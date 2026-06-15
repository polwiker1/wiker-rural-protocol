// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RunFiveProducerDemo} from "../script/RunFiveProducerDemo.s.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RunFiveProducerDemoTest is Test {
    uint256 internal constant ADMIN_PRIVATE_KEY = 0xA11CE;
    uint256 internal constant PRODUCER_KEY_BASE = 20_000;

    address internal admin;
    address internal treasury = address(0x7EA);

    ProducerRegistry internal registry;
    RuralProducts1155 internal products;
    RuralEscrow internal escrow;
    MockUSDC internal mockUsdc;

    function setUp() public {
        admin = vm.addr(ADMIN_PRIVATE_KEY);
        vm.deal(admin, 10 ether);

        registry = new ProducerRegistry(admin);
        products = new RuralProducts1155(admin, "https://api.wiker.example/lots/{id}.json");
        mockUsdc = new MockUSDC();
        escrow = new RuralEscrow(admin, admin, admin, treasury, mockUsdc, registry, products);

        vm.startPrank(admin);
        registry.setEscrow(address(escrow));
        products.setEscrow(address(escrow));
        vm.stopPrank();

        vm.setEnv("PRIVATE_KEY", vm.toString(ADMIN_PRIVATE_KEY));
        vm.setEnv("PRODUCER_REGISTRY_ADDRESS", vm.toString(address(registry)));
        vm.setEnv("RURAL_PRODUCTS_ADDRESS", vm.toString(address(products)));
        vm.setEnv("RURAL_ESCROW_ADDRESS", vm.toString(address(escrow)));
        vm.setEnv("MOCK_USDC_ADDRESS", vm.toString(address(mockUsdc)));
    }

    function testRunsFiveIndependentProducerSales() public {
        RunFiveProducerDemo script = new RunFiveProducerDemo();
        script.run();

        uint128[5] memory maxSupply = [uint128(50), 80, 200, 40, 120];
        uint128[5] memory soldQuantity = [uint128(3), 2, 10, 1, 5];
        uint128[5] memory unitPrice = [uint128(5e6), 8e6, 3e6, 12e6, 4e6];

        for (uint256 i = 0; i < 5; i++) {
            address producer = vm.addr(PRODUCER_KEY_BASE + i);
            uint256 lotId = i + 2;
            uint256 grossAmount = uint256(unitPrice[i]) * soldQuantity[i];

            assertTrue(registry.isActiveProducer(producer));
            assertEq(products.availableSupply(lotId), maxSupply[i] - soldQuantity[i]);
            assertEq(products.balanceOf(admin, lotId), 0);
            assertEq(mockUsdc.balanceOf(producer), grossAmount * 99 / 100);
        }

        assertEq(escrow.nextOrderId(), 6);
        assertEq(mockUsdc.balanceOf(address(escrow)), 0);
        assertEq(mockUsdc.balanceOf(treasury), 930_000);
        assertEq(mockUsdc.balanceOf(admin), 7e6);
    }
}
