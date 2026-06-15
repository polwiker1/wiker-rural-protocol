# Revision previa al redeploy

## Decisiones confirmadas

- Solo `NO_SHIPMENT`, no enviar dentro del plazo de 7 dias, registra falta del
  productor.
- Calidad, producto equivocado, danos, demoras y devoluciones del correo pueden
  resolverse economicamente, pero nunca registran falta automatica.
- Cumplir 21 dias desde `ProductSent` genera revision administrativa, sin
  movimiento automatico de fondos.
- El productor carga manualmente los datos de envio desde su panel.
- Wiker verifica el envio y el verificador operativo confirma el hash on-chain.
- El comprador tiene acciones para comprar, confirmar recepcion y reclamar.
- Los permisos administrativos se asignan al multisig antes del despliegue
  final.

## Diferencias con el contrato actual

### Penalizaciones de disputas

El contrato local ya fue corregido. La unica ruta que ejecuta
`reportShipmentFailure` es:

```text
refundForNoShipment(...)
```

Las resoluciones de disputa solamente indican si el stock fisico fue recuperado.

### Ventana logistica

Implementado mediante `LOGISTICS_REVIEW_PERIOD = 21 days` y
`requiresLogisticsReview(orderId)`. La lectura no mueve fondos ni cambia estado.

### Datos de envio

El contrato actual guarda correctamente solo `shippingEvidenceHash`. Los campos
humanos deben almacenarse en Inery y mostrarse en los paneles. No deben agregarse
codigos de seguimiento ni datos personales directamente al contrato.

### Devoluciones

El contrato local incluye arbitraje de devoluciones mediante `ReturnApproved` y
`ReturnShipped`, con 7 dias para despachar y arbitraje especifico una vez
despachada. Debe definirse en el acuerdo de cada operacion:

- quien paga el envio de devolucion segun la causa;
- evidencia requerida para confirmar recepcion;
- criterio humano para restaurar o retirar el stock.

### Multisig

Los contratos aceptan cualquier direccion como `admin`, incluyendo un multisig.
No es necesario implementar un multisig propio.

Para el despliegue final:

- `ProducerRegistry.initialAdmin` = multisig;
- `RuralProducts1155.initialAdmin` = multisig;
- `RuralEscrow.initialGovernance` = multisig de gobierno;
- `RuralEscrow.initialResolver` = multisig de resoluciones;
- `RuralEscrow.initialVerifier` = wallet operativa limitada;
- `RuralEscrow.initialTreasury` = wallet o multisig de tesoreria definido;
- verificar umbral, firmantes y recuperacion antes del broadcast.

## Separacion de permisos implementada

| Rol | Permisos |
| --- | --- |
| Multisig de gobierno | Administradores, tesoreria, productores, lotes, pausa y configuracion |
| Multisig de resoluciones | Reembolsos, divisiones, disputas y escalamiento legal |
| Verificador operativo | Confirmar envio y entrega, sin mover fondos ni cambiar configuracion |

El escrow implementa direcciones separadas para `governance`, `resolver` y
`verifier`. Gobierno puede rotar los roles operativos.

## Riesgos operativos restantes

- Confirmar todos los envios mediante el multisig de gobierno introduce demoras.
- El panel debe alertar con anticipacion y mostrar envios pendientes de
  verificacion.
- Los codigos de seguimiento y datos personales deben cifrarse o protegerse por
  permisos en Inery. No deben ser registros publicos.
- Una demora interna de Wiker no debe convertir un envio real cargado a tiempo
  en una falta del productor.
- El modelo local ya separa stock reservado, vendido y retirado. Un reembolso
  libera la reserva cuando el producto fue recuperado o nunca fue enviado.

## Estado de bloqueantes tecnicos

- Alerta logistica de 21 dias: implementada.
- Roles separados: implementados y probados.
- Plazo de devolucion: implementado en 7 dias.
- Arbitraje especifico de devolucion despachada: implementado.
- Script configurable por gobierno, resolutor, verificador y tesoreria:
  implementado.

Antes del broadcast deben definirse y verificar las direcciones reales de
testnet para cada rol.
