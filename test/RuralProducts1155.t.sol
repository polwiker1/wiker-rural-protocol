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
        assertEq(lot.allocatedSupply, 0);
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
        assertEq(lot.allocatedSupply, 20);
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
        assertEq(token.availableSupply(LOT_ID), 980);
    }

    function testUnsuccessfulOrderBurnsAndDoesNotRestoreSupply() public {
        vm.startPrank(escrow);
        token.allocateToBuyer(buyer, LOT_ID, 20);
        token.burnFailed(buyer, LOT_ID, 20);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer, LOT_ID), 0);
        assertEq(token.availableSupply(LOT_ID), 980);
    }
}
