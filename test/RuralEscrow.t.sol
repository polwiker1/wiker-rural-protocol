// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1155Holder} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract ReentrantBuyer is ERC1155Holder {
    RuralEscrow private immutable escrow;
    MockUSDC private immutable usdc;
    uint256 private immutable lotId;
    bytes32 private immutable agreementHash;

    bool public reentryBlocked;

    constructor(RuralEscrow escrow_, MockUSDC usdc_, uint256 lotId_, bytes32 agreementHash_) {
        escrow = escrow_;
        usdc = usdc_;
        lotId = lotId_;
        agreementHash = agreementHash_;
    }

    function approveAndPurchase() external {
        usdc.approve(address(escrow), type(uint256).max);
        escrow.purchase(lotId, 1, type(uint128).max, agreementHash);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public override returns (bytes4) {
        try escrow.purchase(lotId, 1, type(uint128).max, agreementHash) {
            reentryBlocked = false;
        } catch {
            reentryBlocked = true;
        }
        return this.onERC1155Received.selector;
    }
}

contract RuralEscrowTest is Test {
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

    function testPurchaseCalculatesPriceAndMintsTokensToBuyer() public {
        uint256 orderId = _purchase();
        RuralEscrow.Order memory order = escrow.getOrder(orderId);

        assertEq(order.buyer, buyer);
        assertEq(order.producer, producer);
        assertEq(order.quantity, QUANTITY);
        assertEq(order.amount, ORDER_AMOUNT);
        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Paid));
        assertEq(usdc.balanceOf(address(escrow)), ORDER_AMOUNT);
        assertEq(products.balanceOf(buyer, LOT_ID), QUANTITY);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testPurchaseRevertsForSuspendedProducer() public {
        vm.prank(admin);
        registry.suspendProducer(producer);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.ProducerNotActive.selector);
        escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, AGREEMENT_HASH);
    }

    function testPurchasePauseDoesNotBlockExistingRefund() public {
        uint256 orderId = _purchase();

        vm.prank(admin);
        escrow.setPurchasesPaused(true);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.PurchasesPaused.selector);
        escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, AGREEMENT_HASH);

        vm.warp(block.timestamp + 7 days);
        vm.prank(admin);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);

        assertEq(usdc.balanceOf(buyer), 1_000e6);
    }

    function testBuyerConfirmsReceiptAndReleasesStandardFee() public {
        uint256 orderId = _purchase();

        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        vm.prank(buyer);
        escrow.confirmReceipt(orderId);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Completed));
        assertEq(usdc.balanceOf(producer), 19_800_000);
        assertEq(usdc.balanceOf(treasury), 200_000);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testPurchaseRevertsWhenPriceExceedsBuyerMaximum() public {
        vm.prank(admin);
        products.updateUnitPrice(LOT_ID, UNIT_PRICE + 1e6);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.MaximumAmountExceeded.selector);
        escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, AGREEMENT_HASH);
    }

    function testOnlyBuyerCanConfirmReceipt() public {
        uint256 orderId = _purchase();

        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        vm.prank(stranger);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.confirmReceipt(orderId);
    }

    function testOnlyAdminCanConfirmShipment() public {
        uint256 orderId = _purchase();

        vm.prank(stranger);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
    }

    function testProductSentRequiresLogisticsReviewAfterTwentyOneDaysWithoutMovingFunds() public {
        uint256 orderId = _purchase();

        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        assertFalse(escrow.requiresLogisticsReview(orderId));
        vm.warp(block.timestamp + escrow.LOGISTICS_REVIEW_PERIOD());
        assertTrue(escrow.requiresLogisticsReview(orderId));
        assertEq(usdc.balanceOf(address(escrow)), ORDER_AMOUNT);
        assertEq(usdc.balanceOf(producer), 0);
    }

    function testAdminRefundsFullAmountAfterSevenDaysWithoutShipment() public {
        uint256 orderId = _purchase();
        uint256 buyerBalanceAfterPurchase = usdc.balanceOf(buyer);

        vm.warp(block.timestamp + 7 days);
        vm.prank(admin);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        ProducerRegistry.Producer memory producerRecord = registry.getProducer(producer);

        assertEq(buyerBalanceAfterPurchase, 980e6);
        assertEq(usdc.balanceOf(buyer), 1_000e6);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY);
        assertEq(producerRecord.shipmentFailures, 1);
        assertEq(registry.feeBps(producer), 500);
    }

    function testRefundedBuyerCannotPermanentlyExhaustLotStock() public {
        uint128 fullLotAmount = MAX_SUPPLY * UNIT_PRICE;
        vm.prank(buyer);
        uint256 orderId = escrow.purchase(LOT_ID, MAX_SUPPLY, fullLotAmount, AGREEMENT_HASH);
        assertEq(products.availableSupply(LOT_ID), 0);

        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(admin);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY);

        usdc.mint(stranger, fullLotAmount);
        vm.startPrank(stranger);
        usdc.approve(address(escrow), fullLotAmount);
        escrow.purchase(LOT_ID, MAX_SUPPLY, fullLotAmount, keccak256("second-agreement"));
        vm.stopPrank();

        assertEq(products.availableSupply(LOT_ID), 0);
        assertEq(products.balanceOf(stranger, LOT_ID), MAX_SUPPLY);
    }

    function testCannotRefundBeforeShipmentDeadline() public {
        uint256 orderId = _purchase();

        vm.prank(admin);
        vm.expectRevert(RuralEscrow.DeadlineActive.selector);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);
    }

    function testOnlyAdminCanRefundForNoShipment() public {
        uint256 orderId = _purchase();
        vm.warp(block.timestamp + 7 days);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);
    }

    function testRefundCannotExecuteTwice() public {
        uint256 orderId = _purchase();
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(admin);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.refundForNoShipment(orderId, RESOLUTION_HASH);
        vm.stopPrank();
    }

    function testCompletedOrderCannotReleaseFundsTwice() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        vm.startPrank(buyer);
        escrow.confirmReceipt(orderId);

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.confirmReceipt(orderId);
        vm.stopPrank();

        assertEq(usdc.balanceOf(producer), 19_800_000);
        assertEq(usdc.balanceOf(treasury), 200_000);
    }

    function testSecondNoShipmentRefundSuspendsProducer() public {
        uint256 firstOrderId = _purchase();
        uint256 secondOrderId = _purchase();
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(admin);
        escrow.refundForNoShipment(firstOrderId, RESOLUTION_HASH);
        escrow.refundForNoShipment(secondOrderId, RESOLUTION_HASH);
        vm.stopPrank();

        assertFalse(registry.isActiveProducer(producer));
    }

    function testPenalizedProducerPaysFivePercentOnFutureCompletion() public {
        uint256 failedOrderId = _purchase();
        vm.warp(block.timestamp + 7 days);
        vm.prank(admin);
        escrow.refundForNoShipment(failedOrderId, RESOLUTION_HASH);

        uint256 successfulOrderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(successfulOrderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.confirmReceipt(successfulOrderId);

        assertEq(usdc.balanceOf(producer), 19e6);
        assertEq(usdc.balanceOf(treasury), 1e6);
    }

    function testDisputeFreezesOrderUntilAdminRefundsBuyer() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);

        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.prank(buyer);
        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.confirmReceipt(orderId);

        vm.prank(admin);
        escrow.resolveDisputeForBuyer(orderId, RESOLUTION_HASH);

        assertEq(usdc.balanceOf(buyer), 1_000e6);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
        assertEq(registry.feeBps(producer), 100);
    }

    function testAdminCanResolveDisputeForProducer() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.prank(admin);
        escrow.resolveDisputeForProducer(orderId, RESOLUTION_HASH);

        assertEq(usdc.balanceOf(producer), 19_800_000);
        assertEq(usdc.balanceOf(treasury), 200_000);
    }

    function testAdminCanSplitDisputedFunds() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.prank(admin);
        escrow.resolveDisputeSplit(orderId, 10e6, RESOLUTION_HASH);

        assertEq(usdc.balanceOf(buyer), 990e6);
        assertEq(usdc.balanceOf(producer), 9_900_000);
        assertEq(usdc.balanceOf(treasury), 100_000);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testEscalatedDisputeCanStillBeResolved() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        escrow.escalateDispute(orderId, keccak256("legal-escalation"));
        escrow.resolveDisputeForBuyer(orderId, RESOLUTION_HASH);
        vm.stopPrank();

        assertEq(usdc.balanceOf(buyer), 1_000e6);
    }

    function testBuyerReturnRefundsOnlyAfterProducerReceivesProduct() public {
        uint256 orderId = _purchase();
        vm.startPrank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        escrow.confirmDelivery(orderId);
        vm.stopPrank();
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));
        escrow.confirmReturnShipment(orderId, keccak256("return-shipping"));
        vm.stopPrank();

        assertEq(usdc.balanceOf(buyer), 980e6);
        assertEq(usdc.balanceOf(address(escrow)), ORDER_AMOUNT);
        assertEq(products.balanceOf(buyer, LOT_ID), QUANTITY);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);

        vm.prank(admin);
        escrow.confirmReturnReceivedAndRefund(orderId, keccak256("return-received"), true);

        RuralEscrow.Order memory order = escrow.getOrder(orderId);
        assertEq(uint256(order.status), uint256(RuralEscrow.OrderStatus.Refunded));
        assertEq(usdc.balanceOf(buyer), 1_000e6);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.balanceOf(buyer, LOT_ID), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY);
    }

    function testApprovedReturnWithoutShipmentKeepsFundsAndStockReserved() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);
        vm.prank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));

        vm.prank(admin);
        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.confirmReturnReceivedAndRefund(orderId, keccak256("not-received"), true);

        assertEq(usdc.balanceOf(address(escrow)), ORDER_AMOUNT);
        assertEq(products.balanceOf(buyer, LOT_ID), QUANTITY);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testApprovedReturnNotShippedCanResolveForProducer() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));
        vm.warp(block.timestamp + escrow.RETURN_SHIPMENT_DEADLINE());
        escrow.resolveExpiredReturnForProducer(orderId, keccak256("buyer-never-returned"));
        vm.stopPrank();

        assertEq(uint256(escrow.getOrder(orderId).status), uint256(RuralEscrow.OrderStatus.Completed));
        assertEq(usdc.balanceOf(producer), 19_800_000);
        assertEq(usdc.balanceOf(treasury), 200_000);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
    }

    function testReturnCannotShipAfterDeadline() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);
        vm.prank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));

        vm.warp(block.timestamp + escrow.RETURN_SHIPMENT_DEADLINE());
        vm.prank(admin);
        vm.expectRevert(RuralEscrow.DeadlineExpired.selector);
        escrow.confirmReturnShipment(orderId, keccak256("late-return"));
    }

    function testReturnShippedRequiresSpecificArbitration() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);
        vm.startPrank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));
        escrow.confirmReturnShipment(orderId, keccak256("return-shipped"));

        vm.expectRevert(RuralEscrow.InvalidStatus.selector);
        escrow.resolveDisputeForProducer(orderId, keccak256("invalid-general-resolution"));

        escrow.resolveReturnShippingDispute(orderId, 10e6, keccak256("return-lost-split"));
        vm.stopPrank();

        assertEq(uint256(escrow.getOrder(orderId).status), uint256(RuralEscrow.OrderStatus.PartiallyResolved));
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function testReturnedDamagedProductIsRefundedButRetiredFromStock() public {
        uint256 orderId = _purchase();
        vm.prank(admin);
        escrow.confirmShipment(orderId, SHIPPING_HASH);
        vm.prank(buyer);
        escrow.openDispute(orderId, DISPUTE_HASH);

        vm.startPrank(admin);
        escrow.approveReturn(orderId, keccak256("return-approved"));
        escrow.confirmReturnShipment(orderId, keccak256("return-shipping"));
        escrow.confirmReturnReceivedAndRefund(orderId, keccak256("damaged-return-received"), false);
        vm.stopPrank();

        RuralProducts1155.Lot memory lot = products.getLot(LOT_ID);
        assertEq(lot.retiredSupply, QUANTITY);
        assertEq(products.availableSupply(LOT_ID), MAX_SUPPLY - QUANTITY);
        assertEq(usdc.balanceOf(buyer), 1_000e6);
    }

    function testPurchaseBlocksReentrancyFromERC1155Receiver() public {
        ReentrantBuyer attacker = new ReentrantBuyer(escrow, usdc, LOT_ID, AGREEMENT_HASH);
        usdc.mint(address(attacker), 100e6);

        attacker.approveAndPurchase();

        assertTrue(attacker.reentryBlocked());
        assertEq(escrow.nextOrderId(), 2);
        assertEq(products.balanceOf(address(attacker), LOT_ID), 1);
    }

    function _purchase() private returns (uint256 orderId) {
        vm.prank(buyer);
        orderId = escrow.purchase(LOT_ID, QUANTITY, ORDER_AMOUNT, AGREEMENT_HASH);
    }
}
