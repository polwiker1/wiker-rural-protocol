// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ProducerRegistry} from "../src/ProducerRegistry.sol";
import {RuralProducts1155} from "../src/RuralProducts1155.sol";
import {RuralEscrow} from "../src/RuralEscrow.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract RunFiveProducerDemo is Script {
    uint256 private constant PRODUCER_KEY_BASE = 20_000;
    uint256 private constant BUYER_MOCK_USDC_BALANCE = 100e6;

    struct DemoLot {
        uint256 lotId;
        uint128 maxSupply;
        uint128 unitPrice;
        uint128 purchaseQuantity;
        string product;
    }

    function run() external {
        uint256 defaultPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 governancePrivateKey = vm.envOr("GOVERNANCE_PRIVATE_KEY", defaultPrivateKey);
        uint256 verifierPrivateKey = vm.envOr("VERIFIER_PRIVATE_KEY", defaultPrivateKey);
        uint256 buyerPrivateKey = vm.envOr("BUYER_PRIVATE_KEY", defaultPrivateKey);
        address demoBuyer = vm.addr(buyerPrivateKey);
        ProducerRegistry registry = ProducerRegistry(vm.envAddress("PRODUCER_REGISTRY_ADDRESS"));
        RuralProducts1155 products = RuralProducts1155(vm.envAddress("RURAL_PRODUCTS_ADDRESS"));
        RuralEscrow escrow = RuralEscrow(vm.envAddress("RURAL_ESCROW_ADDRESS"));
        MockUSDC mockUsdc = MockUSDC(vm.envAddress("MOCK_USDC_ADDRESS"));

        DemoLot[5] memory lots = _demoLots();
        address[5] memory producers;

        for (uint256 i = 0; i < lots.length; i++) {
            producers[i] = vm.addr(PRODUCER_KEY_BASE + i);
        }

        vm.startBroadcast(governancePrivateKey);
        for (uint256 i = 0; i < lots.length; i++) {
            registry.registerProducer(producers[i], keccak256(bytes(string.concat("demo-producer-", lots[i].product))));
            products.createLot(
                lots[i].lotId,
                producers[i],
                lots[i].maxSupply,
                lots[i].unitPrice,
                keccak256(bytes(string.concat("demo-lot-", lots[i].product)))
            );
        }
        mockUsdc.mint(demoBuyer, BUYER_MOCK_USDC_BALANCE);
        vm.stopBroadcast();

        for (uint256 i = 0; i < lots.length; i++) {
            uint128 totalAmount = lots[i].unitPrice * lots[i].purchaseQuantity;

            vm.startBroadcast(buyerPrivateKey);
            mockUsdc.approve(address(escrow), totalAmount);
            uint256 orderId = escrow.purchase(
                lots[i].lotId,
                lots[i].purchaseQuantity,
                totalAmount,
                keccak256(bytes(string.concat("demo-agreement-", lots[i].product)))
            );
            vm.stopBroadcast();

            vm.startBroadcast(verifierPrivateKey);
            escrow.confirmShipment(orderId, keccak256(bytes(string.concat("demo-shipment-", lots[i].product))));
            vm.stopBroadcast();

            vm.startBroadcast(buyerPrivateKey);
            escrow.confirmReceipt(orderId);
            vm.stopBroadcast();

            console2.log("Product:", lots[i].product);
            console2.log("Lot ID:", lots[i].lotId);
            console2.log("Order ID:", orderId);
            console2.log("Producer:", producers[i]);
            console2.log("Buyer:", demoBuyer);
            console2.log("Sold quantity:", lots[i].purchaseQuantity);
            console2.log("Total MockUSDC:", totalAmount);
        }
    }

    function _demoLots() private pure returns (DemoLot[5] memory lots) {
        lots[0] = DemoLot({lotId: 2, maxSupply: 50, unitPrice: 5e6, purchaseQuantity: 3, product: "Miel"});
        lots[1] = DemoLot({lotId: 3, maxSupply: 80, unitPrice: 8e6, purchaseQuantity: 2, product: "Cafe"});
        lots[2] = DemoLot({lotId: 4, maxSupply: 200, unitPrice: 3e6, purchaseQuantity: 10, product: "Trigo"});
        lots[3] = DemoLot({lotId: 5, maxSupply: 40, unitPrice: 12e6, purchaseQuantity: 1, product: "Aceite"});
        lots[4] = DemoLot({lotId: 6, maxSupply: 120, unitPrice: 4e6, purchaseQuantity: 5, product: "Yerba"});
    }
}
