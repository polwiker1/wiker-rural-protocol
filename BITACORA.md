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
- El stock reservado se restaura en reembolsos cuando el producto nunca fue
  enviado o fue recuperado.

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
- La implementacion inicial hacia consumir stock permanentemente en reembolsos.
  Esta decision fue reemplazada posteriormente por stock reservado, vendido y
  retirado.
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
- Solo el verificador operativo confirma el envio informado por el productor.
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

## 2026-06-15 - Preparacion de despliegue testnet

- Se agrego `DeployRuralProtocolTestnet.s.sol`.
- El script despliega y conecta el protocolo completo con `MockUSDC`.
- Registra un productor y lote demostrativos.
- Emite saldo MockUSDC a un comprador demostrativo.
- Se agrego prueba integral del flujo de despliegue.
- Se documento simulacion y broadcast en Arbitrum Sepolia.
- Suite actual: `37 passed, 0 failed`.

## 2026-06-15 - Despliegue y prueba en Arbitrum Sepolia

- Se simulo y transmitio el despliegue integral en `chainId 421614`.
- Direcciones y transacciones registradas en
  `deployments/arbitrum-sepolia.md`.
- Se ejecuto una compra real de prueba por `20 MockUSDC`.
- Se confirmo el envio y la recepcion on-chain.
- La orden finalizo en estado `Completed`.
- Los ERC-1155 fueron quemados.
- El stock disponible se redujo de `100` a `98`.
- El escrow finalizo con saldo `0 MockUSDC`.

## 2026-06-15 - Demostracion con cinco productores

- Se agrego `RunFiveProducerDemo.s.sol` y su prueba integral.
- Se registraron cinco productores independientes en Arbitrum Sepolia.
- Se crearon lotes de miel, cafe, trigo, aceite y yerba.
- Cada productor completo una venta mediante compra, confirmacion de envio y
  confirmacion de recepcion.
- Las ordenes `2` a `6` finalizaron en estado `Completed`.
- Cada productor recibio el `99%` de su venta.
- La tesoreria recibio un total de `0.93 MockUSDC`.
- El escrow finalizo con saldo `0 MockUSDC`.
- Los tokens ERC-1155 de las cinco compras fueron quemados.
- El stock de cada lote se redujo permanentemente segun la cantidad vendida.
- Para contabilidad, `maxSupply` representa el stock inicial historico y el
  modelo local final separa stock reservado, vendido, retirado y disponible.
- Direcciones, saldos y transacciones quedaron registrados en
  `deployments/arbitrum-sepolia.md`.

## 2026-06-15 - Modelo de indexacion descentralizada

- Se definio un flujo para indexar eventos confirmados de Arbitrum hacia Inery.
- Arbitrum y los contratos permanecen como fuente de verdad para stock, pagos y
  estados.
- Inery conserva vistas humanas, historicas y consultables.
- Se definieron colecciones para productores, lotes, ordenes, pagos y eventos.
- Cada evento se identifica de forma unica por `chainId`, `transactionHash` y
  `logIndex`.
- El contenido humano del lote vive off-chain y su `metadataHash` queda anclado
  en `RuralProducts1155`.
- Se agregaron ejemplos canonicos para el lote `#1001` y una venta completa.

## 2026-06-15 - Auditoria de fallas y disputas

- Se detecto y corrigio que un envio podia confirmarse despues del plazo de
  siete dias.
- Desde el vencimiento exacto solo corresponde revision y reembolso.
- Se detecto y corrigio que una disputa ganada por el comprador no podia
  registrar culpa del productor.
- Las resoluciones para comprador y divididas permiten indicar explicitamente
  si corresponde penalizacion.
- La primera culpa confirmada eleva la tarifa futura al `5%`.
- La segunda culpa confirmada suspende al productor.
- El administrador puede abrir una disputa por reclamos recibidos fuera del
  panel, por ejemplo WhatsApp o correo.
- Se agrego una matriz integral con cinco productores y cinco resoluciones.
- Queda pendiente definir el plazo maximo para ordenes detenidas en
  `ProductSent` y si distintos tipos de culpa comparten sanciones.

## 2026-06-15 - Propuesta de ventana logistica

- Se propone conservar `7 dias` desde la compra para confirmar un envio real.
- Se propone agregar una ventana logistica minima de `21 dias` desde `sentAt`.
- La ventana de `21 dias` permite intentos de entrega y devolucion al emisor.
- Vencer la ventana logistica no mueve fondos automaticamente; habilita revision
  administrativa.
- Producto incorrecto, calidad discutida, danos y problemas del correo pueden
  resolverse economicamente, pero no deben generar sanciones automaticas.
- La falta objetiva propuesta es declarar un envio que no posee aceptacion
  verificable del correo.
- Queda por confirmar si no enviar dentro de los primeros `7 dias` continua
  contando como falta sancionable, como se habia definido anteriormente.
- Los permisos administrativos se migraran a multisig antes de Arbitrum One.

## 2026-06-15 - Revision funcional previa al redeploy

- Se confirmo que solo no enviar dentro de los 7 dias registra falta del
  productor.
- Calidad, producto equivocado, danos y problemas del correo no registran falta
  automatica.
- La alerta de 21 dias desde `ProductSent` no mueve fondos automaticamente.
- El productor carga manualmente empresa de correo, seguimiento, despacho,
  estado y evidencia desde su panel.
- Los datos humanos de envio se almacenan en Inery; el contrato conserva su
  hash.
- Wiker verifica el envio y el verificador operativo confirma el hash on-chain.
- Se documentaron botones y vistas para comprador, productor y administracion.
- Se detecto que el contrato actual todavia permite penalizar desde disputas y
  conserva una revision de entrega de 7 dias; ambos puntos deben corregirse
  antes del redeploy.
- Se detecto que utilizar un unico multisig para confirmar cada envio no escala.
- Antes del redeploy se recomienda separar gobierno, resoluciones y verificacion
  operativa mediante roles limitados.
- Los datos logisticos visibles para comprador y vendedor deben permanecer
  cifrados o protegidos por permisos en Inery.

## 2026-06-15 - Revision de due diligence tecnica

- Se prepararon respuestas tecnicas sobre dependencias, ataques, disputas y
  funcionamiento degradado.
- Se confirmo que el prototipo actual no depende de Chainlink ni IPFS.
- Si frontend y backend fallan, los contratos y fondos permanecen en Arbitrum,
  pero las operaciones que requieren evidencia humana pueden quedar detenidas.
- No se identifico una ruta directa para retirar arbitrariamente fondos del
  escrow; las resoluciones pagan a comprador, productor y tesoreria registrados.
- La revision es interna y no reemplaza una auditoria de seguridad externa.
- Se identifico el agotamiento malicioso de stock en el modelo anterior.
- Se corrigio localmente separando stock reservado, vendido y retirado; los
  reembolsos con producto recuperado liberan nuevamente la reserva.
- Todavia no existe una estimacion defendible del costo minimo para manipular el
  sistema de forma rentable.

## 2026-06-15 - Correccion del modelo de stock

- Se reemplazo `allocatedSupply` por stock reservado, vendido y retirado.
- Una compra emite ERC-1155 al comprador y aumenta `reservedSupply`.
- Una venta completada quema los tokens, reduce la reserva y aumenta
  `soldSupply`.
- Un reembolso quema los tokens y libera la reserva cuando el producto nunca fue
  enviado o fue recuperado.
- Si un producto no fue recuperado, la resolucion lo mueve a `retiredSupply`.
- Solo el stock disponible puede retirarse administrativamente y debe incluir un
  hash de motivo.
- Se agrego una prueba donde un comprador reserva todo un lote, recibe un
  reembolso y otro comprador puede adquirir nuevamente el lote completo.
- No se agregaron limites de compra por wallet ni por orden.

## 2026-06-15 - Arbitraje de devoluciones fisicas

- Se agregaron estados `ReturnApproved` y `ReturnShipped`.
- Una disputa puede convertirse en devolucion autorizada.
- El reembolso no se ejecuta hasta que Wiker verifica que el productor recibio
  el producto devuelto.
- Hasta entonces, fondos, tokens y stock permanecen reservados.
- Si el producto devuelto es vendible, el stock vuelve a estar disponible.
- Si no es vendible, pasa a `retiredSupply`.
- Si el comprador nunca envia la devolucion, la orden puede resolverse para el
  productor.
- Una orden ya completada no puede revertirse porque los fondos dejaron el
  escrow.

## 2026-06-15 - Bloqueantes previos al redeploy implementados

- Se separaron roles de `governance`, `resolver` y `verifier`.
- El verificador puede confirmar envios y entregas, pero no mover fondos.
- El resolutor puede resolver fondos, pero no cambiar configuracion.
- Gobierno puede rotar resolutor, verificador y tesoreria.
- Se agrego alerta de revision logistica despues de 21 dias desde `sentAt`, sin
  movimiento automatico de fondos.
- Una devolucion aprobada debe despacharse dentro de 7 dias.
- Una devolucion ya despachada solo puede cerrarse mediante recepcion verificada
  o arbitraje especifico.
- El script de despliegue acepta direcciones separadas para gobierno, resolutor,
  verificador y tesoreria.

## 2026-06-15 - Redeploy con roles separados en Arbitrum Sepolia

- Se simulo y transmitio exitosamente la nueva version en `chainId 421614`.
- Se asignaron direcciones diferentes para gobierno, resolutor, verificador y
  tesoreria.
- Se verificaron on-chain las conexiones entre registro, ERC-1155 y escrow.
- Se verificaron on-chain los plazos de 7, 21 y 7 dias.
- El lote demo se creo con 100 unidades disponibles.
- El comprador demo recibio 1,000 MockUSDC.
- Direcciones y transacciones se registraron en
  `deployments/arbitrum-sepolia.md`.

## 2026-06-15 - Clausula de revision logistica

- Se agrego una clausula operativa formal para explicar la revision logistica
  despues de 21 dias desde `ProductSent`.
- La clausula aclara que el plazo no libera fondos, no reembolsa, no penaliza,
  no cancela y no modifica stock automaticamente.
- El frontend debe mostrar esta clausula antes de que el comprador firme la
  operacion.

## 2026-06-16 - Fuzzing inicial de seguridad

- Se agrego `test/RuralProtocolFuzz.t.sol`.
- Se incorporaron pruebas fuzz para cantidades variables de compra, reembolso
  por falta de envio, pausa de compras y resolucion dividida de disputa.
- Las propiedades verificadas cubren consistencia de escrow, stock reservado,
  stock retirado, tokens ERC-1155 y pagos a comprador, productor y tesoreria.
- La suite completa queda en `59 passed, 0 failed`.

## 2026-06-16 - Pruebas locales de carga de compras

- Se agrego `test/RuralProtocolLoad.t.sol`.
- Se simularon 100 wallets comprando el mismo lote sin romper contabilidad de
  escrow, ordenes, tokens ERC-1155 ni stock reservado.
- Se simulo agotamiento completo del supply con 100 wallets y se verifico que
  una compra adicional revierte sin cobrar USDC ni emitir tokens.
- La prueba representa compras ordenadas por la EVM, no paralelismo real fuera
  de blockchain.
- La suite completa queda en `61 passed, 0 failed`.

## 2026-06-16 - Estimacion de gas operativo

- Se ejecuto `forge test --gas-report`.
- Se documento `docs/GAS_ESTIMATES.md`.
- Se separo el gas pagado por comprador del gas operativo pagado por Wiker.
- Las acciones operativas principales del escrow se estiman entre `36k` y
  `184k` gas segun la funcion.
- La compra queda del lado del comprador y se observa cerca de `306k` gas
  tipicos.

## 2026-06-16 - Coverage defensivo de RuralEscrow

- Se agrego `test/RuralEscrowNegativeBranches.t.sol`.
- Se cubrieron ramas negativas de hashes cero, direcciones cero, montos
  invalidos, estados incorrectos, deadlines y resoluciones de devolucion.
- `RuralEscrow.sol` subio a:
  - `97.13%` lineas;
  - `96.93%` statements;
  - `95.12%` branches;
  - `100.00%` funciones.
- La suite completa queda en `71 passed, 0 failed`.
