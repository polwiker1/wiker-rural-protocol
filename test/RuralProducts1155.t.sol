// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";

contract RuralProducts1155Test is Test {
    RuralProducts1155 internal token;

    address internal admin = address(0xAD);
    address internal escrow = address(0xE5C);
    address internal producer = address(0xBEEF);
    address internal buyer = address(0xA11CE);
    address internal secondBuyer = address(0xB0B);

    uint256 internal constant LOT_ID = 1;
    uint128 internal constant MAX_SUPPLY = 1_000;
    uint128 internal constant UNIT_PRICE = 10e6;
    bytes32 internal metadataHash = keccak256("lot-metadata-v1");

    function setUp() public {
        token = new RuralProducts1155(admin, "https://api.wiker.example/lots/{id}.json");

        vm.startPrank(admin);
        token.setEscrow(escrow);
        token.createLot(LOT_ID, producer, MAX_SUPPLY, UNIT_PRICE, metadataHash);
        vm.stopPrank();
    }

    function testAdminCreatesLotWithoutMintingToProducer() public view {
        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);

        assertEq(lot.producer, producer);
        assertEq(lot.maxSupply, MAX_SUPPLY);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.soldSupply, 0);
        assertEq(lot.retiredSupply, 0);
        assertEq(lot.unitPrice, UNIT_PRICE);
        assertEq(lot.metadataHash, metadataHash);
        assertTrue(lot.active);
        assertEq(token.balanceOf(producer, LOT_ID), 0);
        assertEq(token.availableSupply(LOT_ID), MAX_SUPPLY);
    }

    function testEscrowAllocatesUnitsDirectlyToBuyer() public {
        vm.prank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);

        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(token.balanceOf(buyer, LOT_ID), 20);
        assertEq(lot.reservedSupply, 20);
        assertEq(lot.soldSupply, 0);
        assertEq(token.availableSupply(LOT_ID), 980);
    }

    function testOnlyEscrowCanAllocateUnits() public {
        vm.prank(admin);
        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.allocateToBuyer(buyer, LOT_ID, 20);
    }

    function testCannotAllocateMoreThanApprovedSupply() public {
        vm.prank(escrow);
        vm.expectRevert(RuralProducts1155.SupplyExceeded.selector);
        token.allocateToBuyer(buyer, LOT_ID, MAX_SUPPLY + 1);
    }

    function testPausedLotCannotAllocateNewUnits() public {
        vm.prank(admin);
        token.setLotActive(LOT_ID, false);

        vm.prank(escrow);
        vm.expectRevert(RuralProducts1155.LotNotActive.selector);
        token.allocateToBuyer(buyer, LOT_ID, 1);
    }

    function testBuyerCannotTransferUnits() public {
        vm.prank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);

        vm.prank(buyer);
        vm.expectRevert(RuralProducts1155.NonTransferable.selector);
        token.safeTransferFrom(buyer, secondBuyer, LOT_ID, 1, "");
    }

    function testCompletedOrderBurnsButDoesNotRestoreSupply() public {
        vm.startPrank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);
        token.burnCompleted(buyer, LOT_ID, 20);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer, LOT_ID), 0);
        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.soldSupply, 20);
        assertEq(token.availableSupply(LOT_ID), 980);
    }

    function testRefundedOrderBurnsAndRestoresAvailableSupply() public {
        vm.startPrank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);
        token.burnRefunded(buyer, LOT_ID, 20, true);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer, LOT_ID), 0);
        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.soldSupply, 0);
        assertEq(token.availableSupply(LOT_ID), MAX_SUPPLY);
    }

    function testRefundedOrderCanRetireUnrecoveredStock() public {
        vm.startPrank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);
        token.burnRefunded(buyer, LOT_ID, 20, false);
        vm.stopPrank();

        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(lot.reservedSupply, 0);
        assertEq(lot.retiredSupply, 20);
        assertEq(token.availableSupply(LOT_ID), 980);
    }

    function testAdminCanRetireUnavailableStock() public {
        vm.prank(admin);
        token.retireAvailableSupply(LOT_ID, 30, keccak256("stock-unavailable"));

        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(lot.retiredSupply, 30);
        assertEq(token.availableSupply(LOT_ID), 970);
    }

    function testConstructorAndSettersRejectZeroAddresses() public {
        vm.expectRevert(RuralProducts1155.ZeroAddress.selector);
        new RuralProducts1155(address(0), "https://api.wiker.example/lots/{id}.json");

        vm.startPrank(admin);
        vm.expectRevert(RuralProducts1155.ZeroAddress.selector);
        token.setAdmin(address(0));

        vm.expectRevert(RuralProducts1155.ZeroAddress.selector);
        token.setEscrow(address(0));
        vm.stopPrank();
    }

    function testAdminCanRotateAdminEscrowAndBaseURI() public {
        address newAdmin = address(0xA1);
        address newEscrow = address(0xE1);

        vm.startPrank(admin);
        token.setBaseURI("https://api.wiker.example/v2/{id}.json");
        token.setAdmin(newAdmin);
        vm.stopPrank();

        assertEq(token.admin(), newAdmin);

        vm.prank(newAdmin);
        token.setEscrow(newEscrow);
        assertEq(token.escrow(), newEscrow);
    }

    function testCreateLotRejectsInvalidInputsAndDuplicateLot() public {
        vm.startPrank(admin);
        vm.expectRevert(RuralProducts1155.ZeroAddress.selector);
        token.createLot(2, address(0), MAX_SUPPLY, UNIT_PRICE, metadataHash);

        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.createLot(2, producer, 0, UNIT_PRICE, metadataHash);

        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.createLot(2, producer, MAX_SUPPLY, 0, metadataHash);

        vm.expectRevert(RuralProducts1155.LotAlreadyExists.selector);
        token.createLot(LOT_ID, producer, MAX_SUPPLY, UNIT_PRICE, metadataHash);
        vm.stopPrank();
    }

    function testLotAdminFunctionsRejectMissingLotAndInvalidPrice() public {
        vm.startPrank(admin);
        vm.expectRevert(RuralProducts1155.LotNotFound.selector);
        token.setLotActive(999, false);

        vm.expectRevert(RuralProducts1155.LotNotFound.selector);
        token.updateMetadataHash(999, keccak256("missing"));

        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.updateUnitPrice(LOT_ID, 0);

        vm.expectRevert(RuralProducts1155.LotNotFound.selector);
        token.updateUnitPrice(999, UNIT_PRICE);
        vm.stopPrank();
    }

    function testAdminCanUpdateMetadataAndUnitPrice() public {
        bytes32 updatedMetadataHash = keccak256("lot-metadata-v2");

        vm.startPrank(admin);
        token.updateMetadataHash(LOT_ID, updatedMetadataHash);
        token.updateUnitPrice(LOT_ID, UNIT_PRICE + 1e6);
        vm.stopPrank();

        RuralProducts1155.Lot memory lot = token.getLot(LOT_ID);
        assertEq(lot.metadataHash, updatedMetadataHash);
        assertEq(lot.unitPrice, UNIT_PRICE + 1e6);
    }

    function testAllocateRejectsInvalidInputsAndMissingLot() public {
        vm.startPrank(escrow);
        vm.expectRevert(RuralProducts1155.ZeroAddress.selector);
        token.allocateToBuyer(address(0), LOT_ID, 1);

        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.allocateToBuyer(buyer, LOT_ID, 0);

        vm.expectRevert(RuralProducts1155.LotNotFound.selector);
        token.allocateToBuyer(buyer, 999, 1);
        vm.stopPrank();
    }

    function testBurnsRejectZeroAmount() public {
        vm.startPrank(escrow);
        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.burnCompleted(buyer, LOT_ID, 0);

        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.burnRefunded(buyer, LOT_ID, 0, true);
        vm.stopPrank();
    }

    function testRetireAvailableSupplyRejectsInvalidInputs() public {
        vm.startPrank(admin);
        vm.expectRevert(RuralProducts1155.InvalidAmount.selector);
        token.retireAvailableSupply(LOT_ID, 0, keccak256("reason"));

        vm.expectRevert(RuralProducts1155.InvalidHash.selector);
        token.retireAvailableSupply(LOT_ID, 1, bytes32(0));

        vm.expectRevert(RuralProducts1155.LotNotFound.selector);
        token.retireAvailableSupply(999, 1, keccak256("missing"));

        vm.expectRevert(RuralProducts1155.SupplyExceeded.selector);
        token.retireAvailableSupply(LOT_ID, MAX_SUPPLY + 1, keccak256("too-much"));
        vm.stopPrank();
    }

    function testOnlyAdminCanCallAdminFunctions() public {
        vm.startPrank(secondBuyer);
        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.setAdmin(secondBuyer);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.setEscrow(secondBuyer);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.setBaseURI("https://bad.example/{id}.json");

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.createLot(2, producer, MAX_SUPPLY, UNIT_PRICE, metadataHash);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.setLotActive(LOT_ID, false);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.updateMetadataHash(LOT_ID, metadataHash);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.updateUnitPrice(LOT_ID, UNIT_PRICE);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.retireAvailableSupply(LOT_ID, 1, keccak256("reason"));
        vm.stopPrank();
    }

    function testOnlyEscrowCanBurnUnits() public {
        vm.startPrank(secondBuyer);
        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.burnCompleted(buyer, LOT_ID, 1);

        vm.expectRevert(RuralProducts1155.Unauthorized.selector);
        token.burnRefunded(buyer, LOT_ID, 1, true);
        vm.stopPrank();
    }
}
