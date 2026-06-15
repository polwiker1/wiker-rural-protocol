// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

contract RuralProducts1155 is ERC1155 {
    using SafeCast for uint256;

    struct Lot {
        address producer;
        uint128 maxSupply;
        uint128 reservedSupply;
        uint128 soldSupply;
        uint128 retiredSupply;
        uint128 unitPrice;
        bytes32 metadataHash;
        bool active;
    }

    address public admin;
    address public escrow;

    mapping(uint256 tokenId => Lot) private lots;

    event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);
    event EscrowUpdated(address indexed previousEscrow, address indexed newEscrow);
    event LotCreated(
        uint256 indexed tokenId,
        address indexed producer,
        uint128 maxSupply,
        uint128 unitPrice,
        bytes32 indexed metadataHash
    );
    event LotStatusUpdated(uint256 indexed tokenId, bool active);
    event LotMetadataUpdated(uint256 indexed tokenId, bytes32 indexed metadataHash);
    event LotUnitPriceUpdated(uint256 indexed tokenId, uint128 previousUnitPrice, uint128 newUnitPrice);
    event UnitsAllocated(uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event UnitsCompleted(uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event UnitsRefunded(uint256 indexed tokenId, address indexed buyer, uint256 amount, bool stockRestored);
    event UnitsRetired(uint256 indexed tokenId, uint256 amount, bytes32 indexed reasonHash);

    error Unauthorized();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidHash();
    error LotAlreadyExists();
    error LotNotFound();
    error LotNotActive();
    error SupplyExceeded();
    error NonTransferable();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyEscrow() {
        if (msg.sender != escrow) revert Unauthorized();
        _;
    }

    constructor(address initialAdmin, string memory baseURI) ERC1155(baseURI) {
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

    function setBaseURI(string calldata newBaseURI) external onlyAdmin {
        _setURI(newBaseURI);
    }

    function createLot(uint256 tokenId, address producer, uint128 maxSupply, uint128 unitPrice, bytes32 metadataHash)
        external
        onlyAdmin
    {
        if (producer == address(0)) revert ZeroAddress();
        if (maxSupply == 0 || unitPrice == 0) revert InvalidAmount();
        if (lots[tokenId].producer != address(0)) revert LotAlreadyExists();

        lots[tokenId] = Lot({
            producer: producer,
            maxSupply: maxSupply,
            reservedSupply: 0,
            soldSupply: 0,
            retiredSupply: 0,
            unitPrice: unitPrice,
            metadataHash: metadataHash,
            active: true
        });

        emit LotCreated(tokenId, producer, maxSupply, unitPrice, metadataHash);
        emit LotStatusUpdated(tokenId, true);
    }

    function setLotActive(uint256 tokenId, bool active) external onlyAdmin {
        _requireLot(tokenId);
        lots[tokenId].active = active;
        emit LotStatusUpdated(tokenId, active);
    }

    function updateMetadataHash(uint256 tokenId, bytes32 metadataHash) external onlyAdmin {
        _requireLot(tokenId);
        lots[tokenId].metadataHash = metadataHash;
        emit LotMetadataUpdated(tokenId, metadataHash);
    }

    function updateUnitPrice(uint256 tokenId, uint128 newUnitPrice) external onlyAdmin {
        if (newUnitPrice == 0) revert InvalidAmount();
        _requireLot(tokenId);
        uint128 previousUnitPrice = lots[tokenId].unitPrice;
        lots[tokenId].unitPrice = newUnitPrice;
        emit LotUnitPriceUpdated(tokenId, previousUnitPrice, newUnitPrice);
    }

    function allocateToBuyer(address buyer, uint256 tokenId, uint256 amount) external onlyEscrow {
        if (buyer == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        _requireLot(tokenId);

        Lot storage lot = lots[tokenId];
        if (!lot.active) revert LotNotActive();
        if (amount > _availableSupply(lot)) revert SupplyExceeded();

        lot.reservedSupply += amount.toUint128();
        _mint(buyer, tokenId, amount, "");
        emit UnitsAllocated(tokenId, buyer, amount);
    }

    function burnCompleted(address buyer, uint256 tokenId, uint256 amount) external onlyEscrow {
        if (amount == 0) revert InvalidAmount();
        Lot storage lot = lots[tokenId];
        lot.reservedSupply -= amount.toUint128();
        lot.soldSupply += amount.toUint128();
        _burn(buyer, tokenId, amount);
        emit UnitsCompleted(tokenId, buyer, amount);
    }

    function burnRefunded(address buyer, uint256 tokenId, uint256 amount, bool restoreStock) external onlyEscrow {
        if (amount == 0) revert InvalidAmount();
        Lot storage lot = lots[tokenId];
        lot.reservedSupply -= amount.toUint128();
        if (!restoreStock) lot.retiredSupply += amount.toUint128();
        _burn(buyer, tokenId, amount);
        emit UnitsRefunded(tokenId, buyer, amount, restoreStock);
    }

    function retireAvailableSupply(uint256 tokenId, uint256 amount, bytes32 reasonHash) external onlyAdmin {
        if (amount == 0) revert InvalidAmount();
        if (reasonHash == bytes32(0)) revert InvalidHash();
        _requireLot(tokenId);

        Lot storage lot = lots[tokenId];
        if (amount > _availableSupply(lot)) revert SupplyExceeded();
        lot.retiredSupply += amount.toUint128();
        emit UnitsRetired(tokenId, amount, reasonHash);
    }

    function availableSupply(uint256 tokenId) external view returns (uint256) {
        return _availableSupply(lots[tokenId]);
    }

    function getLot(uint256 tokenId) external view returns (Lot memory) {
        return lots[tokenId];
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        if (from != address(0) && to != address(0)) revert NonTransferable();
        super._update(from, to, ids, values);
    }

    function _requireLot(uint256 tokenId) private view {
        if (lots[tokenId].producer == address(0)) revert LotNotFound();
    }

    function _availableSupply(Lot storage lot) private view returns (uint256) {
        return
            uint256(lot.maxSupply) - uint256(lot.reservedSupply) - uint256(lot.soldSupply) - uint256(lot.retiredSupply);
    }
}
