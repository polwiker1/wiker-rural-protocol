// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployRuralProtocolTestnet} from "../script/DeployRuralProtocolTestnet.s.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract DeployRuralProtocolTestnetTest is Test {
    uint256 internal constant DEPLOYER_PRIVATE_KEY = 0xA11CE;
    address internal deployer;
    address internal governance = address(0x600);
    address internal resolver = address(0x650);
    address internal verifier = address(0x700);
    address internal treasury = address(0x7EA);
    address internal producer = address(0xBEEF);
    address internal buyer = address(0xB0B);

    function setUp() public {
        deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        vm.setEnv("PRIVATE_KEY", vm.toString(DEPLOYER_PRIVATE_KEY));
        vm.setEnv("GOVERNANCE_ADDRESS", vm.toString(governance));
        vm.setEnv("RESOLVER_ADDRESS", vm.toString(resolver));
        vm.setEnv("VERIFIER_ADDRESS", vm.toString(verifier));
        vm.setEnv("TREASURY_ADDRESS", vm.toString(treasury));
        vm.setEnv("DEMO_PRODUCER_ADDRESS", vm.toString(producer));
        vm.setEnv("DEMO_BUYER_ADDRESS", vm.toString(buyer));
    }

    function testDeploysAndConnectsCompleteTestnetProtocol() public {
        DeployRuralProtocolTestnet script = new DeployRuralProtocolTestnet();

        (ProducerRegistry registry, RuralProducts1155 products, RuralEscrow escrow, MockUSDC mockUsdc) = script.run();

        assertEq(registry.admin(), governance);
        assertEq(products.admin(), governance);
        assertEq(escrow.governance(), governance);
        assertEq(escrow.resolver(), resolver);
        assertEq(escrow.verifier(), verifier);
        assertEq(escrow.treasury(), treasury);
        assertEq(address(escrow.paymentToken()), address(mockUsdc));
        assertEq(address(escrow.producerRegistry()), address(registry));
        assertEq(address(escrow.ruralProducts()), address(products));
        assertEq(registry.escrow(), address(escrow));
        assertEq(products.escrow(), address(escrow));
        assertTrue(registry.isActiveProducer(producer));
        assertEq(products.availableSupply(script.DEMO_LOT_ID()), script.DEMO_MAX_SUPPLY());
        assertEq(mockUsdc.balanceOf(buyer), script.DEMO_BUYER_BALANCE());
    }
}
