// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RuralProtocolLoadTest is Test {
    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal usdc;

    address internal governance = address(0x600);
    address internal resolver = address(0x650);
    address internal verifier = address(0x700);
    address internal treasury = address(0x7EA);
    address internal producer = address(0xBEEF);

    uint256 internal constant LOT_ID = 1;
    uint128 internal constant MAX_SUPPLY = 1_000;
    uint128 internal constant UNIT_PRICE = 10e6;
    uint256 internal constant BUYER_BALANCE = 10_000e6;
    uint256 internal constant BUYER_KEY_BASE = 100_000;

    bytes32 internal constant AGREEMENT_HASH = keccak256("agreement-v1");

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
    }

    function testManyWalletsCanBuySameLotWithoutBreakingAccounting() public {
        uint256 buyerCount = 100;
        uint128 quantityPerBuyer = 3;
        uint256 totalQuantity = buyerCount * quantityPerBuyer;
        uint256 totalAmount = totalQuantity * UNIT_PRICE;

        for (uint256 i = 0; i < buyerCount; i++) {
            address buyer = _fundAndApproveBuyer(i);
            vm.prank(buyer);
            uint256 orderId = escrow.purchase(LOT_ID, quantityPerBuyer, quantityPerBuyer * UNIT_PRICE, AGREEMENT_HASH);

            RuralEscrow.Order memory order = escrow.getOrder(orderId);
            assertEq(order.buyer, buyer);
            assertEq(order.quantity, quantityPerBuyer);
            assertEq(order.amount, quantityPerBuyer * UNIT_PRICE);
            assertEq(products.balanceOf(buyer, LOT_ID), quantityPerBuyer);
        }

        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);
        assertEq(escrow.nextOrderId(), buyerCount + 1);
        assertEq(usdc.balanceOf(address(escrow)), totalAmount);
        assertEq(lot.reservedSupply, totalQuantity);
        assertEq(lot.soldSupply, 0);
        assertEq(lot.retiredSupply, 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - totalQuantity);
    }

    function testManyWalletsCannotOversellLotSupply() public {
        uint256 buyerCount = 100;
        uint128 quantityPerBuyer = 10;

        for (uint256 i = 0; i < buyerCount; i++) {
            address buyer = _fundAndApproveBuyer(i);
            vm.prank(buyer);
            escrow.purchase(LOT_ID, quantityPerBuyer, quantityPerBuyer * UNIT_PRICE, AGREEMENT_HASH);
        }

        assertEq(products.availableSupply(LOT_ID), 0);
        assertEq(usdc.balanceOf(address(escrow)), uint256(MAX_SUPPLY) * UNIT_PRICE);

        address extraBuyer = _fundAndApproveBuyer(buyerCount);
        vm.prank(extraBuyer);
        vm.expectRevert(RuralProducts1155.SupplyExceeded.selector);
        escrow.purchase(LOT_ID, 1, UNIT_PRICE, AGREEMENT_HASH);

        assertEq(escrow.nextOrderId(), buyerCount + 1);
        assertEq(products.availableSupply(LOT_ID), 0);
        assertEq(products.balanceOf(extraBuyer, LOT_ID), 0);
        assertEq(usdc.balanceOf(extraBuyer), BUYER_BALANCE);
        assertEq(usdc.balanceOf(address(escrow)), uint256(MAX_SUPPLY) * UNIT_PRICE);
    }

    function _fundAndApproveBuyer(uint256 index) private returns (address buyer) {
        buyer = vm.addr(BUYER_KEY_BASE + index);
        usdc.mint(buyer, BUYER_BALANCE);
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);
    }
}
