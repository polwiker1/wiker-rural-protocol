# Arquitectura MVP

## Actores

| Actor | Responsabilidad |
| --- | --- |
| Administrador Wiker | Registra productores, aprueba lotes y confirma envios |
| Productor | Publica productos mediante Wiker e informa envios |
| Comprador | Compra, confirma recepcion, solicita reembolso o disputa |
| Tesoreria Wiker | Recibe la tarifa del protocolo |
| Instancia legal | Resuelve disputas escaladas |

## Contratos

### `ProducerRegistry`

- Mantiene productores registrados.
- Registra incumplimientos por falta de envio.
- Suspende automaticamente al segundo incumplimiento.
- Solo el escrow autorizado puede reportar incumplimientos.

### `RuralProducts1155`

- Registra lotes aprobados y su supply maximo.
- Registra el precio unitario en USDC para que el escrow no confie en importes
  enviados por el frontend.
- Los precios se expresan en la unidad minima del token de pago configurado. En
  USDC, `10 USDC` se registra como `10_000_000`.
- Emite unidades directamente al comprador por orden del escrow.
- Impide transferencias entre usuarios.
- Quema unidades al completar o reembolsar ordenes.
- Conserva consumido el supply de ventas completadas.
- Conserva consumido el supply de ordenes reembolsadas por incumplimiento.
- Nunca restaura supply automaticamente.

### `RuralEscrow`

- Recibe pagos USDC.
- Crea ordenes y solicita emision ERC-1155.
- Registra envio confirmado por Wiker.
- Recibe confirmacion de recepcion del comprador.
- Permite a la administracion ejecutar reembolsos por falta de envio luego de
  siete dias y revision del caso.
- Congela ordenes disputadas.
- Ejecuta resoluciones administrativas.
- Distribuye `99%` al productor y `1%` a la tesoreria en ventas exitosas.
- Consulta la tarifa vigente del productor. Despues del primer incumplimiento,
  futuras ventas exitosas distribuyen `95%` al productor y `5%` a Wiker.
- La pausa global impide compras nuevas, pero no bloquea reembolsos ni
  resoluciones existentes.
- El comprador informa un importe maximo aceptado. La compra revierte si el
  precio on-chain aumento respecto del total mostrado en el frontend.

## Componentes off-chain

### Marketplace y paneles

Una unica aplicacion muestra vistas segun el rol asociado a la wallet:

- marketplace publico;
- panel comprador;
- panel productor;
- panel administrador.

### Backend privado

Guarda informacion que no debe publicarse on-chain:

- datos personales;
- codigos de seguimiento;
- fotos y comprobantes;
- mensajes de WhatsApp y correo;
- notas administrativas;
- documentos legales.

El protocolo registra hashes para probar integridad sin publicar el contenido.

## Limites

- El contrato no consulta APIs externas directamente.
- El costo y pago del envio quedan fuera del escrow.
- WhatsApp y email notifican, pero no reemplazan el estado on-chain.
- El administrador MVP es una wallet. Se migrara a multisig antes de
  produccion.
