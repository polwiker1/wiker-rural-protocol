# Wiker Rural Protocol

Smart contracts para representar lotes de productos rurales mediante ERC-1155 y
proteger sus pagos mediante escrow.

El repositorio se desarrolla separado de la preventa WKR y del frontend del
Mercado Rural Wiker. La primera integracion se realizara en Arbitrum Sepolia con
un MockUSDC. Mainnet utilizara Arbitrum One y USDC oficial luego de pruebas,
revision legal y auditoria.

## Alcance MVP

- Productores registrados y administrados por Wiker.
- Lotes aprobados por Wiker con supply maximo.
- ERC-1155 no transferible entre usuarios.
- Tokens emitidos directamente al comprador al pagar.
- USDC retenido en escrow hasta completar la operacion.
- Envio acordado y pagado fuera del protocolo.
- Confirmacion manual de envio por Wiker.
- Confirmacion de recepcion por el comprador.
- Reembolsos, disputas y resoluciones por orden.

## Documentacion

- `BITACORA.md`: decisiones confirmadas y cambios del modelo.
- `docs/ARCHITECTURE.md`: contratos, actores y responsabilidades.
- `docs/FLOWS.md`: estados y recorridos de lotes y ordenes.
- `docs/DISPUTE_MATRIX.md`: escenarios, resoluciones y riesgos de disputas.
- `docs/FRONTEND_WORKFLOWS.md`: acciones y datos requeridos por cada panel.
- `docs/PRE_REDEPLOY_REVIEW.md`: diferencias pendientes antes del redeploy.
- `docs/TECHNICAL_DUE_DILIGENCE_QA.md`: respuestas de seguridad y dependencias.
- `docs/OPERATIONAL_CLAUSES.md`: clausulas operativas para usuarios.
- `docs/SECURITY.md`: riesgos y controles requeridos.
- `docs/DEPLOYMENT.md`: simulacion y despliegue en Arbitrum Sepolia.
- `docs/INERY_INDEXING.md`: esquema y flujo para indexar el protocolo.
- `deployments/arbitrum-sepolia.md`: direcciones y pruebas on-chain.
- `examples/inery/`: registros canonicos de lote y orden.

## Desarrollo

```bash
forge build
forge test
forge fmt
```

## Estado

En especificacion e implementacion inicial. No apto para produccion.
