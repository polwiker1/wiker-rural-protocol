# Estimacion de gas operativo

Estas estimaciones salen de `forge test --gas-report` y sirven para dimensionar
el costo operativo del escrow. No son una cotizacion exacta de Arbitrum One.

En Arbitrum el costo final depende de:

- gas usado por la funcion;
- gas price L2 al momento de ejecutar;
- componente de publicacion de datos en L1;
- precio de ETH;
- posible overhead de multisig o cuenta operativa.

Formula simple:

```text
costo ETH = gas usado * gasPriceGwei / 1_000_000_000
costo USD = costo ETH * precio ETH/USD
```

Ejemplo de referencia, no cotizacion:

```text
gasPrice = 0.05 gwei
ETH/USD = 3,500

100,000 gas ~= 0.000005 ETH ~= 0.0175 USD
```

## Quien paga cada accion

| Accion | Actor esperado | Paga gas |
| --- | --- | --- |
| Compra | Comprador | Comprador |
| Confirmar recepcion | Comprador | Comprador |
| Confirmar envio | Verificador Wiker | Wiker |
| Confirmar entrega | Verificador Wiker | Wiker |
| Reembolso por no envio | Resolutor Wiker | Wiker |
| Abrir disputa desde reclamo off-chain | Resolutor Wiker | Wiker |
| Resolver disputa | Resolutor Wiker | Wiker |
| Aprobar devolucion | Resolutor Wiker | Wiker |
| Confirmar envio de devolucion | Verificador Wiker | Wiker |
| Confirmar recepcion de devolucion y reembolsar | Resolutor Wiker | Wiker |
| Pausar compras | Gobierno Wiker | Wiker |
| Rotar roles | Gobierno Wiker | Wiker |

## Gas observado en funciones del escrow

| Funcion | Gas tipico aproximado | Actor |
| --- | ---: | --- |
| `purchase` | 306,000 | comprador |
| `confirmReceipt` | 92,000 | comprador |
| `confirmShipment` | 59,000 | Wiker/verificador |
| `confirmDelivery` | 36,000 | Wiker/verificador |
| `refundForNoShipment` | 122,000 | Wiker/resolutor |
| `openDispute` | 54,000 | comprador o Wiker/resolutor |
| `approveReturn` | 59,000 | Wiker/resolutor |
| `confirmReturnShipment` | 56,000 | Wiker/verificador |
| `confirmReturnReceivedAndRefund` | 97,000 | Wiker/resolutor |
| `resolveDisputeForBuyer` | 111,000 | Wiker/resolutor |
| `resolveDisputeForProducer` | 173,000 | Wiker/resolutor |
| `resolveDisputeSplit` | 184,000 | Wiker/resolutor |
| `resolveExpiredReturnForProducer` | 158,000 | Wiker/resolutor |
| `resolveReturnShippingDispute` | 170,000 | Wiker/resolutor |
| `setPurchasesPaused` | 47,000 | Wiker/gobierno |
| `setResolver` / `setVerifier` | 31,000 | Wiker/gobierno |
| `setTreasury` | 24,000 | Wiker/gobierno |

## Ejemplos de costo operativo Wiker

Usando el ejemplo de `0.05 gwei` y `3,500 USD/ETH`:

| Accion Wiker | Gas aprox. | Costo aprox. |
| --- | ---: | ---: |
| Confirmar envio | 59,000 | 0.010 USD |
| Reembolso por no envio | 122,000 | 0.021 USD |
| Resolver disputa para comprador | 111,000 | 0.019 USD |
| Resolver disputa dividida | 184,000 | 0.032 USD |
| Confirmar devolucion y reembolsar | 97,000 | 0.017 USD |
| Pausar compras | 47,000 | 0.008 USD |

Con `0.10 gwei`, esos valores se duplican. Con `1.00 gwei`, son veinte veces
mayores que la tabla de `0.05 gwei`.

## Lectura operativa

El gasto de gas de Wiker por operacion normal es bajo si Wiker solo confirma
envios y resuelve excepciones. El mayor volumen de gas queda del lado del
comprador porque la compra ejecuta transferencia USDC, crea orden y emite
ERC-1155.

Para produccion, la tesoreria deberia presupuestar gas para:

- confirmaciones de envio;
- reembolsos por falta de envio;
- disputas;
- devoluciones;
- pausas o rotacion de roles.

Si Wiker decide patrocinar tambien compras o acciones del comprador, el costo
operativo sube de forma importante porque `purchase` es la funcion mas usada y
una de las mas costosas.
