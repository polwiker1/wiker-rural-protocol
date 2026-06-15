// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ProducerRegistry {
    uint16 public constant STANDARD_FEE_BPS = 100;
    uint16 public constant PENALIZED_FEE_BPS = 500;

    enum ProducerStatus {
        Unregistered,
        Active,
        Suspended
    }

    struct Producer {
        ProducerStatus status;
        uint32 shipmentFailures;
        bytes32 profileHash;
    }

    address public admin;
    address public escrow;

    mapping(address producer => Producer) private producers;
    mapping(address producer => uint16) private producerFeeBps;

    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event EscrowUpdated(address indexed previousEscrow, address indexed newEscrow);
    event ProducerRegistered(address indexed producer, bytes32 indexed profileHash);
    event ProducerProfileUpdated(address indexed producer, bytes32 indexed profileHash);
    event ProducerStatusUpdated(address indexed producer, ProducerStatus previousStatus, ProducerStatus newStatus);
    event ShipmentFailureReported(address indexed producer, uint32 failureCount);
    event ProducerFeeUpdated(address indexed producer, uint16 previousFeeBps, uint16 newFeeBps);

    error Unauthorized();
    error ZeroAddress();
    error ProducerAlreadyRegistered();
    error ProducerNotRegistered();
    error InvalidFee();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyEscrow() {
        if (msg.sender != escrow) revert Unauthorized();
        _;
    }

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddress();
        admin = initialAdmin;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(previousAdmin, newAdmin);
    }

    function setEscrow(address newEscrow) external onlyAdmin {
        if (newEscrow == address(0)) revert ZeroAddress();
        address previousEscrow = escrow;
        escrow = newEscrow;
        emit EscrowUpdated(previousEscrow, newEscrow);
    }

    function registerProducer(address producer, bytes32 profileHash) external onlyAdmin {
        if (producer == address(0)) revert ZeroAddress();
        if (producers[producer].status != ProducerStatus.Unregistered) revert ProducerAlreadyRegistered();

        producers[producer] = Producer({status: ProducerStatus.Active, shipmentFailures: 0, profileHash: profileHash});
        producerFeeBps[producer] = STANDARD_FEE_BPS;

        emit ProducerRegistered(producer, profileHash);
        emit ProducerStatusUpdated(producer, ProducerStatus.Unregistered, ProducerStatus.Active);
    }

    function updateProfileHash(address producer, bytes32 profileHash) external onlyAdmin {
        _requireRegistered(producer);
        producers[producer].profileHash = profileHash;
        emit ProducerProfileUpdated(producer, profileHash);
    }

    function suspendProducer(address producer) external onlyAdmin {
        _setStatus(producer, ProducerStatus.Suspended);
    }

    function reactivateProducer(address producer) external onlyAdmin {
        _setStatus(producer, ProducerStatus.Active);
    }

    function setProducerFeeBps(address producer, uint16 newFeeBps) external onlyAdmin {
        _requireRegistered(producer);
        if (newFeeBps > 10_000) revert InvalidFee();
        _setProducerFee(producer, newFeeBps);
    }

    function reportShipmentFailure(address producer) external onlyEscrow returns (uint32 failureCount) {
        _requireRegistered(producer);

        Producer storage record = producers[producer];
        failureCount = ++record.shipmentFailures;
        emit ShipmentFailureReported(producer, failureCount);

        if (failureCount == 1) {
            _setProducerFee(producer, PENALIZED_FEE_BPS);
        }

        if (failureCount >= 2 && record.status != ProducerStatus.Suspended) {
            ProducerStatus previousStatus = record.status;
            record.status = ProducerStatus.Suspended;
            emit ProducerStatusUpdated(producer, previousStatus, ProducerStatus.Suspended);
        }
    }

    function isActiveProducer(address producer) external view returns (bool) {
        return producers[producer].status == ProducerStatus.Active;
    }

    function getProducer(address producer) external view returns (Producer memory) {
        return producers[producer];
    }

    function feeBps(address producer) external view returns (uint16) {
        _requireRegistered(producer);
        return producerFeeBps[producer];
    }

    function _setStatus(address producer, ProducerStatus newStatus) private {
        _requireRegistered(producer);
        ProducerStatus previousStatus = producers[producer].status;
        producers[producer].status = newStatus;
        emit ProducerStatusUpdated(producer, previousStatus, newStatus);
    }

    function _requireRegistered(address producer) private view {
        if (producers[producer].status == ProducerStatus.Unregistered) revert ProducerNotRegistered();
    }

    function _setProducerFee(address producer, uint16 newFeeBps) private {
        uint16 previousFeeBps = producerFeeBps[producer];
        producerFeeBps[producer] = newFeeBps;
        emit ProducerFeeUpdated(producer, previousFeeBps, newFeeBps);
    }
}
