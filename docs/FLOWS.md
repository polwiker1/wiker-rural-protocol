# Flujos MVP

## Alta de productor

```text
Productor completa registro off-chain
  -> Wiker revisa
  -> administrador registra wallet on-chain
  -> productor activo
```

## Alta de lote

```text
Productor carga producto en el panel
  -> Wiker revisa documentos y cantidad
  -> administrador aprueba lote on-chain
  -> ERC-1155 registra tokenId y supply maximo
  -> marketplace publica lote
```

El productor no envia una transaccion para solicitar el lote y no recibe el
supply en su wallet.

## Compra y finalizacion normal

```text
Comprador paga USDC
  -> escrow crea orden
  -> ERC-1155 emite unidades al comprador
  -> productor recibe aviso
  -> productor informa envio en su panel
  -> Wiker verifica y confirma ProductSent on-chain
  -> comprador confirma recepcion
  -> escrow quema tokens
  -> 99% productor + 1% tesoreria Wiker
```

## Falta de envio

```text
Orden pagada
  -> pasan 7 dias sin envio confirmado
  -> orden aparece vencida en el panel administrativo
  -> Wiker revisa comunicaciones y situacion del productor
  -> administrador ejecuta reembolso
  -> estado cambia antes de transferir fondos
  -> tokens se queman
  -> stock reservado vuelve a estar disponible
  -> 100% USDC vuelve al comprador
  -> Wiker paga el gas de la transaccion
  -> primer incumplimiento: advertencia + tarifa futura de 5%
  -> segundo incumplimiento suspende al productor
```

El vencimiento no mueve fondos automaticamente porque una blockchain no ejecuta
acciones por si sola. Habilita a la administracion para revisar y ejecutar el
reembolso. Los fondos siempre vuelven completos a la wallet del comprador y la
wallet administrativa paga el gas por separado.

Como el producto nunca fue enviado, el stock reservado vuelve a estar
disponible. La falta del productor se registra por separado.

Desde el vencimiento exacto del plazo ya no se permite confirmar el envio. Esto
impide evitar el reembolso registrando un envio tardio.

## Disputa

```text
Orden enviada o entrega reportada
  -> comprador o administrador abre disputa
  -> solo esa orden queda congelada
  -> Wiker revisa evidencia privada
  -> resolucion on-chain:
       liberar al productor
       reembolsar comprador
       dividir fondos
       escalar a legal
```

Las disputas no registran faltas automaticas del productor. Solo el reembolso
por no enviar dentro del plazo registra incumplimiento.

La resolucion economica tambien declara si el producto fue recuperado:

- recuperado: el stock reservado vuelve a estar disponible;
- no recuperado: pasa a stock retirado y no puede venderse nuevamente.

## Devolucion fisica

Si el comprador recibio el producto pero quiere devolverlo, debe reclamar antes
de confirmar recepcion o antes de que Wiker finalice la orden:

```text
Comprador abre disputa
  -> Wiker revisa y aprueba devolucion
  -> estado ReturnApproved
  -> comprador despacha el producto de regreso
  -> Wiker verifica el envio de devolucion
  -> estado ReturnShipped
  -> productor recibe el producto
  -> Wiker verifica recepcion y estado fisico
  -> reembolso al comprador
  -> producto vendible: stock restaurado
  -> producto no vendible: stock retirado
```

Hasta verificar la recepcion de la devolucion:

- los USDC permanecen en escrow;
- los ERC-1155 permanecen en la wallet compradora;
- el stock permanece reservado.

Si el comprador nunca envia la devolucion, Wiker puede resolver la orden a favor
del productor despues de 7 dias. Si ya despacho la devolucion, solo puede
cerrarse mediante recepcion verificada o arbitraje especifico del transporte de
regreso. El costo de la devolucion se acuerda y registra fuera del contrato
segun la causa del reclamo.

Una vez que la orden esta `Completed`, los fondos ya fueron liberados y el
contrato no puede obligar al productor a devolverlos. Cualquier devolucion
posterior requiere un nuevo acuerdo externo.

## Estados de orden

```text
Paid
  -> ProductSent
       -> Completed
       -> Delivered
            -> Completed
            -> Disputed
  -> Refunded

Disputed
  -> ReturnApproved
       -> ReturnShipped
            -> Refunded
       -> Completed
  -> Completed
  -> Refunded
  -> PartiallyResolved
  -> Escalated
```

- `Paid`: USDC retenido y tokens emitidos al comprador.
- `ProductSent`: Wiker verifico el aviso de envio.
- `Delivered`: Wiker verifico evidencia de entrega; fondos permanecen en escrow
  hasta confirmacion o resolucion.
- `Disputed`: orden congelada por reclamo del comprador.
- `Escalated`: disputa derivada a instancia legal.
- `ReturnApproved`: Wiker autorizo la devolucion; fondos y stock siguen
  reservados.
- `ReturnShipped`: Wiker verifico el despacho de regreso; aun no existe
  reembolso.
- `Completed`: pago distribuido y tokens quemados.
- `Refunded`: comprador reembolsado y tokens quemados.
- `PartiallyResolved`: fondos divididos por resolucion administrativa.
