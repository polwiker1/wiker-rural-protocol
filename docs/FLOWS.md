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
  -> stock no se restaura
  -> 100% USDC vuelve al comprador
  -> Wiker paga el gas de la transaccion
  -> primer incumplimiento: advertencia + tarifa futura de 5%
  -> segundo incumplimiento suspende al productor
```

El vencimiento no mueve fondos automaticamente porque una blockchain no ejecuta
acciones por si sola. Habilita a la administracion para revisar y ejecutar el
reembolso. Los fondos siempre vuelven completos a la wallet del comprador y la
wallet administrativa paga el gas por separado.

El stock asociado a una operacion fallida queda consumido. Para volver a
publicarlo, el productor necesita una nueva aprobacion administrativa.

## Disputa

```text
Orden enviada o entrega reportada
  -> comprador abre disputa
  -> solo esa orden queda congelada
  -> Wiker revisa evidencia privada
  -> resolucion on-chain:
       liberar al productor
       reembolsar comprador
       dividir fondos
       escalar a legal
```

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
  -> Completed
  -> Refunded
  -> PartiallyResolved
  -> Escalated
```

- `Paid`: USDC retenido y tokens emitidos al comprador.
- `ProductSent`: Wiker verifico el aviso de envio.
- `Delivered`: Wiker verifico evidencia de entrega; comienza revision de 7 dias.
- `Disputed`: orden congelada por reclamo del comprador.
- `Escalated`: disputa derivada a instancia legal.
- `Completed`: pago distribuido y tokens quemados.
- `Refunded`: comprador reembolsado y tokens quemados.
- `PartiallyResolved`: fondos divididos por resolucion administrativa.
