# Bitacora - Wiker Rural Protocol

## 2026-06-14 - Modelo funcional MVP confirmado

### Separacion del proyecto

- Este protocolo vive en un repositorio independiente.
- No se incorpora a la preventa WKR.
- El marketplace existente se integrara cuando las interfaces de contratos sean
  estables.
- Primera red objetivo: Arbitrum Sepolia con MockUSDC.
- Red de produccion futura: Arbitrum One con USDC oficial.

### Representacion del producto

- Cada `tokenId` ERC-1155 representa unidades de un lote rural aprobado.
- Una unidad representa el derecho contractual a recibir una unidad definida
  del producto de ese lote.
- El supply no se emite a la wallet del productor ni a una wallet Wiker.
- El contrato registra el supply maximo y emite unidades directamente al
  comprador al realizarse una compra.
- Los tokens no pueden revenderse.
- Los tokens se queman al completar o reembolsar una orden.
- Una venta completada consume permanentemente el supply aprobado aunque sus
  tokens se quemen.
- Un reembolso por incumplimiento quema los tokens y tambien consume
  permanentemente el supply aprobado.
- El stock nunca se restaura automaticamente.

### Productores y administracion

- Wiker registra, aprueba y administra productores.
- El productor utiliza un panel asociado a su wallet y recibe inicialmente
  avisos personales por WhatsApp.
- La wallet administradora confirma manualmente los envios informados por el
  productor.
- Primer incumplimiento por falta de envio: advertencia.
- Despues del primer incumplimiento confirmado, la tarifa aplicable a futuras
  ventas exitosas del productor sube de `1%` a `5%`.
- Segundo incumplimiento por falta de envio: suspension automatica hasta
  revision administrativa.
- La tarifa penalizada no vuelve automaticamente a `1%`; requiere decision
  administrativa.

### Pagos y escrow

- El comprador paga el valor del producto en USDC al escrow.
- El envio se acuerda y paga fuera del contrato entre comprador y productor.
- Si la operacion finaliza correctamente:
  - `99%` se libera al productor.
  - `1%` se envia a la tesoreria Wiker como tarifa por el servicio de software.
- Si la operacion se reembolsa:
  - `100%` vuelve al comprador.
  - Wiker no cobra tarifa.
- El usuario que ejecute una transaccion paga su gas.

### Plazos

- El productor tiene siete dias desde la compra para lograr que Wiker confirme
  el envio.
- Sin envio confirmado al vencer el plazo, la orden queda habilitada para
  revision administrativa por falta de envio.
- Wiker revisa el caso antes de ejecutar el reembolso.
- La wallet administradora ejecuta el reembolso y paga el gas de esa
  transaccion.
- El comprador recibe el `100%` de los USDC depositados. El costo de gas no se
  descuenta del importe reembolsado.
- El reembolso debe ser de una sola ejecucion y estar protegido contra
  reentrancy.
- El plazo posterior a entrega comienza cuando:
  - el comprador confirma recepcion; o
  - Wiker confirma evidencia de entrega.
- Nunca comienza solamente porque el productor informo el envio.

### Disputas

- Una disputa congela solamente su orden, no todo el protocolo.
- El panel administrativo registra numero, categoria, evidencia y estado.
- Los datos privados y evidencias viven off-chain.
- On-chain se guardan hashes y la resolucion.
- La administracion puede:
  - liberar fondos al productor;
  - reembolsar al comprador;
  - dividir fondos;
  - escalar a instancia legal.

### Pausas

- Una pausa global futura solo debe impedir nuevas compras durante emergencias.
- No debe impedir reembolsos ni resoluciones de fondos existentes.
- El bloqueo ordinario se realiza por orden mediante su estado de disputa.

## Decisiones pendientes

- Formato exacto del acuerdo legal por transaccion.
- Politica y duracion de la instancia legal.
- Regla exacta para entregas verificadas por Wiker sin confirmacion del
  comprador.
- Almacenamiento privado para documentos, evidencia y comunicaciones.
- Estrategia de transacciones patrocinadas para productores.

## 2026-06-14 - Primera implementacion

- Se implemento `ProducerRegistry`.
- Solo el escrow autorizado puede registrar incumplimientos de envio.
- El primer incumplimiento conserva al productor activo.
- El segundo incumplimiento suspende automaticamente al productor.
- La rehabilitacion administrativa no borra su historial.
- Se implemento `RuralProducts1155`.
- Los lotes se crean sin emitir supply a productor ni administrador.
- Solo el escrow autorizado puede asignar unidades a compradores.
- Las transferencias entre usuarios estan bloqueadas.
- Una venta completada quema tokens sin restaurar stock.
- La implementacion inicial restauraba stock en un reembolso.
- Decision corregida antes del escrow: un reembolso tambien consume stock
  permanentemente.
- Suite inicial: `15 passed, 0 failed`.

## 2026-06-14 - RuralEscrow MVP

- Se implemento `RuralEscrow` con pagos mediante un ERC-20 configurado como
  USDC.
- El precio unitario se registra on-chain en cada lote.
- El comprador indica lote, cantidad e importe maximo aceptado; el escrow
  calcula el importe real usando el precio on-chain.
- El comprador tambien firma un importe maximo aceptado para protegerse de
  cambios de precio entre la visualizacion y la ejecucion.
- Al comprar, el escrow retiene USDC y emite ERC-1155 al comprador.
- Solo administracion confirma el envio informado por el productor.
- El comprador puede confirmar recepcion y liberar el pago.
- Administracion puede confirmar entrega y finalizar luego de siete dias sin
  disputa.
- Luego de siete dias sin envio, solo administracion puede reembolsar tras
  revisar el caso.
- Los reembolsos por falta de envio registran incumplimiento:
  - primero: tarifa futura de `5%`;
  - segundo: suspension automatica.
- Las disputas pueden resolverse para productor, comprador, mediante division de
  fondos o escalamiento legal.
- La pausa global solo bloquea compras nuevas.
- Compras, pagos y reembolsos usan `ReentrancyGuard` y `SafeERC20`.
- Suite actual: `36 passed, 0 failed`.
