// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract DisputeScenarioMatrixTest is Test {
    address internal admin = address(0xAD);
    address internal treasury = address(0x7EA);
    address internal buyer = address(0xA11CE);

    uint128 internal constant MAX_SUPPLY = 100;
    uint128 internal constant UNIT_PRICE = 10e6;
    uint128 internal constant QUANTITY = 2;
    uint128 internal constant ORDER_AMOUNT = UNIT_PRICE * QUANTITY;

    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal usdc;

    address[5] internal producers;

    function setUp() public {
        registry = new ProducerRegistry(admin);
        products = new RuralProducts1155(admin, "https://api.wiker.example/lots/{id}.json");
        usdc = new MockUSDC();
        escrow = new RuralEscrow(admin, admin, admin, treasury, usdc, registry, products);

        vm.startPrank(admin);
        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));
        for (uint256 i = 0; i < producers.length; i++) {
            address producer = address(uint160(0x1000 + i));
            producers[i] = producer;
            registry.registerProducer(producer, keccak256(abi.encode("producer", i)));
            products.createLot(101 + i, producer, MAX_SUPPLY, UNIT_PRICE, keccak256(abi.encode("lot", i)));
        }
        vm.stopPrank();

        usdc.mint(buyer, 1_000e6);
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function testFiveProducerFailureAndDisputeResolutionMatrix() public {
        uint256[5] memory orderIds;
        for (uint256 i = 0; i < orderIds.length; i++) {
            orderIds[i] = _purchase(101 + i);
        }

        vm.startPrank(admin);
        for (uint256 i = 1; i < orderIds.length; i++) {
            escrow.confirmShipment(orderIds[i], keccak256(abi.encode("shipment", i)));
        }
        vm.stopPrank();

        // Producer 2 shipment is not delivered and stock is recovered.
        _openDispute(orderIds[1], "not-delivered");
        vm.prank(admin);
        escrow.resolveDisputeForBuyer(orderIds[1], keccak256("not-delivered-refund"));

        // Producer 3 proves delivery and receives the payment.
        _openDispute(orderIds[2], "buyer-claim-rejected");
        vm.prank(admin);
        escrow.resolveDisputeForProducer(orderIds[2], keccak256("producer-proved-delivery"));

        // Producer 4 and buyer accept a split caused by carrier damage.
        _openDispute(orderIds[3], "carrier-damage");
        vm.prank(admin);
        escrow.resolveDisputeSplit(orderIds[3], 10e6, keccak256("carrier-damage-split"));

        // Producer 5 dispute is escalated to legal; stock is later recovered.
        _openDispute(orderIds[4], "legal-review-required");
        vm.startPrank(admin);
        escrow.escalateDispute(orderIds[4], keccak256("legal-escalation"));
        escrow.resolveDisputeForBuyer(orderIds[4], keccak256("legal-buyer-refund"));
        vm.stopPrank();

        // Producer 1 never shipped within the deadline.
        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(admin);
        escrow.refundForNoShipment(orderIds[0], keccak256("no-shipment-refund"));

        assertEq(uint256(escrow.getOrder(orderIds[0]).status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(uint256(escrow.getOrder(orderIds[1]).status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(uint256(escrow.getOrder(orderIds[2]).status), uint256(RuralEscrow.OrderStatus.Completed));
        assertEq(uint256(escrow.getOrder(orderIds[3]).status), uint256(RuralEscrow.OrderStatus.PartiallyResolved));
        assertEq(uint256(escrow.getOrder(orderIds[4]).status), uint256(RuralEscrow.OrderStatus.Refunded));

        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(usdc.balanceOf(buyer), 970e6);
        assertEq(usdc.balanceOf(producers[2]), 19_800_000);
        assertEq(usdc.balanceOf(producers[3]), 9_900_000);
        assertEq(usdc.balanceOf(treasury), 300_000);

        for (uint256 i = 0; i < producers.length; i++) {
            assertEq(products.balanceOf(buyer, 101 + i), 0);
            uint256 expectedAvailable = i == 0 ? MAX_SUPPLY : MAX_SUPPLY - QUANTITY;
            assertEq(products.availableSupply(101 + i), expectedAvailable);
        }

        _assertProducerFault(producers[0]);
        for (uint256 i = 1; i < producers.length; i++) {
            assertEq(registry.getProducer(producers[i]).shipmentFailures, 0);
        }
    }

    function testShipmentCannotBeConfirmedAfterDeadline() public {
        uint256 orderId = _purchase(101);
        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());

        vm.prank(admin);
        vm.expectRevert(RuralEscrow.ShipmentDeadlineExpired.selector);
        escrow.confirmShipment(orderId, keccak256("late-shipment"));

        vm.prank(admin);
        escrow.refundForNoShipment(orderId, keccak256("deadline-refund"));
    }

    function testDisputeRefundsDoNotPenalizeProducer() public {
        uint256 firstOrderId = _purchase(101);
        uint256 secondOrderId = _purchase(101);

        vm.startPrank(admin);
        escrow.confirmShipment(firstOrderId, keccak256("fake-shipment-1"));
        escrow.confirmShipment(secondOrderId, keccak256("fake-shipment-2"));
        vm.stopPrank();

        _openDispute(firstOrderId, "not-delivered-1");
        _openDispute(secondOrderId, "not-delivered-2");

        vm.startPrank(admin);
        escrow.resolveDisputeForBuyer(firstOrderId, keccak256("fault-1"));
        escrow.resolveDisputeForBuyer(secondOrderId, keccak256("fault-2"));
        vm.stopPrank();

        assertTrue(registry.isActiveProducer(producers[0]));
        assertEq(registry.getProducer(producers[0]).shipmentFailures, 0);
        assertEq(registry.feeBps(producers[0]), registry.STANDARD_FEE_BPS());
    }

    function testAdminCanOpenDisputeWhenBuyerReportsOffChain() public {
        uint256 orderId = _purchase(101);

        vm.startPrank(admin);
        escrow.confirmShipment(orderId, keccak256("shipment"));
        escrow.openDispute(orderId, keccak256("buyer-reported-by-whatsapp"));
        escrow.resolveDisputeForBuyer(orderId, keccak256("producer-never-delivered"));
        vm.stopPrank();

        assertEq(uint256(escrow.getOrder(orderId).status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(registry.getProducer(producers[0]).shipmentFailures, 0);
    }

    function testUnrelatedWalletCannotOpenDispute() public {
        uint256 orderId = _purchase(101);
        vm.prank(admin);
        escrow.confirmShipment(orderId, keccak256("shipment"));

        vm.prank(address(0xBAD));
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.openDispute(orderId, keccak256("invalid-report"));
    }

    function _purchase(uint256 lotId) private returns (uint256 orderId) {
        vm.prank(buyer);
        orderId = escrow.purchase(lotId, QUANTITY, ORDER_AMOUNT, keccak256(abi.encode("agreement", lotId)));
    }

    function _openDispute(uint256 orderId, string memory reason) private {
        vm.prank(buyer);
        escrow.openDispute(orderId, keccak256(bytes(reason)));
    }

    function _assertProducerFault(address producer) private view {
        assertEq(registry.getProducer(producer).shipmentFailures, 1);
        assertEq(registry.feeBps(producer), registry.PENALIZED_FEE_BPS());
        assertTrue(registry.isActiveProducer(producer));
    }
}
