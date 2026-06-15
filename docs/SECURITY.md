# Seguridad

## Principios

- Actualizar estado antes de transferir fondos.
- Usar `SafeERC20` para todos los movimientos USDC.
- Proteger liberaciones y reembolsos con `ReentrancyGuard`.
- Validar estado, actor, plazo e importe en cada transicion.
- Una orden completada o reembolsada no puede ejecutarse nuevamente.
- Una orden reembolsada no restaura stock automaticamente.
- Una disputa bloquea solo su orden.
- Los tokens ERC-1155 no pueden transferirse entre usuarios.
- No publicar informacion personal ni codigos de seguimiento on-chain.

## Permisos MVP

- Una wallet administrativa registra productores y lotes.
- Solo el escrow autorizado reporta incumplimientos al registro.
- Solo el escrow autorizado emite y quema tokens vinculados a ordenes.
- Solo administracion confirma envios, ejecuta reembolsos por falta de envio y
  resuelve disputas.

Antes de mainnet, los permisos administrativos deben migrarse a multisig y
procedimientos documentados.

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
- USDC no estandar o con comportamiento inesperado.

## Pausa de emergencia futura

Una pausa global debe detener nuevas compras, pero permitir:

- reembolsos vencidos;
- apertura de disputas;
- resoluciones administrativas;
- recuperacion controlada de fondos.
