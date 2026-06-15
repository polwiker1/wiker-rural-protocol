# Matriz de fallas y disputas

## Escenarios probados

| Caso | Situacion | Resolucion | Resultado comprador | Resultado productor | Penalizacion |
| --- | --- | --- | --- | --- | --- |
| 1 | Productor no informa envio antes de 7 dias | Reembolso y restauracion de stock | Recibe 100% | Recibe 0 | Si |
| 2 | Envio declarado, comprador no recibe | Disputa para comprador | Recibe 100% | Recibe 0 | No |
| 3 | Comprador disputa, productor demuestra entrega correcta | Disputa para productor | Recibe producto | Recibe pago menos tarifa | No |
| 4 | Producto danado por el correo y ambas partes acuerdan dividir | Resolucion parcial | Recibe monto acordado | Recibe saldo menos tarifa | No |
| 5 | No existe acuerdo y el caso pasa a legal | Escalamiento y resolucion posterior | Segun resolucion | Segun resolucion | Configurable |
| 6 | Comprador recibe y devuelve producto vendible | Reembolso despues de recepcion verificada | Recibe 100% | Recibe producto | No |
| 7 | Comprador recibe autorizacion pero no devuelve | Resolucion para productor | Conserva producto | Recibe pago menos tarifa | No |
| 8 | Producto devuelto no puede revenderse | Reembolso y retiro de stock | Recibe 100% | Recibe producto no vendible | No |

Todos los casos se prueban conjuntamente en
`test/DisputeScenarioMatrix.t.sol`.

## Reglas verificadas

- Desde el vencimiento exacto de los 7 dias ya no puede confirmarse un envio.
- Comprador o administrador pueden abrir una disputa.
- Una wallet ajena no puede abrir una disputa.
- Abrir una disputa congela solamente esa orden.
- Una disputa escalada sigue pudiendo resolverse on-chain.
- Las disputas no registran faltas automaticas del productor.
- La primera culpa confirmada eleva la tarifa futura del productor al `5%`.
- La segunda culpa confirmada suspende al productor.
- Toda resolucion terminal quema los ERC-1155 y deja el escrow de esa orden en
  cero.
- Un reembolso restaura stock solo cuando el producto fue recuperado o nunca
  fue enviado.
- Si el producto no fue recuperado, la resolucion lo mueve a stock retirado.
- Una devolucion autorizada no libera reembolso hasta verificar que el productor
  recibio el producto.
- Si el comprador nunca despacha la devolucion, la orden puede resolverse para
  el productor.

## Matriz contable de ejemplo

Cinco ordenes de `20 USDC` cada una:

```text
Total depositado: 100 USDC
Reembolsos al comprador: 70 USDC
Pagos netos a productores: 29.70 USDC
Tarifa Wiker: 0.30 USDC
Balance final escrow: 0 USDC
```

## Propuesta previa al redeploy

### Dos plazos independientes

No debe usarse un unico plazo total para todas las ordenes:

```text
Compra
  -> hasta 7 dias para confirmar un envio real
  -> desde ProductSent: ventana logistica minima de 21 dias
  -> revision administrativa si no existe entrega confirmada
```

La ventana logistica de `21 dias` comienza en `sentAt`, no en `purchasedAt`.
Esto permite que el correo complete intentos de entrega y eventualmente devuelva
el paquete al emisor.

- La orden puede durar hasta `28 dias` desde la compra antes de revision.
- El comprador puede confirmar recepcion y completar antes.
- El comprador o Wiker pueden abrir una disputa despues del envio.
- Cumplir los `21 dias` no mueve fondos automaticamente.
- Al vencer, la orden entra en revision administrativa.

### Clasificacion objetiva de faltas

Las resoluciones economicas y las sanciones al productor son decisiones
separadas.

No generan automaticamente una falta:

- producto incorrecto;
- calidad discutida;
- producto danado;
- demora o devolucion causada por el correo;
- acuerdo de division de fondos.

Estas situaciones pueden terminar en reembolso o division, pero su evaluacion es
interpretativa y no debe suspender automaticamente al productor.

Una falta automatizable debe depender de evidencia objetiva:

- envio declarado como realizado, pero codigo inexistente, invalido o sin
  aceptacion verificable del correo.

La regla de falta de envio antes del plazo de siete dias requiere confirmacion
final porque anteriormente tambien se definio como incumplimiento sancionable.

### Evidencia minima de envio real

Para marcar `ProductSent`, Wiker debe verificar como minimo:

- empresa de correo;
- codigo de seguimiento;
- primer evento de aceptacion del paquete por el correo;
- fecha y hora;
- hash de la evidencia.

La sola carga de un codigo por el productor no alcanza para confirmar el envio.

## Riesgos y decisiones pendientes

### Orden en `ProductSent` sin actividad

Si nadie actua, una orden puede permanecer en `ProductSent`. La propuesta es
marcarla para revision administrativa al cumplir `21 dias` desde `sentAt`, sin
mover fondos automaticamente.

### Poder administrativo

El verificador confirma envios y entregas, mientras el resolutor abre y resuelve
disputas. Gobierno y resoluciones deben utilizar multisig antes de Arbitrum One,
con procedimientos y registro de evidencia.

### Clasificacion de culpa

El contrato local corregido solo registra falta del productor mediante el
reembolso por no envio dentro de los siete dias.
