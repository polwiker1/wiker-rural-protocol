# Clausulas operativas

## Aceptacion de roles privilegiados

Antes de operar en Arbitrum One, toda persona o entidad que controle una wallet
con permisos privilegiados debera aceptar formalmente el marco operativo de
Wiker Rural Protocol.

Esta aceptacion tendra dos capas:

- **Acuerdo legal off-chain:** documento firmado fuera de la blockchain donde el
  operador acepta sus responsabilidades, limites, prohibicion de colusion,
  obligacion de actuar con evidencia, deber de reportar perdida o compromiso de
  claves, y consecuencias legales por abuso del rol.
- **Evidencia on-chain:** la wallet asignada al rol debera aceptar o quedar
  registrada contra el hash del acuerdo operativo vigente. Ese registro debera
  vincular address, rol, version del acuerdo, hash documental, fecha o bloque, y
  estado activo o revocado.

Los roles alcanzados por esta politica incluyen, como minimo:

- gobierno;
- resolutor de disputas;
- verificador operativo;
- tesoreria;
- cualquier signer de multisig que participe en esos roles.

La finalidad de este modelo es reducir el riesgo de colusion o abuso de
permisos privilegiados mediante responsabilidad legal, trazabilidad publica y
separacion de funciones.

Una wallet privilegiada no deberia recibir permisos de produccion si no existe
evidencia verificable de:

- identidad o entidad responsable del operador;
- acuerdo legal firmado;
- hash del acuerdo operativo registrado;
- aceptacion del rol por la wallet correspondiente;
- procedimiento de revocacion ante perdida de clave, renuncia, conflicto de
  interes o conducta maliciosa.

La aceptacion on-chain no reemplaza el acuerdo legal. Su funcion es dejar una
prueba tecnica verificable de que una address acepto operar bajo una version
determinada del marco operativo.

## Revision logistica

Cuando Wiker confirme que el producto fue despachado, la operacion pasara al
estado **Producto Enviado**.

Si transcurren **21 dias corridos** desde esa confirmacion sin que el comprador
confirme recepcion, sin que Wiker verifique entrega, o sin que exista una
resolucion previa, la operacion entrara en **revision logistica**.

La revision logistica no produce automaticamente:

- liberacion del pago al productor;
- reembolso al comprador;
- penalizacion al productor;
- cancelacion de la operacion;
- modificacion del stock.

Durante la revision logistica, los fondos permaneceran retenidos en escrow hasta
que Wiker evalue la evidencia disponible, incluyendo informacion del correo,
comprobantes, comunicaciones entre las partes y cualquier documentacion
relevante.

Luego de la revision, Wiker podra resolver la operacion conforme al estado real
del envio y la evidencia disponible, pudiendo:

- liberar el pago al productor;
- reembolsar total o parcialmente al comprador;
- solicitar una devolucion;
- escalar la disputa a instancia legal;
- mantener la operacion en revision si existe una causa logistica verificable.

El comprador y el productor aceptan que los plazos logisticos pueden variar por
causas ajenas a Wiker, incluyendo demoras del correo, intentos de entrega,
devoluciones al remitente, feriados, retenciones o eventos de fuerza mayor.
