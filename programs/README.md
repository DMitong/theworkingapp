# Programs — Solana / Rust / Anchor (Phase 2)

This directory will contain the Rust smart contracts for Solana deployment, written using the **Anchor** framework.

Solana deployment is Phase 2. Phase 1 ships EVM (Solidity/Foundry) only.

---

## Prerequisites (Phase 2)

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"

# Install Anchor
cargo install --git https://github.com/coral-xyz/anchor avm --locked
avm install latest && avm use latest

# Verify
anchor --version
solana --version
```

---

## Planned Program Structure

```
programs/
├── platform_factory/           # Factory: deploys community and bounty programs
│   └── src/lib.rs
├── platform_nft_registry/      # Soulbound identity NFT (Metaplex-based)
│   └── src/lib.rs
├── community_registry/         # Community registration + membership
│   └── src/lib.rs
├── project_contract/           # Project lifecycle + milestone escrow
│   └── src/lib.rs
└── bounty_contract/            # Individual bounty lifecycle
    └── src/lib.rs
```

---

## Design Parity with Solidity Contracts

All Rust/Anchor programs must implement feature parity with the Solidity contracts.
Refer to `contracts/src/` for the canonical behaviour spec.

Key differences in the Solana implementation:

| Concept | EVM (Solidity) | Solana (Anchor) |
|---|---|---|
| Contract deployment | `new Contract()` | Program Derived Addresses (PDAs) |
| Storage | Contract state variables | Anchor Account structs |
| Events | `emit EventName(...)` | Anchor `emit!(EventName {...})` |
| Access control | `msg.sender` modifiers | Signer account constraints |
| Escrow | Contract holds ERC-20 | PDA holds SPL token vault |
| Multisig | ECDSA signature recovery | Signer account array validation |
| Factory pattern | CREATE2 deployment | PDA seed-based account creation |

---

## Escrow on Solana

Escrow uses SPL tokens (USDT-SPL and USDC-SPL on Solana).
Use an Associated Token Account owned by the project PDA as the escrow vault.

```rust
// Project escrow vault PDA
#[account(
    init,
    payer = funder,
    associated_token::mint = escrow_token_mint,
    associated_token::authority = project_pda,
)]
pub escrow_vault: Account<'info, TokenAccount>,
```

---

## Solana-Specific Implementation Notes

1. **PDAs as contract equivalents:** Each community, project, and bounty is a PDA
   seeded with unique identifiers. This replaces the CREATE2 factory pattern from EVM.

2. **Cross-Program Invocations (CPI):** Where EVM contracts call other contracts directly,
   Solana programs use CPIs. The project program will CPI into the SPL Token program
   for escrow transfers.

3. **Account size limits:** Solana accounts have a default size limit. For variable-length
   data (milestone arrays, membership lists), use the `realloc` constraint or store
   IPFS hashes (fixed 46-byte strings) rather than full data.

4. **Transaction size limits:** Solana transactions are limited to ~1232 bytes.
   Operations with many accounts (like multi-milestone projects) may need to be
   split across multiple transactions.

5. **The Graph on Solana:** Use Helius webhooks or an Anchor event listener
   (similar to the EVM event listener in `backend/src/services/blockchain/eventListener.ts`)
   for indexing Solana program events.

---

## NFT on Solana

The soulbound identity NFT on Solana uses Metaplex's Token Metadata program.
It is minted as a non-transferable NFT using the `NonTransferable` extension
(available in Token-2022 / Token Extensions).

```bash
# Token-2022 non-transferable mint creation
spl-token --program-id TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb \
  create-token --non-transferable
```

---

## Timeline

- Phase 1 (Months 1–6): EVM only. This directory is a placeholder.
- Phase 2 (Months 7–12): Anchor programs built and deployed to Solana Devnet.
  Integration with backend `BlockchainService` — add Solana provider + Anchor client.
  Frontend: add Phantom wallet connector (already in wagmi config for Solana-compatible setup).
