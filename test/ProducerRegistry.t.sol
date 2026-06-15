// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";

contract ProducerRegistryTest is Test {
    ProducerRegistry internal registry;

    address internal admin = address(0xAD);
    address internal escrow = address(0xE5C);
    address internal producer = address(0xBEEF);
    address internal stranger = address(0xBAD);
    bytes32 internal profileHash = keccak256("private-producer-profile-v1");

    function setUp() public {
        registry = new ProducerRegistry(admin);

        vm.prank(admin);
        registry.setEscrow(escrow);
    }

    function testAdminRegistersProducer() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        ProducerRegistry.Producer memory record = registry.getProducer(producer);
        assertEq(uint256(record.status), uint256(ProducerRegistry.ProducerStatus.Active));
        assertEq(record.shipmentFailures, 0);
        assertEq(record.profileHash, profileHash);
        assertEq(registry.feeBps(producer), 100);
        assertTrue(registry.isActiveProducer(producer));
    }

    function testOnlyAdminCanRegisterProducer() public {
        vm.prank(stranger);
        vm.expectRevert(ProducerRegistry.Unauthorized.selector);
        registry.registerProducer(producer, profileHash);
    }

    function testCannotRegisterProducerTwice() public {
        vm.startPrank(admin);
        registry.registerProducer(producer, profileHash);

        vm.expectRevert(ProducerRegistry.ProducerAlreadyRegistered.selector);
        registry.registerProducer(producer, profileHash);
        vm.stopPrank();
    }

    function testOnlyEscrowCanReportShipmentFailure() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        vm.prank(stranger);
        vm.expectRevert(ProducerRegistry.Unauthorized.selector);
        registry.reportShipmentFailure(producer);
    }

    function testFirstFailureWarnsButKeepsProducerActive() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        vm.prank(escrow);
        uint32 failures = registry.reportShipmentFailure(producer);

        assertEq(failures, 1);
        assertEq(registry.feeBps(producer), 500);
        assertTrue(registry.isActiveProducer(producer));
    }

    function testSecondFailureSuspendsProducer() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        vm.startPrank(escrow);
        registry.reportShipmentFailure(producer);
        uint32 failures = registry.reportShipmentFailure(producer);
        vm.stopPrank();

        ProducerRegistry.Producer memory record = registry.getProducer(producer);
        assertEq(failures, 2);
        assertEq(uint256(record.status), uint256(ProducerRegistry.ProducerStatus.Suspended));
        assertFalse(registry.isActiveProducer(producer));
    }

    function testAdminCanReactivateSuspendedProducerWithoutClearingHistory() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        vm.startPrank(escrow);
        registry.reportShipmentFailure(producer);
        registry.reportShipmentFailure(producer);
        vm.stopPrank();

        vm.prank(admin);
        registry.reactivateProducer(producer);

        ProducerRegistry.Producer memory record = registry.getProducer(producer);
        assertEq(uint256(record.status), uint256(ProducerRegistry.ProducerStatus.Active));
        assertEq(record.shipmentFailures, 2);
        assertEq(registry.feeBps(producer), 500);
    }

    function testAdminCanRestoreStandardFeeAfterReview() public {
        vm.prank(admin);
        registry.registerProducer(producer, profileHash);

        vm.prank(escrow);
        registry.reportShipmentFailure(producer);

        vm.prank(admin);
        registry.setProducerFeeBps(producer, 100);

        assertEq(registry.feeBps(producer), 100);
    }
}
