// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RuralEscrowNegativeBranchesTest is Test {
    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal usdc;

    address internal admin = address(0xAD);
    address internal treasury = address(0x7EA);
    address internal producer = address(0xBEEF);
    address internal buyer = address(0xA11CE);
    address internal stranger = address(0xBAD);

    uint256 internal constant LOT_ID = 1;
    uint128 internal constant MAX_SUPPLY = 100;
    uint128 internal constant UNIT_PRICE = 10e6;
    uint128 internal constant QUANTITY = 2;
    uint128 internal constant ORDER_AMOUNT = UNIT_PRICE * QUANTITY;

    bytes32 internal constant AGREEMENT_HASH = keccak256("agreement-v1");
    bytes32 internal constant SHIPPING_HASH = keccak256("shipping-evidence-v1");
    bytes32 internal constant DISPUTE_HASH = keccak256("dispute-evidence-v1");
    bytes32 internal constant RESOLUTION_HASH = keccak256("resolution-v1");

    function setUp() public {
        registry = new ProducerRegistry(admin);
        products = new RuralProducts1155(admin, "https://api.wiker.example/lots/{id}.json");
        usdc = new MockUSDC();
        escrow = new RuralEscrow(admin, admin, admin, treasury, usdc, registry, products);

        vm.startPrank(admin);
        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));
        registry.registerProducer(producer, keccak256("producer-profile"));
        products.createLot(LOT_ID, producer, MAX_SUPPLY, UNIT_PRICE, keccak256("lot-metadata"));
        vm.stopPrank();

        usdc.mint(buyer, 1_000e6);
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function testConstructorRejectsZeroAddresses() public {
        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(address(0), admin, admin, treasury, usdc, registry, products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, address(0), admin, treasury, usdc, registry, products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, admin, address(0), treasury, usdc, registry, products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, admin, admin, address(0), usdc, registry, products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, admin, admin, treasury, MockUSDC(address(0)), registry, products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, admin, admin, treasury, usdc, ProducerRegistry(address(0)), products);

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        new RuralEscrow(admin, admin, admin, treasury, usdc, registry, RuralProducts1155(address(0)));
    }

    function testGovernanceSettersRejectZeroAddressesAndUnauthorizedCaller() public {
        vm.prank(stranger);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.setGovernance(stranger);

        vm.startPrank(admin);
        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        escrow.setGovernance(address(0));

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        escrow.setResolver(address(0));

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        escrow.setVerifier(address(0));

        vm.expectRevert(RuralEscrow.ZeroAddress.selector);
        escrow.setTreasury(address(0));
        vm.stopPrank();
    }

    function testPurchaseRejectsInvalidInputsAndOverflowAmount() public {
        vm.startPrank(buyer);
        vm.expectRevert(RuralEscrow.InvalidAmount.selector);
        escrow.purchase(LOT_ID, 0, ORDER_AMOUNT, AGREEMENT_HASH);

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, bytes32(0));
        vm.stopPrank();

        vm.prank(admin);
        products.createLot(2, producer, 10, type(uint128).max, keccak256("expensive-lot"));

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.InvalidAmount.selector);
        escrow.purchase(2, 2, type(uint128).max, AGREEMENT_HASH);
    }

    function testShipmentAndDeliveryRejectInvalidBranches() public {
        uint256 orderId = _purchase();

        vm.startPrank(admin);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.confirmShipment(orderId, bytes32(0));

        escrow.confirmShipment(orderId, SHIPPING_HASH);

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        escrow.confirmDelivery(orderId);

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.confirmDelivery(orderId);
        vm.stopPrank();
    }

    function testRefundRejectsZeroHashAndInvalidStatus() public {
        uint256 orderId = _purchase();

        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(admin);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.refundForNoShipment(orderId, bytes32(0));

        uint256 sentOrderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(sentOrderId, SHIPPING_HASH);

        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(admin);
        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.refundForNoShipment(sentOrderId, RESOLUTION_HASH);
    }

    function testDisputeEntrypointsRejectInvalidHashesAndStatuses() public {
        uint256 orderId = _purchase();

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.openDispute(orderId, bytes32(0));

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.escalateDispute(orderId, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.escalateDispute(orderId, RESOLUTION_HASH);

        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.stopPrank();

        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.resolveDisputeForProducer(orderId, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.resolveDisputeForBuyer(orderId, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.resolveDisputeSplit(orderId, 1, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidAmount.selector);
        escrow.resolveDisputeSplit(orderId, 0, RESOLUTION_HASH);

        vm.expectRevert(RuralEscrow.InvalidAmount.selector);
        escrow.resolveDisputeSplit(orderId, ORDER_AMOUNT, RESOLUTION_HASH);
        vm.stopPrank();
    }

    function testReturnFlowRejectsInvalidHashesAndDeadlines() public {
        uint256 orderId = _openDispute();

        vm.startPrank(admin);
        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.approveReturn(orderId, bytes32(0));

        escrow.approveReturn(orderId, RESOLUTION_HASH);

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.confirmReturnShipment(orderId, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.resolveExpiredReturnForProducer(orderId, bytes32(0));

        vm.expectRevert(RuralEscrow.DeadlineActive.selector);
        escrow.resolveExpiredReturnForProducer(orderId, RESOLUTION_HASH);

        escrow.confirmReturnShipment(orderId, keccak256("return-shipping"));

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.confirmReturnReceivedAndRefund(orderId, bytes32(0), true);

        vm.expectRevert(RuralEscrow.InvalidHash.selector);
        escrow.resolveReturnShippingDispute(orderId, 0, bytes32(0));

        vm.expectRevert(RuralEscrow.InvalidAmount.selector);
        escrow.resolveReturnShippingDispute(orderId, ORDER_AMOUNT + 1, RESOLUTION_HASH);
        vm.stopPrank();
    }

    function testReturnShippingDisputeCanResolveFullProducerPayment() public {
        uint256 orderId = _returnShippedOrder();

        vm.prank(admin);
        escrow.resolveReturnShippingDispute(orderId, 0, RESOLUTION_HASH);

        assertEq(uint256(escrow.getOrder(orderId).status), uint256(RuralEscrow.OrderStatus.Completed));
        assertEq(usdc.balanceOf(producer), 19_800_000);
        assertEq(usdc.balanceOf(treasury), 200_000);
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function testReturnShippingDisputeCanResolveFullBuyerRefund() public {
        uint256 orderId = _returnShippedOrder();

        vm.prank(admin);
        escrow.resolveReturnShippingDispute(orderId, ORDER_AMOUNT, RESOLUTION_HASH);

        assertEq(uint256(escrow.getOrder(orderId).status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(usdc.balanceOf(buyer), 1_000e6);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testViewBranchesForLogisticsAndReturnDeadline() public {
        assertFalse(escrow.requiresLogisticsReview(999));
        assertEq(escrow.returnShipmentDeadline(999), 0);

        uint256 orderId = _openDispute();
        vm.prank(admin);
        escrow.approveReturn(orderId, RESOLUTION_HASH);

        assertEq(escrow.returnShipmentDeadline(orderId), block.timestamp + escrow.RETURN_SHIPMENT_DEADLINE());
    }

    function _purchase() private returns (uint256 orderId) {
        vm.prank(buyer);
        orderId = escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, AGREEMENT_HASH);
    }

    function _openDispute() private returns (uint256 orderId) {
        orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);
    }

    function _returnShippedOrder() private returns (uint256 orderId) {
        orderId = _openDispute();
        vm.startPrank(admin);
        escrow.approveReturn(orderId, RESOLUTION_HASH);
        escrow.confirmReturnShipment(orderId, keccak256("return-shipping"));
        vm.stopPrank();
    }
}
