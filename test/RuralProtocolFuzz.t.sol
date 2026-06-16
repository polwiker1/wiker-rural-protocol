// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RuralProtocolFuzzTest is Test {
    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal usdc;

    address internal governance = address(0x600);
    address internal resolver = address(0x650);
    address internal verifier = address(0x700);
    address internal treasury = address(0x7EA);
    address internal producer = address(0xBEEF);
    address internal buyer = address(0xA11CE);

    uint256 internal constant LOT_ID = 1;
    uint128 internal constant MAX_SUPPLY = 1_000;
    uint128 internal constant UNIT_PRICE = 10e6;
    uint256 internal constant BUYER_STARTING_BALANCE = 100_000e6;

    bytes32 internal constant AGREEMENT_HASH = keccak256("agreement-v1");
    bytes32 internal constant SHIPPING_HASH = keccak256("shipping-evidence-v1");
    bytes32 internal constant DISPUTE_HASH = keccak256("dispute-evidence-v1");
    bytes32 internal constant RESOLUTION_HASH = keccak256("resolution-v1");

    function setUp() public {
        registry = new ProducerRegistry(governance);
        products = new RuralProducts1155(governance, "https://api.wiker.example/lots/{id}.json");
        usdc = new MockUSDC();
        escrow = new RuralEscrow(governance, resolver, verifier, treasury, usdc, registry, products);

        vm.startPrank(governance);
        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));
        registry.registerProducer(producer, keccak256("producer-profile"));
        products.createLot(LOT_ID, producer, MAX_SUPPLY, UNIT_PRICE, keccak256("lot-metadata"));
        vm.stopPrank();

        usdc.mint(buyer, BUYER_STARTING_BALANCE);
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function testFuzzPurchaseMaintainsEscrowAndStockAccounting(uint128 rawQuantity) public {
        uint128 quantity = uint128(bound(rawQuantity, 1, MAX_SUPPLY));
        uint128 amount = quantity * UNIT_PRICE;

        uint256 orderId = _purchase(quantity, amount);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);

        assertEq(order.buyer, buyer);
        assertEq(order.producer, producer);
        assertEq(order.quantity, quantity);
        assertEq(order.amount, amount);
        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Paid));
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(buyer), BUYER_STARTING_BALANCE - amount);
        assertEq(products.balanceOf(buyer, LOT_ID), quantity);
        assertEq(lot.reservedSupply, quantity);
        assertEq(lot.soldSupply, 0);
        assertEq(lot.retiredSupply, 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - quantity);
    }

    function testFuzzNoShipmentRefundRestoresStockAndBuyerFunds(uint128 rawQuantity) public {
        uint128 quantity = uint128(bound(rawQuantity, 1, MAX_SUPPLY));
        uint128 amount = quantity * UNIT_PRICE;
        uint256 orderId = _purchase(quantity, amount);

        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(resolver);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);

        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(usdc.balanceOf(buyer), BUYER_STARTING_BALANCE);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.soldSupply, 0);
        assertEq(lot.retiredSupply, 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY);
        assertEq(registry.feeBps(producer), 500);
    }

    function testFuzzPurchasePauseBlocksNewPurchasesButAllowsExistingRefunds(uint128 rawQuantity) public {
        uint128 quantity = uint128(bound(rawQuantity, 1, MAX_SUPPLY));
        uint128 amount = quantity * UNIT_PRICE;
        uint256 orderId = _purchase(quantity, amount);

        vm.prank(governance);
        escrow.setPurchasesPaused(true);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.PurchasesPaused.selector);
        escrow.purchase(LOT_ID, 1, UNIT_PRICE, AGREEMENT_HASH);

        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(resolver);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);

        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(usdc.balanceOf(buyer), BUYER_STARTING_BALANCE);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(lot.reservedSupply, 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY);
        assertTrue(escrow.purchasesPaused());
    }

    function testFuzzSplitDisputeNeverPaysMoreThanEscrowed(uint128 rawQuantity, uint128 rawBuyerAmount) public {
        uint128 quantity = uint128(bound(rawQuantity, 1, MAX_SUPPLY));
        uint128 amount = quantity * UNIT_PRICE;
        uint128 buyerAmount = uint128(bound(rawBuyerAmount, 1, amount - 1));

        uint256 orderId = _purchase(quantity, amount);
        vm.prank(verifier);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        uint256 grossProducerAmount = uint256(amount) - buyerAmount;
        uint256 expectedTreasuryFee = grossProducerAmount * registry.feeBps(producer) / 10_000;
        uint256 expectedProducerAmount = grossProducerAmount - expectedTreasuryFee;

        vm.prank(resolver);
        escrow.resolveDisputeSplit(orderId, buyerAmount, RESOLUTION_HASH);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);

        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.PartiallyResolved));
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(usdc.balanceOf(buyer), BUYER_STARTING_BALANCE - amount + buyerAmount);
        assertEq(usdc.balanceOf(producer), expectedProducerAmount);
        assertEq(usdc.balanceOf(treasury), expectedTreasuryFee);
        assertEq(buyerAmount + expectedProducerAmount + expectedTreasuryFee, amount);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.soldSupply, 0);
        assertEq(lot.retiredSupply, quantity);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - quantity);
    }

    function _purchase(uint128 quantity, uint128 amount) private returns (uint256 orderId) {
        vm.prank(buyer);
        orderId = escrow.purchase(LOT_ID, quantity, amount, AGREEMENT_HASH);
    }
}
