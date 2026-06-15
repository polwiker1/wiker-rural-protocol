// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {ProducerRegistry} from "./ProducerRegistry.sol";
import {RuralProducts1155} from "./RuralProducts1155.sol";

contract RuralEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    uint256 public constant SHIPMENT_DEADLINE = 7 days;
    uint256 public constant DELIVERY_REVIEW_PERIOD = 7 days;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    enum OrderStatus {
        None,
        Paid,
        ProductSent,
        Delivered,
        Disputed,
        Escalated,
        Completed,
        Refunded,
        PartiallyResolved
    }

    struct Order {
        uint256 lotId;
        address buyer;
        address producer;
        uint128 quantity;
        uint128 amount;
        uint64 purchasedAt;
        uint64 sentAt;
        uint64 deliveredAt;
        OrderStatus status;
        bytes32 agreementHash;
        bytes32 shippingEvidenceHash;
        bytes32 disputeEvidenceHash;
        bytes32 resolutionHash;
    }

    IERC20 public immutable paymentToken;
    ProducerRegistry public immutable producerRegistry;
    RuralProducts1155 public immutable ruralProducts;

    address public admin;
    address public treasury;
    uint256 public nextOrderId = 1;
    bool public purchasesPaused;

    mapping(uint256 orderId => Order) private orders;

    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event PurchasesPausedUpdated(bool paused);
    event OrderCreated(
        uint256 indexed orderId,
        uint256 indexed lotId,
        address indexed buyer,
        address producer,
        uint256 quantity,
        uint256 amount,
        bytes32 agreementHash
    );
    event ShipmentConfirmed(uint256 indexed orderId, bytes32 indexed shippingEvidenceHash);
    event DeliveryConfirmed(uint256 indexed orderId, address indexed confirmedBy);
    event DisputeOpened(uint256 indexed orderId, bytes32 indexed disputeEvidenceHash);
    event DisputeEscalated(uint256 indexed orderId, bytes32 indexed resolutionHash);
    event OrderCompleted(uint256 indexed orderId, uint256 producerAmount, uint256 treasuryFee);
    event OrderRefunded(uint256 indexed orderId, uint256 buyerAmount, bool shipmentFailure);
    event OrderPartiallyResolved(
        uint256 indexed orderId, uint256 buyerAmount, uint256 producerAmount, uint256 treasuryFee
    );

    error Unauthorized();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidHash();
    error InvalidStatus();
    error PurchasesPaused();
    error ProducerNotActive();
    error MaximumAmountExceeded();
    error DeadlineActive();
    error ReviewPeriodActive();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(
        address initialAdmin,
        address initialTreasury,
        IERC20 paymentToken_,
        ProducerRegistry producerRegistry_,
        RuralProducts1155 ruralProducts_
    ) {
        if (
            initialAdmin == address(0) || initialTreasury == address(0) || address(paymentToken_) == address(0)
                || address(producerRegistry_) == address(0) || address(ruralProducts_) == address(0)
        ) revert ZeroAddress();

        admin = initialAdmin;
        treasury = initialTreasury;
        paymentToken = paymentToken_;
        producerRegistry = producerRegistry_;
        ruralProducts = ruralProducts_;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(previousAdmin, newAdmin);
    }

    function setTreasury(address newTreasury) external onlyAdmin {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previousTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(previousTreasury, newTreasury);
    }

    function setPurchasesPaused(bool paused) external onlyAdmin {
        purchasesPaused = paused;
        emit PurchasesPausedUpdated(paused);
    }

    function purchase(uint256 lotId, uint128 quantity, uint128 maxAmount, bytes32 agreementHash)
        external
        nonReentrant
        returns (uint256 orderId)
    {
        if (purchasesPaused) revert PurchasesPaused();
        if (quantity == 0) revert InvalidAmount();
        if (agreementHash == bytes32(0)) revert InvalidHash();

        RuralProducts1155.Lot memory lot = ruralProducts.getLot(lotId);
        if (!producerRegistry.isActiveProducer(lot.producer)) revert ProducerNotActive();

        uint256 amount = uint256(quantity) * uint256(lot.unitPrice);
        if (amount > type(uint128).max) revert InvalidAmount();
        if (amount > maxAmount) revert MaximumAmountExceeded();

        orderId = nextOrderId++;
        orders[orderId] = Order({
            lotId: lotId,
            buyer: msg.sender,
            producer: lot.producer,
            quantity: quantity,
            amount: amount.toUint128(),
            purchasedAt: uint64(block.timestamp),
            sentAt: 0,
            deliveredAt: 0,
            status: OrderStatus.Paid,
            agreementHash: agreementHash,
            shippingEvidenceHash: bytes32(0),
            disputeEvidenceHash: bytes32(0),
            resolutionHash: bytes32(0)
        });

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        ruralProducts.allocateToBuyer(msg.sender, lotId, quantity);

        emit OrderCreated(orderId, lotId, msg.sender, lot.producer, quantity, amount, agreementHash);
    }

    function confirmShipment(uint256 orderId, bytes32 shippingEvidenceHash) external onlyAdmin {
        if (shippingEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Paid);

        order.status = OrderStatus.ProductSent;
        order.sentAt = uint64(block.timestamp);
        order.shippingEvidenceHash = shippingEvidenceHash;
        emit ShipmentConfirmed(orderId, shippingEvidenceHash);
    }

    function confirmReceipt(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        if (msg.sender != order.buyer) revert Unauthorized();
        if (order.status != OrderStatus.ProductSent && order.status != OrderStatus.Delivered) revert InvalidStatus();

        order.deliveredAt = uint64(block.timestamp);
        _complete(orderId, order);
    }

    function confirmDelivery(uint256 orderId) external onlyAdmin {
        Order storage order = _requireStatus(orderId, OrderStatus.ProductSent);
        order.status = OrderStatus.Delivered;
        order.deliveredAt = uint64(block.timestamp);
        emit DeliveryConfirmed(orderId, msg.sender);
    }

    function finalizeAfterDeliveryReview(uint256 orderId) external onlyAdmin nonReentrant {
        Order storage order = _requireStatus(orderId, OrderStatus.Delivered);
        if (block.timestamp < uint256(order.deliveredAt) + DELIVERY_REVIEW_PERIOD) revert ReviewPeriodActive();
        _complete(orderId, order);
    }

    function refundForNoShipment(uint256 orderId, bytes32 resolutionHash) external onlyAdmin nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Paid);
        if (block.timestamp < uint256(order.purchasedAt) + SHIPMENT_DEADLINE) revert DeadlineActive();

        order.status = OrderStatus.Refunded;
        order.resolutionHash = resolutionHash;

        ruralProducts.burnFailed(order.buyer, order.lotId, order.quantity);
        producerRegistry.reportShipmentFailure(order.producer);
        paymentToken.safeTransfer(order.buyer, order.amount);

        emit OrderRefunded(orderId, order.amount, true);
    }

    function openDispute(uint256 orderId, bytes32 disputeEvidenceHash) external {
        if (disputeEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = orders[orderId];
        if (msg.sender != order.buyer) revert Unauthorized();
        if (order.status != OrderStatus.ProductSent && order.status != OrderStatus.Delivered) revert InvalidStatus();

        order.status = OrderStatus.Disputed;
        order.disputeEvidenceHash = disputeEvidenceHash;
        emit DisputeOpened(orderId, disputeEvidenceHash);
    }

    function escalateDispute(uint256 orderId, bytes32 resolutionHash) external onlyAdmin {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Disputed);
        order.status = OrderStatus.Escalated;
        order.resolutionHash = resolutionHash;
        emit DisputeEscalated(orderId, resolutionHash);
    }

    function resolveDisputeForProducer(uint256 orderId, bytes32 resolutionHash) external onlyAdmin nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        order.resolutionHash = resolutionHash;
        _complete(orderId, order);
    }

    function resolveDisputeForBuyer(uint256 orderId, bytes32 resolutionHash) external onlyAdmin nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        order.status = OrderStatus.Refunded;
        order.resolutionHash = resolutionHash;

        ruralProducts.burnFailed(order.buyer, order.lotId, order.quantity);
        paymentToken.safeTransfer(order.buyer, order.amount);
        emit OrderRefunded(orderId, order.amount, false);
    }

    function resolveDisputeSplit(uint256 orderId, uint128 buyerAmount, bytes32 resolutionHash)
        external
        onlyAdmin
        nonReentrant
    {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        if (buyerAmount == 0 || buyerAmount >= order.amount) revert InvalidAmount();

        order.status = OrderStatus.PartiallyResolved;
        order.resolutionHash = resolutionHash;

        uint256 grossProducerAmount = uint256(order.amount) - buyerAmount;
        (uint256 producerAmount, uint256 treasuryFee) = _paymentSplit(order.producer, grossProducerAmount);

        ruralProducts.burnFailed(order.buyer, order.lotId, order.quantity);
        paymentToken.safeTransfer(order.buyer, buyerAmount);
        paymentToken.safeTransfer(order.producer, producerAmount);
        paymentToken.safeTransfer(treasury, treasuryFee);

        emit OrderPartiallyResolved(orderId, buyerAmount, producerAmount, treasuryFee);
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function _complete(uint256 orderId, Order storage order) private {
        order.status = OrderStatus.Completed;
        (uint256 producerAmount, uint256 treasuryFee) = _paymentSplit(order.producer, order.amount);

        ruralProducts.burnCompleted(order.buyer, order.lotId, order.quantity);
        paymentToken.safeTransfer(order.producer, producerAmount);
        paymentToken.safeTransfer(treasury, treasuryFee);
        emit OrderCompleted(orderId, producerAmount, treasuryFee);
    }

    function _paymentSplit(address producer, uint256 grossAmount)
        private
        view
        returns (uint256 producerAmount, uint256 treasuryFee)
    {
        treasuryFee = grossAmount * producerRegistry.feeBps(producer) / BPS_DENOMINATOR;
        producerAmount = grossAmount - treasuryFee;
    }

    function _requireStatus(uint256 orderId, OrderStatus expected) private view returns (Order storage order) {
        order = orders[orderId];
        if (order.status != expected) revert InvalidStatus();
    }

    function _requireResolvableDispute(uint256 orderId) private view returns (Order storage order) {
        order = orders[orderId];
        if (order.status != OrderStatus.Disputed && order.status != OrderStatus.Escalated) revert InvalidStatus();
    }
}
