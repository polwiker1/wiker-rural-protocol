# Technical Due Diligence Q&A

## Current status

These answers describe the current prototype and the changes required before a
final testnet redeployment. The protocol has not completed an independent
security audit and must not be presented as production-ready.

## What is the largest unresolved technical risk in the protocol today?

The largest unresolved risk is privileged-role compromise combined with
operational dependency on Wiker.

The current contracts use one administrator address for shipment confirmation,
refunds, dispute resolution, producer management, and configuration. A
compromised administrator can make incorrect dispute decisions and disrupt the
protocol.

Before production, permissions must be separated between:

- governance multisig;
- dispute-resolution multisig;
- limited shipment verifier.

The most recent internal review identified a stock-griefing risk in the previous
model. It has been corrected locally by separating reserved, sold, and retired
stock. Refunded orders restore availability only when the product was recovered
or never shipped.

## Which assumptions must remain true for the system not to fail?

- Arbitrum continues processing transactions and preserving contract state.
- The configured USDC contract behaves as expected and remains transferable.
- Administrative and future multisig signing keys remain secure.
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

The current prototype does not depend on Chainlink or IPFS.

If the backend and user interface are offline:

- all existing contract state remains readable directly from Arbitrum;
- buyers can purchase directly through the contract if they know the contract
  address, lot ID, amount, and agreement hash;
- buyers can confirm receipt and open eligible disputes directly on-chain;
- authorized accounts can resolve orders directly on-chain;
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

1. Compromise the current administrator key and abuse dispute resolutions or
   configuration.
2. Compromise a buyer wallet and confirm receipt before the legitimate buyer
   intends to release payment.
3. Collude with an administrator or dispute resolver to release escrowed funds
   incorrectly.
4. Exploit operational verification by submitting false shipment evidence.
5. Abuse stock consumption through purchases followed by refunds or favorable
   dispute resolutions.
6. Target the frontend to make users approve or interact with incorrect
   contracts.

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
  operationally.

The first three items were implemented and tested locally. The remaining
architecture changes must be completed before redeployment.

## Can you demonstrate a failed dispute case and how it was resolved?

Yes. The local dispute matrix demonstrates five independent orders:

- no shipment: full buyer refund and producer shipment failure;
- shipment reported but buyer not delivered: full buyer refund;
- buyer dispute rejected after producer proves delivery: producer paid;
- carrier damage: funds split between buyer and producer;
- dispute escalated to legal review and later resolved.

For five orders of `20 USDC` each, the test verifies:

```text
Total deposited: 100.00 USDC
Buyer refunds: 70.00 USDC
Producer payments: 29.70 USDC
Wiker fees: 0.30 USDC
Final escrow balance: 0.00 USDC
```

The demonstration is implemented in `test/DisputeScenarioMatrix.t.sol`.

## How much would it cost an attacker to manipulate the system profitably?

We cannot currently provide a defensible numeric answer.

Under the current testnet architecture, compromise of the single administrator
key may be sufficient to manipulate operational decisions. That means the attack
cost is primarily the cost of compromising or coercing one privileged signer,
not an on-chain economic threshold.

After multisig and role separation, the minimum governance attack should require
compromising the multisig threshold. However, this still does not produce a
quantifiable economic-security value.

The previously identified stock-griefing vector required only gas and temporary
USDC capital. The local implementation now releases reserved stock after valid
refunds, preventing a refunded buyer from permanently exhausting a lot.

Before production, Wiker must define and test:

- stock accounting and recovery decisions in dispute resolutions;
- multisig threshold and signer independence;
- maximum escrow exposure per order, producer, and day;
- monitoring and emergency response times.

Until those controls exist, the correct answer is that profitable manipulation
cost has not been bounded.
