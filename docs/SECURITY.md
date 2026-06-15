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

## Pausa de emergencia futura

Una pausa global debe detener nuevas compras, pero permitir:

- reembolsos vencidos;
- apertura de disputas;
- resoluciones administrativas;
- recuperacion controlada de fondos.
