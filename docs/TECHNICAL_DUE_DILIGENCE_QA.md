# Technical Due Diligence Q&A

## Current status

These answers describe the current Arbitrum Sepolia testnet deployment with
separated operational roles. The protocol has not completed an independent
security audit and must not be presented as production-ready.

Current testnet role separation:

- governance: configuration, treasury updates, role rotation, and pause;
- resolver: refunds, dispute resolutions, and return resolutions;
- verifier: shipment, delivery, and return-shipment confirmations only;
- treasury: receives protocol fees.

Before Arbitrum One, the privileged roles must be moved from testnet wallets to
the selected multisig structure and the operational/legal procedures must be
approved.

## What is the largest unresolved technical risk in the protocol today?

The largest unresolved risk is privileged-role compromise or collusion combined
with operational dependency on Wiker evidence review.

The current contracts separate governance, resolver, verifier, and treasury
roles. This removes the previous single-admin concentration, but the system still
depends on privileged actors to interpret real-world evidence and execute
correct resolutions.

The verifier can move an order into shipment-related states but cannot directly
move escrowed funds. The resolver can move funds through the contract's allowed
resolution paths. Governance can rotate roles, pause the protocol, and change
configuration. A compromised or colluding privileged role can still cause
incorrect operational outcomes even if direct arbitrary withdrawals are not
available.

The remaining production controls are multisig thresholds, signer independence,
external audit, monitoring, maximum exposure limits, and documented legal
procedures for evidence review.

## Which assumptions must remain true for the system not to fail?

- Arbitrum continues processing transactions and preserving contract state.
- The configured USDC contract behaves as expected and remains transferable.
- Governance, resolver, verifier, and future multisig signing keys remain
  secure.
- Wiker verifies real shipment evidence honestly and within the required time.
- Dispute resolvers do not collude with buyers or producers.
- Producers and buyers retain access to their wallets.
- Off-chain evidence remains available and its content matches the hashes stored
  on-chain.
- The application correctly displays the contract state and does not treat
  backend data as the source of truth for payments.
- The protocol does not accept more value than its operational and legal dispute
  process can handle.

## If Chainlink, IPFS, and the backend go offline simultaneously, what still works?

The current protocol does not depend on Chainlink or IPFS for escrow execution.

If the backend and user interface are offline:

- all existing contract state remains readable directly from Arbitrum;
- buyers can purchase directly through the contract if they know the contract
  address, lot ID, amount, and agreement hash;
- buyers can confirm receipt and open eligible disputes directly on-chain;
- authorized role accounts can resolve orders directly on-chain;
- ERC-1155 balances, stock, order status, and escrowed USDC remain intact.

What stops or becomes operationally unsafe:

- human-readable product metadata and private evidence may be unavailable;
- producers cannot submit shipment information through the application;
- Wiker cannot reliably verify new shipment evidence;
- notifications, indexing, and Inery synchronization stop;
- disputes requiring off-chain evidence cannot be resolved responsibly.

Funds are not automatically lost, but some orders may remain locked until the
off-chain services recover.

## How would an attacker attempt to steal funds from the protocol today?

The most credible attack paths are:

1. Compromise governance and rotate roles or change critical configuration.
2. Compromise the resolver role and execute incorrect dispute resolutions within
   the allowed contract paths.
3. Compromise the verifier role and submit false shipment, delivery, or return
   confirmations.
4. Compromise a buyer wallet and confirm receipt before the legitimate buyer
   intends to release payment.
5. Collude with privileged operators to release escrowed funds
   incorrectly.
6. Exploit operational verification by submitting false shipment evidence.
7. Target the frontend to make users approve or interact with incorrect
   contracts.
8. Manipulate off-chain evidence or metadata before Wiker records the evidence
   hash used for resolution.

Direct arbitrary withdrawal from escrow has not been identified in the current
implementation. Resolution payments are restricted to the recorded buyer,
producer, and treasury. However, this statement is based on internal review and
tests, not an independent audit.

## What did your most recent security review identify as critical vulnerabilities?

The latest review was an internal engineering review, not an external security
audit. It identified:

- shipment could previously be confirmed after the seven-day deadline;
- dispute resolutions could incorrectly register subjective producer fault;
- only the buyer could initially open a dispute, potentially leaving funds
  locked when the buyer reported through another channel;
- a single administrator role had excessive authority;
- orders could remain indefinitely in `ProductSent`;
- the previous stock model allowed refunded orders to consume stock permanently;
- shipment confirmation through a governance multisig would not scale
  operationally;
- buyer refunds after return approval could execute before confirming return
  shipment;
- shipped returns could still be resolved through the generic producer-win path;
- deployment scripts needed explicit separated role addresses.

Current status: these items were mitigated in contracts, tests, and the latest
Arbitrum Sepolia redeployment. Remaining production work is external audit,
mainnet multisig setup, operational/legal approval, frontend integration, Inery
integration, and production monitoring.

## Can you demonstrate a failed dispute case and how it was resolved?

Yes. The local dispute and return tests demonstrate independent failure paths:

- no shipment: full buyer refund and producer shipment failure;
- shipment reported but buyer not delivered: full buyer refund;
- buyer dispute rejected after producer proves delivery: producer paid;
- carrier damage: funds split between buyer and producer;
- dispute escalated to legal review and later resolved;
- return approved and returned product recovered: buyer refund with stock
  restored;
- return approved but buyer never ships back: producer paid after the return
  deadline;
- returned product damaged or unrecovered: buyer/producer funds can be split or
  refunded with stock retired.

For five orders of `20 USDC` each, the test verifies:

```text
Total deposited: 100.00 USDC
Buyer refunds: 70.00 USDC
Producer payments: 29.70 USDC
Wiker fees: 0.30 USDC
Final escrow balance: 0.00 USDC
```

The demonstrations are implemented in `test/DisputeScenarioMatrix.t.sol` and
`test/RuralEscrow.t.sol`.

## How much would it cost an attacker to manipulate the system profitably?

We cannot currently provide a defensible numeric answer.

Under the current testnet architecture, roles are separated but still controlled
by testnet operational wallets. That means the attack cost is primarily the cost
of compromising or coercing the relevant privileged role, not an on-chain
economic threshold.

After mainnet multisig migration, a governance or resolution attack should
require compromising the relevant multisig threshold. However, this still does
not produce a complete numeric security bound because the protocol depends on
real-world shipment and dispute evidence.

The previously identified stock-griefing vector required only gas and temporary
USDC capital. The current implementation separates reserved, sold, and retired
stock. Refunded orders restore availability only when the product was recovered
or never shipped, preventing refunded purchases from permanently exhausting a lot
unless the resolver intentionally retires unrecovered stock.

Before production, Wiker must define and test:

- stock accounting and recovery decisions in dispute resolutions;
- multisig threshold and signer independence;
- maximum escrow exposure per order, producer, and day;
- monitoring and emergency response times.

Until those controls exist, the correct answer is that profitable manipulation
cost has not been bounded.
