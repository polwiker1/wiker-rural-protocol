// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract DeployRuralProtocolTestnet is Script {
    uint256 public constant DEMO_LOT_ID = 1;
    uint128 public constant DEMO_MAX_SUPPLY = 100;
    uint128 public constant DEMO_UNIT_PRICE = 10e6;
    uint256 public constant DEMO_BUYER_BALANCE = 1_000e6;

    struct DeploymentConfig {
        address deployer;
        address governance;
        address resolver;
        address verifier;
        address treasury;
        address demoProducer;
        address demoBuyer;
    }

    function run()
        external
        returns (ProducerRegistry registry, RuralProducts1155 products, RuralEscrow escrow, MockUSDC mockUsdc)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        DeploymentConfig memory config;
        config.deployer = vm.addr(deployerPrivateKey);
        config.governance = vm.envOr("GOVERNANCE_ADDRESS", config.deployer);
        config.resolver = vm.envOr("RESOLVER_ADDRESS", config.deployer);
        config.verifier = vm.envOr("VERIFIER_ADDRESS", config.deployer);
        config.treasury = vm.envOr("TREASURY_ADDRESS", config.deployer);
        config.demoProducer = vm.envOr("DEMO_PRODUCER_ADDRESS", config.deployer);
        config.demoBuyer = vm.envOr("DEMO_BUYER_ADDRESS", config.deployer);

        vm.startBroadcast(deployerPrivateKey);

        registry = new ProducerRegistry(config.deployer);
        products = new RuralProducts1155(config.deployer, "https://api.wiker.com.ar/lots/{id}.json");
        mockUsdc = new MockUSDC();
        escrow = new RuralEscrow(
            config.governance, config.resolver, config.verifier, config.treasury, mockUsdc, registry, products
        );

        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));

        registry.registerProducer(config.demoProducer, keccak256("wiker-testnet-demo-producer"));
        products.createLot(
            DEMO_LOT_ID, config.demoProducer, DEMO_MAX_SUPPLY, DEMO_UNIT_PRICE, keccak256("wiker-testnet-demo-lot")
        );
        mockUsdc.mint(config.demoBuyer, DEMO_BUYER_BALANCE);
        registry.setAdmin(config.governance);
        products.setAdmin(config.governance);

        vm.stopBroadcast();

        console2.log("Deployer:", config.deployer);
        console2.log("Governance:", config.governance);
        console2.log("Resolver:", config.resolver);
        console2.log("Verifier:", config.verifier);
        console2.log("Treasury:", config.treasury);
        console2.log("Demo producer:", config.demoProducer);
        console2.log("Demo buyer:", config.demoBuyer);
        console2.log("ProducerRegistry:", address(registry));
        console2.log("RuralProducts1155:", address(products));
        console2.log("RuralEscrow:", address(escrow));
        console2.log("MockUSDC:", address(mockUsdc));
    }
}
