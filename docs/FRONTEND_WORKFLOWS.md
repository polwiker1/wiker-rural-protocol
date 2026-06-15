# Flujos requeridos del frontend

## Principio

El frontend muestra informacion humana y prepara acciones. Los contratos
controlan pagos, permisos y estados. Inery conserva los registros operativos y
los contratos guardan hashes para verificar su integridad.

Los datos de envio no se publican completos on-chain. Se guarda el documento de
envio en Inery y solamente su hash se registra en `RuralEscrow`.

## Panel comprador

### Boton `Comprar`

Visible cuando:

- el lote esta activo;
- existe stock disponible;
- el productor esta activo;
- las compras no estan pausadas.

Muestra antes de firmar:

- producto y unidad fisica;
- cantidad;
- precio unitario;
- total USDC;
- wallet productora;
- tarifa de Wiker;
- regla de envio fuera del escrow;
- clausula de revision logistica;
- acuerdo de la operacion.

Acciones:

```text
Approve USDC, si hace falta
  -> purchase(lotId, quantity, maxAmount, agreementHash)
```

### Boton `Confirmar recepcion`

Visible para la wallet compradora cuando la orden esta en `ProductSent` o
`Delivered`.

Accion:

```text
confirmReceipt(orderId)
```

Libera el pago y quema los ERC-1155 de la orden.

### Boton `Reclamar`

Siempre abre un caso humano con categoria, descripcion y evidencia.

- En estado `Paid`, el reclamo se registra en Inery y notifica a Wiker. No abre
  una disputa on-chain inmediata ni mueve fondos.
- En `ProductSent` o `Delivered`, el comprador puede abrir una disputa on-chain
  mediante `openDispute(orderId, disputeEvidenceHash)`.
- En una orden terminal el boton solo permite soporte posterior; no altera la
  resolucion on-chain.

Si el comprador ya recibio el producto y desea devolverlo, debe usar `Reclamar`
antes de confirmar recepcion. Luego visualiza:

- devolucion pendiente de aprobacion;
- devolucion aprobada;
- formulario para informar envio de regreso;
- devolucion en transito;
- recepcion verificada y reembolso.

El comprador visualiza:

- estado de la orden;
- fechas de compra y envio confirmado;
- empresa de correo;
- codigo de seguimiento;
- historial humano del envio;
- fecha de revision logistica;
- estado del reclamo o disputa.

El codigo de seguimiento y los datos logisticos solo son visibles para comprador,
productor y Wiker. No deben exponerse en vistas publicas.

## Panel productor

Cada productor ingresa con la wallet registrada. Solo puede ver y cargar envios
de ordenes donde `order.producer` coincide con su wallet.

### Formulario `Informar envio`

Campos obligatorios:

- `orderId`;
- empresa de correo;
- codigo de seguimiento;
- fecha y hora de despacho;
- primer estado informado por el correo;
- comprobante o evidencia;
- observaciones opcionales.

Validaciones:

- orden en estado `Paid`;
- productor de la orden igual a wallet conectada;
- dentro de los 7 dias desde la compra;
- codigo no reutilizado para otra orden;
- campos obligatorios completos.

El formulario no cambia directamente el estado on-chain. Genera un documento de
envio, lo guarda en Inery y calcula su hash:

```text
Vendedor carga envio
  -> Inery guarda shipment record pendiente
  -> Wiker recibe alerta
  -> Wiker verifica aceptacion real del correo
  -> verificador operativo confirma shippingEvidenceHash on-chain
  -> orden cambia a ProductSent
```

El registro de Inery debe estar cifrado o protegido por permisos. El
`shippingEvidenceHash` on-chain permite verificarlo sin publicar su contenido.

El productor visualiza:

- ventas y ordenes pendientes de despacho;
- limite exacto para informar envio;
- envios pendientes de verificacion Wiker;
- envios confirmados;
- reclamos y disputas;
- pagos pendientes y liberados;
- historial de faltas objetivas por no envio en tiempo.

## Panel administrativo

El panel administrativo prepara operaciones para el multisig. No debe depender
de una clave privada individual.

Colas principales:

- productores y lotes pendientes de aprobacion;
- envios pendientes de verificacion;
- ordenes `Paid` vencidas sin envio;
- ordenes `ProductSent` con 21 dias desde `sentAt`;
- reclamos y disputas;
- devoluciones aprobadas pendientes de envio;
- devoluciones enviadas pendientes de recepcion;
- resoluciones pendientes de firma multisig.

Al verificar un envio, Wiker debe comparar el registro humano con evidencia de
aceptacion real del correo. Luego prepara:

```text
confirmShipment(orderId, shippingEvidenceHash)
```

## Estados visibles

| Estado on-chain | Texto humano |
| --- | --- |
| `Paid` | Pagado, esperando envio |
| `ProductSent` | Envio verificado por Wiker |
| `Delivered` | Entrega verificada, periodo de revision |
| `Disputed` | Orden en disputa |
| `Escalated` | En revision legal |
| `ReturnApproved` | Devolucion autorizada, pendiente de envio |
| `ReturnShipped` | Devolucion enviada, pendiente de recepcion |
| `Completed` | Operacion completada |
| `Refunded` | Comprador reembolsado |
| `PartiallyResolved` | Fondos distribuidos por acuerdo |

## Ventana logistica

Al cumplirse `21 dias` desde `sentAt`, el frontend y el indexador deben marcar la
orden para revision. Esta alerta:

- no devuelve fondos;
- no libera fondos;
- no sanciona al productor;
- no cambia automaticamente el estado on-chain.
