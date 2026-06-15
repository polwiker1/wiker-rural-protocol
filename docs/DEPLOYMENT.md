# Despliegue Testnet

La primera red objetivo es Arbitrum Sepolia (`chainId 421614`). El despliegue de
prueba utiliza `MockUSDC` y crea un productor y lote demostrativos.

## Preparacion

```bash
cp .env.example .env
```

Configurar una wallet utilizada exclusivamente en testnet:

```text
RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
PRIVATE_KEY=<private-key-testnet>
GOVERNANCE_PRIVATE_KEY=<opcional-para-scripts-demo>
VERIFIER_PRIVATE_KEY=<opcional-para-scripts-demo>
BUYER_PRIVATE_KEY=<opcional-para-scripts-demo>
GOVERNANCE_ADDRESS=<multisig-de-gobierno-o-wallet-testnet>
RESOLVER_ADDRESS=<multisig-de-resoluciones-o-wallet-testnet>
VERIFIER_ADDRESS=<wallet-operativa-limitada>
TREASURY_ADDRESS=<opcional>
DEMO_PRODUCER_ADDRESS=<opcional>
DEMO_BUYER_ADDRESS=<opcional>
```

La wallet deployer necesita ETH de Arbitrum Sepolia para pagar gas.

## Simulacion

La simulacion no transmite transacciones:

```bash
set -a
source .env
set +a
forge script script/DeployRuralProtocolTestnet.s.sol:DeployRuralProtocolTestnet \
  --rpc-url "$RPC_URL"
```

## Broadcast

Transmitir solo despues de revisar la simulacion:

```bash
set -a
source .env
set +a
forge script script/DeployRuralProtocolTestnet.s.sol:DeployRuralProtocolTestnet \
  --rpc-url "$RPC_URL" \
  --broadcast
```

## Resultado

El script despliega y conecta:

- `ProducerRegistry`
- `RuralProducts1155`
- `MockUSDC`
- `RuralEscrow`

Ademas:

- autoriza el escrow en registro y ERC-1155;
- transfiere gobierno de registro y ERC-1155 a `GOVERNANCE_ADDRESS`;
- configura gobierno, resolutor y verificador separados en el escrow;
- registra el productor demostrativo;
- crea un lote de `100` unidades a `10 MockUSDC`;
- entrega `1,000 MockUSDC` al comprador demostrativo.

`MockUSDC` es exclusivo de testnet y nunca debe utilizarse en mainnet.

## Demostracion con cinco productores

Sobre un despliegue existente, configurar:

```text
PRODUCER_REGISTRY_ADDRESS=
RURAL_PRODUCTS_ADDRESS=
RURAL_ESCROW_ADDRESS=
MOCK_USDC_ADDRESS=
```

Simular:

```bash
set -a
source .env
set +a
forge script script/RunFiveProducerDemo.s.sol:RunFiveProducerDemo \
  --rpc-url "$RPC_URL"
```

Transmitir:

```bash
set -a
source .env
set +a
forge script script/RunFiveProducerDemo.s.sol:RunFiveProducerDemo \
  --rpc-url "$RPC_URL" \
  --broadcast
```

El script usa cinco wallets de productor deterministicas y publicas exclusivas
de testnet. La wallet administrativa actua como comprador demostrativo comun.
Estas wallets nunca deben recibir fondos reales.
