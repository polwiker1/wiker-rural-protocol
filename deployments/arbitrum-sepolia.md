# Arbitrum Sepolia

## Redeploy con roles separados - 2026-06-15

Esta es la version vigente del protocolo en Arbitrum Sepolia.

Roles:

```text
Governance: 0x275fF48842eaf6dFE32B6Cc51713f6CF63841E8D
Resolver:   0xF3aAD2304F711ad5f400Ad322442D67DeD3E8A25
Verifier:   0x521125be95c5679539aB07582F55F0040975A047
Treasury:   0xA7Da01B2c47A74831Df054eC54C1d95691Ef82F7
```

Contratos:

```text
ProducerRegistry:  0x97B3bf50101Ab98A0A0693383501DdDE4BFbEd2C
RuralProducts1155: 0x553046E9FB59Cc5f62B9d666090Cd993B3ff3c5D
RuralEscrow:       0xeAD9BF80C7f68aa82912F7C6c966a1F113756B5B
MockUSDC:          0x23fc9E39073A5Ab0Edd30622943372A6a01a8f8D
```

Plazos verificados on-chain:

```text
Plazo para envio inicial: 7 dias
Alerta de revision logistica: 21 dias desde sentAt
Plazo para despachar devolucion aprobada: 7 dias
```

Estado inicial:

```text
Lote demo: 1
Stock disponible: 100
Saldo comprador demo: 1,000 MockUSDC
```

Transacciones principales:

```text
Deploy ProducerRegistry:
0x7cc36cd02cd2c10aec0eb3ce9ab08e3babbfbf099137c5d36b1684dfb06cac64

Deploy RuralProducts1155:
0x52fcef6ccbf114fd497d1ded061bf76d121eb40ef30869fa6a74133e72617e5a

Deploy MockUSDC:
0x87c8ad898dea2028df0a9c6ae7208a8c0c2c9ded8157a758c5d3d7d1507db7cd

Deploy RuralEscrow:
0x62ebd5c62d5353d5a83d837214371334a8c5bcf38eae4fb3370d6e22e31ef0af
```

## Despliegue demostrativo - 2026-06-15

Red:

```text
Arbitrum Sepolia
chainId: 421614
```

Wallet administrativa, tesoreria, productor demo y comprador demo:

```text
0x521125be95c5679539aB07582F55F0040975A047
```

Contratos:

```text
ProducerRegistry:  0xD41a79dB44ddE74F34296473CA451AEd96CBBa2A
RuralProducts1155: 0x91eB43d44E685F3B57229CcFb6eE4dc821550884
RuralEscrow:       0x3F453F9c0Eae59269e9ED68Ffea1b26683b451F8
MockUSDC:          0xCCD4F95c64A0D9853Be28dAabf0590BAa86c2044
```

## Prueba on-chain

Se ejecuto una compra completa:

```text
Lote: 1
Cantidad: 2
Precio unitario: 10 MockUSDC
Total: 20 MockUSDC
Orden: 1
Estado final: Completed
```

Resultado verificado:

```text
Balance ERC-1155 comprador: 0
Supply disponible lote: 98
Balance MockUSDC escrow: 0
Balance MockUSDC wallet demo: 1,000 MockUSDC
```

Transacciones del flujo:

```text
Approve MockUSDC:
0x277bb30b86e7a93e9f9f2938fd74215a172f72e698c443124643c0ec10203cf6

Compra:
0x422d225f26685128e38f8e9963ce745aa9f19f362cd3189b998d38ca00bd5210

Confirmacion de envio:
0x5097e221e8c4d940866536c904afecfa350a61899f8e9c60f8b8d75fcbab5b34

Confirmacion de recepcion:
0xe16c1b6e8ae926770220e80fbfac3422635417d070ac6125071031336d906631
```

Este despliegue utiliza `MockUSDC` y roles concentrados en una unica wallet. Es
exclusivamente demostrativo y no debe reutilizarse en mainnet.

## Demostracion con cinco productores

Se registraron cinco productores independientes, se crearon cinco lotes y cada
productor completo una venta:

| Lote | Producto | Productor | Stock inicial | Vendido | Stock restante | Pago productor |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 2 | Miel | `0x3087d6D8bC039cB7b10f6612DF504652CC9f4dCE` | 50 | 3 | 47 | 14.85 MockUSDC |
| 3 | Cafe | `0x6a921730c6FfDc466b742D6d37458C4E258d8177` | 80 | 2 | 78 | 15.84 MockUSDC |
| 4 | Trigo | `0x43fA2bA9ACf9cBf3Ed2616d0492a48453992749A` | 200 | 10 | 190 | 29.70 MockUSDC |
| 5 | Aceite | `0xafd20c8e13cb27288F67d2422190f794391272dc` | 40 | 1 | 39 | 11.88 MockUSDC |
| 6 | Yerba | `0x2aAd8e7492DD8849C448B3C683a2410C8bFd2165` | 120 | 5 | 115 | 19.80 MockUSDC |

Lectura contable del stock:

```text
Stock inicial = Lot.maxSupply
Stock consumido = Lot.allocatedSupply
Stock restante = Lot.maxSupply - Lot.allocatedSupply
```

`maxSupply` queda registrado on-chain al crear el lote y no se modifica. El
panel puede obtener ambos valores mediante `getLot(tokenId)` y tambien consultar
el restante directamente mediante `availableSupply(tokenId)`.

Resultado verificado on-chain:

```text
Ordenes: 2, 3, 4, 5 y 6
Estado final de todas las ordenes: Completed
Balance ERC-1155 comprador para cada lote: 0
Balance MockUSDC escrow: 0
Tarifa total recibida por tesoreria: 0.93 MockUSDC
```

Transacciones principales:

| Orden | Compra | Envio | Recepcion |
| --- | --- | --- | --- |
| 2 | `0xea629eeea4a2f689c18d4e0cf3e5e577f89a6a97a587effae48caa17792dd2ea` | `0x4467c3003132cf4ba2e11168f33c8e6ac51a94ac37fa7d7a3224cf2cca7c73af` | `0xce70b3ed41deaac14677a4f5b9c40431fb72178bb6ee5a7e3e4bc6bed0051db4` |
| 3 | `0x87c47c8a639307830d437caf3dc5cd7710a1b543a8f37a91f892aa84298ca04c` | `0xd6406d9e38b5184a0dc3acdf8f34de2e2d58a934e79a1477bc967178c6659b07` | `0x55883c93c8aeae2b6180835d3242fcba99ded2fc392d7c77f16415aab9c6f25c` |
| 4 | `0xc89079ef1e02859c2e488ead0a8d54004ed5e5f84873f4e107c737b15a9cc8c3` | `0xeaf474fef4aee6823feea6afa01c954bb36e2e21d73a13980d4495b36ed863b2` | `0x1786fd4b42bb96d9c7048cfe53ffdbc5cefd0eea3fc8494a371724ece85e08ec` |
| 5 | `0x721dec5d8cf7bb747068851842532e86b204ca28b527112788b47bdab7c4951f` | `0xdfd234a777a8636247bb84dd396cf18e968b14411b0403dbc1d08f78fa159a35` | `0xbd61370170964d02e6b03b74a0c7add4d011e74b90959020bed4ba2c5207da17` |
| 6 | `0xab47d7413c2668d74611145ec18afdfcce313a3bc44c7abc37156a829c763b2e` | `0x9dd5d93f8853730837a641edcdf8113b4bd0987ae92db75028f7833d804ee432` | `0x6231dab191019426dce3b0ae39d477b468c26d8fae73888277c987d6d37fb181` |
