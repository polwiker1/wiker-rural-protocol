# Seguridad

## Principios

- Actualizar estado antes de transferir fondos.
- Usar `SafeERC20` para todos los movimientos USDC.
- Proteger liberaciones y reembolsos con `ReentrancyGuard`.
- Validar estado, actor, plazo e importe en cada transicion.
- Una orden completada o reembolsada no puede ejecutarse nuevamente.
- Una orden reembolsada solo restaura stock cuando el producto fue recuperado o
  nunca fue enviado.
- Una disputa bloquea solo su orden.
- Los tokens ERC-1155 no pueden transferirse entre usuarios.
- No publicar informacion personal ni codigos de seguimiento on-chain.

## Permisos

- El gobierno multisig administra productores, lotes, tesoreria y configuracion.
- El resolutor multisig mueve fondos mediante reembolsos y resoluciones.
- El verificador operativo confirma envios y entregas, pero no mueve fondos.
- Las wallets privilegiadas deben estar vinculadas a un acuerdo legal off-chain
  y a evidencia on-chain del hash/version del acuerdo aceptado.
- Ninguna wallet privilegiada deberia operar en produccion sin aceptacion de rol,
  procedimiento de revocacion y responsable legal identificado.
- Solo el escrow autorizado reporta incumplimientos al registro.
- Solo el escrow autorizado emite y quema tokens vinculados a ordenes.
- Solo el resolutor ejecuta reembolsos y disputas.
- Solo el verificador confirma envios y entregas.

## Riesgos a probar

- Doble reembolso.
- Doble liberacion.
- Reentrancy durante reembolso o pago.
- Compra superior al supply.
- Emision no autorizada.
- Transferencia prohibida entre usuarios.
- Confirmacion de recepcion por una wallet ajena.
- Finalizacion de una orden disputada.
- Suspension incorrecta de productores.
- Confirmacion de envio despues del plazo.
- Disputa iniciada por una wallet no autorizada.
- Resolucion con atribucion incorrecta de culpa al productor.
- Fondos detenidos indefinidamente en estado `ProductSent`.
- Clasificacion incorrecta de stock recuperado durante una disputa.
- Reembolso de devolucion antes de verificar recepcion fisica.
- Restauracion de stock para un producto devuelto que ya no puede venderse.
- Comprador autorizado a devolver que nunca despacha el producto.
- Verificador operativo intentando mover fondos.
- Resolutor intentando cambiar configuracion.
- Resolucion general aplicada a una devolucion ya despachada.
- USDC no estandar o con comportamiento inesperado.

## Coverage defensivo

Se agrego `test/RuralEscrowNegativeBranches.t.sol` para cubrir ramas defensivas
del escrow que no aparecen en flujos felices: hashes cero, direcciones cero,
montos invalidos, estados incorrectos, deadlines activos/vencidos y resoluciones
de devolucion por pago total al productor, reembolso total al comprador o split.

Resultado de referencia:

```text
RuralEscrow.sol
Lines:      97.13%
Statements: 96.93%
Branches:   95.12%
Functions:  100.00%
```

## Fuzzing inicial

La suite incluye una primera capa de fuzzing en `test/RuralProtocolFuzz.t.sol`.
Estas pruebas no reemplazan una auditoria ni invariant testing completo, pero
permiten presionar el protocolo con cantidades variables para detectar bordes
no cubiertos por casos manuales.

Propiedades probadas actualmente:

- una compra con cantidad valida mantiene consistentes escrow, balance del
  comprador, tokens ERC-1155 y stock reservado;
- un reembolso por falta de envio restaura fondos del comprador, quema tokens y
  libera stock reservado;
- la pausa de compras bloquea nuevas compras, pero no bloquea reembolsos de
  ordenes ya existentes;
- una disputa dividida nunca paga mas de lo depositado y deja el escrow en cero.

## Pruebas de carga locales

La suite incluye `test/RuralProtocolLoad.t.sol` para simular muchas wallets
comprando el mismo lote dentro del entorno local de Foundry.

Estas pruebas no representan ejecucion paralela real. En EVM las transacciones
siempre se ordenan secuencialmente dentro del bloque. El objetivo es validar que
una rafaga de compras desde muchas wallets no rompa:

- la contabilidad de ordenes;
- el saldo USDC retenido en escrow;
- el stock reservado;
- los balances ERC-1155 por comprador;
- el limite de supply del lote.

Tambien se prueba que, una vez agotado el supply, una compra adicional revierte
sin cobrar USDC ni emitir tokens.

## Pausa de emergencia futura

Una pausa global debe detener nuevas compras, pero permitir:

- reembolsos vencidos;
- apertura de disputas;
- resoluciones administrativas;
- recuperacion controlada de fondos.
