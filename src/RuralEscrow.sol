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
    uint256 public constant LOGISTICS_REVIEW_PERIOD = 21 days;
    uint256 public constant RETURN_SHIPMENT_DEADLINE = 7 days;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    enum OrderStatus {
        None,
        Paid,
        ProductSent,
        Delivered,
        Disputed,
        Escalated,
        ReturnApproved,
        ReturnShipped,
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
        uint64 returnApprovedAt;
        OrderStatus status;
        bytes32 agreementHash;
        bytes32 shippingEvidenceHash;
        bytes32 disputeEvidenceHash;
        bytes32 resolutionHash;
        bytes32 returnShippingEvidenceHash;
        bytes32 returnReceiptEvidenceHash;
    }

    IERC20 public immutable paymentToken;
    ProducerRegistry public immutable producerRegistry;
    RuralProducts1155 public immutable ruralProducts;

    address public governance;
    address public resolver;
    address public verifier;
    address public treasury;
    uint256 public nextOrderId = 1;
    bool public purchasesPaused;

    mapping(uint256 orderId => Order) private orders;

    event GovernanceUpdated(address indexed previousGovernance, address indexed newGovernance);
    event ResolverUpdated(address indexed previousResolver, address indexed newResolver);
    event VerifierUpdated(address indexed previousVerifier, address indexed newVerifier);
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
    event DisputeOpened(uint256 indexed orderId, address indexed openedBy, bytes32 indexed disputeEvidenceHash);
    event DisputeEscalated(uint256 indexed orderId, bytes32 indexed resolutionHash);
    event ReturnApproved(uint256 indexed orderId, bytes32 indexed resolutionHash);
    event ReturnShipmentConfirmed(uint256 indexed orderId, bytes32 indexed returnShippingEvidenceHash);
    event ReturnReceived(uint256 indexed orderId, bytes32 indexed returnReceiptEvidenceHash, bool stockRestored);
    event ReturnShippingDisputeResolved(
        uint256 indexed orderId,
        uint256 buyerAmount,
        uint256 producerAmount,
        uint256 treasuryFee,
        bytes32 resolutionHash
    );
    event OrderCompleted(uint256 indexed orderId, uint256 producerAmount, uint256 treasuryFee);
    event OrderRefunded(uint256 indexed orderId, uint256 buyerAmount, bool shipmentFailure);
    event ProducerFaultRecorded(uint256 indexed orderId, address indexed producer, bytes32 indexed resolutionHash);
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
    error DeadlineExpired();
    error ShipmentDeadlineExpired();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    modifier onlyResolver() {
        if (msg.sender != resolver) revert Unauthorized();
        _;
    }

    modifier onlyVerifier() {
        if (msg.sender != verifier) revert Unauthorized();
        _;
    }

    constructor(
        address initialGovernance,
        address initialResolver,
        address initialVerifier,
        address initialTreasury,
        IERC20 paymentToken_,
        ProducerRegistry producerRegistry_,
        RuralProducts1155 ruralProducts_
    ) {
        if (
            initialGovernance == address(0) || initialResolver == address(0) || initialVerifier == address(0)
                || initialTreasury == address(0) || address(paymentToken_) == address(0)
                || address(producerRegistry_) == address(0) || address(ruralProducts_) == address(0)
        ) revert ZeroAddress();

        governance = initialGovernance;
        resolver = initialResolver;
        verifier = initialVerifier;
        treasury = initialTreasury;
        paymentToken = paymentToken_;
        producerRegistry = producerRegistry_;
        ruralProducts = ruralProducts_;
    }

    function setGovernance(address newGovernance) external onlyGovernance {
        if (newGovernance == address(0)) revert ZeroAddress();
        address previousGovernance = governance;
        governance = newGovernance;
        emit GovernanceUpdated(previousGovernance, newGovernance);
    }

    function setResolver(address newResolver) external onlyGovernance {
        if (newResolver == address(0)) revert ZeroAddress();
        address previousResolver = resolver;
        resolver = newResolver;
        emit ResolverUpdated(previousResolver, newResolver);
    }

    function setVerifier(address newVerifier) external onlyGovernance {
        if (newVerifier == address(0)) revert ZeroAddress();
        address previousVerifier = verifier;
        verifier = newVerifier;
        emit VerifierUpdated(previousVerifier, newVerifier);
    }

    function setTreasury(address newTreasury) external onlyGovernance {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previousTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(previousTreasury, newTreasury);
    }

    function setPurchasesPaused(bool paused) external onlyGovernance {
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
            returnApprovedAt: 0,
            status: OrderStatus.Paid,
            agreementHash: agreementHash,
            shippingEvidenceHash: bytes32(0),
            disputeEvidenceHash: bytes32(0),
            resolutionHash: bytes32(0),
            returnShippingEvidenceHash: bytes32(0),
            returnReceiptEvidenceHash: bytes32(0)
        });

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        ruralProducts.allocateToBuyer(msg.sender, lotId, quantity);

        emit OrderCreated(orderId, lotId, msg.sender, lot.producer, quantity, amount, agreementHash);
    }

    function confirmShipment(uint256 orderId, bytes32 shippingEvidenceHash) external onlyVerifier {
        if (shippingEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Paid);
        if (block.timestamp >= uint256(order.purchasedAt) + SHIPMENT_DEADLINE) revert ShipmentDeadlineExpired();

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

    function confirmDelivery(uint256 orderId) external onlyVerifier {
        Order storage order = _requireStatus(orderId, OrderStatus.ProductSent);
        order.status = OrderStatus.Delivered;
        order.deliveredAt = uint64(block.timestamp);
        emit DeliveryConfirmed(orderId, msg.sender);
    }

    function refundForNoShipment(uint256 orderId, bytes32 resolutionHash) external onlyResolver nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Paid);
        if (block.timestamp < uint256(order.purchasedAt) + SHIPMENT_DEADLINE) revert DeadlineActive();

        order.status = OrderStatus.Refunded;
        order.resolutionHash = resolutionHash;

        ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, true);
        _recordProducerFault(orderId, order, resolutionHash);
        paymentToken.safeTransfer(order.buyer, order.amount);

        emit OrderRefunded(orderId, order.amount, true);
    }

    function openDispute(uint256 orderId, bytes32 disputeEvidenceHash) external {
        if (disputeEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = orders[orderId];
        if (msg.sender != order.buyer && msg.sender != resolver) revert Unauthorized();
        if (order.status != OrderStatus.ProductSent && order.status != OrderStatus.Delivered) revert InvalidStatus();

        order.status = OrderStatus.Disputed;
        order.disputeEvidenceHash = disputeEvidenceHash;
        emit DisputeOpened(orderId, msg.sender, disputeEvidenceHash);
    }

    function escalateDispute(uint256 orderId, bytes32 resolutionHash) external onlyResolver {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.Disputed);
        order.status = OrderStatus.Escalated;
        order.resolutionHash = resolutionHash;
        emit DisputeEscalated(orderId, resolutionHash);
    }

    function resolveDisputeForProducer(uint256 orderId, bytes32 resolutionHash) external onlyResolver nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        order.resolutionHash = resolutionHash;
        _complete(orderId, order);
    }

    function resolveDisputeForBuyer(uint256 orderId, bytes32 resolutionHash) external onlyResolver nonReentrant {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        order.status = OrderStatus.Refunded;
        order.resolutionHash = resolutionHash;

        ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, false);
        paymentToken.safeTransfer(order.buyer, order.amount);
        emit OrderRefunded(orderId, order.amount, false);
    }

    function resolveDisputeSplit(uint256 orderId, uint128 buyerAmount, bytes32 resolutionHash)
        external
        onlyResolver
        nonReentrant
    {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        if (buyerAmount == 0 || buyerAmount >= order.amount) revert InvalidAmount();

        order.status = OrderStatus.PartiallyResolved;
        order.resolutionHash = resolutionHash;

        uint256 grossProducerAmount = uint256(order.amount) - buyerAmount;
        (uint256 producerAmount, uint256 treasuryFee) = _paymentSplit(order.producer, grossProducerAmount);

        ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, false);
        paymentToken.safeTransfer(order.buyer, buyerAmount);
        paymentToken.safeTransfer(order.producer, producerAmount);
        paymentToken.safeTransfer(treasury, treasuryFee);

        emit OrderPartiallyResolved(orderId, buyerAmount, producerAmount, treasuryFee);
    }

    function approveReturn(uint256 orderId, bytes32 resolutionHash) external onlyResolver {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireResolvableDispute(orderId);
        order.status = OrderStatus.ReturnApproved;
        order.returnApprovedAt = uint64(block.timestamp);
        order.resolutionHash = resolutionHash;
        emit ReturnApproved(orderId, resolutionHash);
    }

    function confirmReturnShipment(uint256 orderId, bytes32 returnShippingEvidenceHash) external onlyVerifier {
        if (returnShippingEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.ReturnApproved);
        if (block.timestamp >= uint256(order.returnApprovedAt) + RETURN_SHIPMENT_DEADLINE) revert DeadlineExpired();
        order.status = OrderStatus.ReturnShipped;
        order.returnShippingEvidenceHash = returnShippingEvidenceHash;
        emit ReturnShipmentConfirmed(orderId, returnShippingEvidenceHash);
    }

    function confirmReturnReceivedAndRefund(uint256 orderId, bytes32 returnReceiptEvidenceHash, bool restoreStock)
        external
        onlyResolver
        nonReentrant
    {
        if (returnReceiptEvidenceHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.ReturnShipped);
        order.status = OrderStatus.Refunded;
        order.returnReceiptEvidenceHash = returnReceiptEvidenceHash;

        ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, restoreStock);
        paymentToken.safeTransfer(order.buyer, order.amount);

        emit ReturnReceived(orderId, returnReceiptEvidenceHash, restoreStock);
        emit OrderRefunded(orderId, order.amount, false);
    }

    function resolveExpiredReturnForProducer(uint256 orderId, bytes32 resolutionHash)
        external
        onlyResolver
        nonReentrant
    {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.ReturnApproved);
        if (block.timestamp < uint256(order.returnApprovedAt) + RETURN_SHIPMENT_DEADLINE) revert DeadlineActive();
        order.resolutionHash = resolutionHash;
        _complete(orderId, order);
    }

    function resolveReturnShippingDispute(uint256 orderId, uint128 buyerAmount, bytes32 resolutionHash)
        external
        onlyResolver
        nonReentrant
    {
        if (resolutionHash == bytes32(0)) revert InvalidHash();
        Order storage order = _requireStatus(orderId, OrderStatus.ReturnShipped);
        if (buyerAmount > order.amount) revert InvalidAmount();
        order.resolutionHash = resolutionHash;

        if (buyerAmount == 0) {
            (uint256 fullProducerAmount, uint256 fullTreasuryFee) = _paymentSplit(order.producer, order.amount);
            _complete(orderId, order);
            emit ReturnShippingDisputeResolved(orderId, 0, fullProducerAmount, fullTreasuryFee, resolutionHash);
            return;
        }

        if (buyerAmount == order.amount) {
            order.status = OrderStatus.Refunded;
            ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, false);
            paymentToken.safeTransfer(order.buyer, buyerAmount);
            emit OrderRefunded(orderId, buyerAmount, false);
            emit ReturnShippingDisputeResolved(orderId, buyerAmount, 0, 0, resolutionHash);
            return;
        }

        order.status = OrderStatus.PartiallyResolved;
        uint256 grossProducerAmount = uint256(order.amount) - buyerAmount;
        (uint256 producerAmount, uint256 treasuryFee) = _paymentSplit(order.producer, grossProducerAmount);
        ruralProducts.burnRefunded(order.buyer, order.lotId, order.quantity, false);
        paymentToken.safeTransfer(order.buyer, buyerAmount);
        paymentToken.safeTransfer(order.producer, producerAmount);
        paymentToken.safeTransfer(treasury, treasuryFee);
        emit OrderPartiallyResolved(orderId, buyerAmount, producerAmount, treasuryFee);
        emit ReturnShippingDisputeResolved(orderId, buyerAmount, producerAmount, treasuryFee, resolutionHash);
    }

    function requiresLogisticsReview(uint256 orderId) external view returns (bool) {
        Order storage order = orders[orderId];
        return
            order.status == OrderStatus.ProductSent
                && block.timestamp >= uint256(order.sentAt) + LOGISTICS_REVIEW_PERIOD;
    }

    function returnShipmentDeadline(uint256 orderId) external view returns (uint256) {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.ReturnApproved) return 0;
        return uint256(order.returnApprovedAt) + RETURN_SHIPMENT_DEADLINE;
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

    function _recordProducerFault(uint256 orderId, Order storage order, bytes32 resolutionHash) private {
        producerRegistry.reportShipmentFailure(order.producer);
        emit ProducerFaultRecorded(orderId, order.producer, resolutionHash);
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
