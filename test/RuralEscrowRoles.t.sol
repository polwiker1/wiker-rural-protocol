// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RuralEscrowRolesTest is Test {
    address internal governance = address(0x600);
    address internal resolver = address(0x650);
    address internal verifier = address(0x700);
    address internal treasury = address(0x7EA);
    address internal producer = address(0xBEEF);
    address internal buyer = address(0xA11CE);

    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal usdc;

    function setUp() public {
        registry = new ProducerRegistry(governance);
        products = new RuralProducts1155(governance, "https://api.wiker.example/lots/{id}.json");
        usdc = new MockUSDC();
        escrow = new RuralEscrow(governance, resolver, verifier, treasury, usdc, registry, products);

        vm.startPrank(governance);
        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));
        registry.registerProducer(producer, keccak256("producer"));
        products.createLot(1, producer, 100, 10e6, keccak256("lot"));
        vm.stopPrank();

        usdc.mint(buyer, 100e6);
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function testVerifierCanConfirmShipmentButCannotMoveFunds() public {
        uint256 orderId = _purchase();
        vm.prank(verifier);
        escrow.confirmShipment(orderId, keccak256("shipment"));

        vm.prank(verifier);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.resolveDisputeForBuyer(orderId, keccak256("resolution"));
    }

    function testResolverCanRefundButCannotChangeConfiguration() public {
        uint256 orderId = _purchase();
        vm.warp(block.timestamp + escrow.SHIPMENT_DEADLINE());
        vm.prank(resolver);
        escrow.refundForNoShipment(orderId, keccak256("no-shipment"));

        vm.prank(resolver);
        vm.expectRevert(RuralEscrow.Unauthorized.selector);
        escrow.setTreasury(address(0x999));
    }

    function testGovernanceCanRotateOperationalRoles() public {
        address newResolver = address(0x651);
        address newVerifier = address(0x701);

        vm.startPrank(governance);
        escrow.setResolver(newResolver);
        escrow.setVerifier(newVerifier);
        vm.stopPrank();

        assertEq(escrow.resolver(), newResolver);
        assertEq(escrow.verifier(), newVerifier);
    }

    function _purchase() private returns (uint256 orderId) {
        vm.prank(buyer);
        orderId = escrow.purchase(1, 1, 10e6, keccak256("agreement"));
    }
}
