# The Working App — Master Build Guide

This is the single source of truth for building The Working App from this scaffold to a
production-ready application. Read this first. Then read the BUILD.md in each workspace.

---

## Repository Map

```
theworkingapp/
├── docs/                        ← Product docs (idea doc v0.3, PRD v1.0)
├── contracts/                   ← Solidity smart contracts (Foundry)
│   ├── BUILD.md                 ← CONTRACTS BUILD GUIDE — read this
│   ├── src/
│   │   ├── interfaces/          ← IDataTypes, IPlatformNFTRegistry, ICommunityRegistry,
│   │   │                           IProjectContract, IBountyContract — ALL WRITTEN
│   │   ├── PlatformNFTRegistry.sol  ← Core implementation written, test coverage TODO
│   │   ├── PlatformFactory.sol      ← Stub — deployCommunity + deployBounty TODO
│   │   ├── CommunityRegistry.sol    ← Stub — deployProject + full membership TODO
│   │   ├── ProjectContract.sol      ← Stub — most functions TODO (see BUILD.md Step 6)
│   │   └── BountyContract.sol       ← Mostly complete — panel vote TODO
│   ├── test/unit/PlatformCore.t.sol ← Written — extend for all contracts
│   └── script/Deploy.s.sol          ← Written — run to deploy
│
├── backend/                     ← Node.js / TypeScript API
│   ├── BUILD.md                 ← BACKEND BUILD GUIDE — read this
│   ├── prisma/schema.prisma     ← Full schema written — run migrate
│   └── src/
│       ├── index.ts             ← Entry point — written
│       ├── config/env.ts        ← Env validation — written
│       ├── types/index.ts       ← All TypeScript types — written
│       ├── middleware/          ← Auth, errorHandler, rateLimiter — written
│       ├── routes/              ← Route stubs — wire to controllers
│       ├── routes/_stubs.ts     ← Full route list with TODO comments
│       ├── controllers/
│       │   └── AuthController.ts  ← Stub — implement AuthService calls
│       ├── services/
│       │   ├── blockchain/
│       │   │   ├── BlockchainService.ts  ← Stub — implement all methods
│       │   │   └── eventListener.ts      ← Stub — implement event handlers
│       │   ├── ipfs/IPFSService.ts       ← Stub — implement with Pinata SDK
│       │   └── onramp/OnRampService.ts   ← Stub — implement Onramper integration
│       └── utils/               ← logger, AppError — written
│
├── frontend/                    ← React 18 + Vite + Tailwind
│   ├── BUILD.md                 ← FRONTEND BUILD GUIDE — read this
│   └── src/
│       ├── main.tsx, App.tsx    ← Entry + routing — written
│       ├── index.css            ← Global styles + component classes — written
│       ├── lib/api.ts           ← Axios client with JWT + refresh — written
│       ├── lib/wagmi.ts         ← Wagmi config — written
│       ├── context/
│       │   ├── AuthContext.tsx  ← Full auth context — written
│       │   └── SocketContext.tsx ← Socket.IO context — written
│       ├── types/index.ts       ← Frontend types (mirror backend) — written
│       ├── hooks/index.ts       ← All data hooks (React Query) — written
│       ├── components/
│       │   ├── common/
│       │   │   ├── AppShell.tsx ← Stubbed — complete Step 2
│       │   │   └── index.tsx    ← StateBadge, VoteTally, EmptyState etc. — written
│       │   └── project/
│       │       └── MilestoneTracker.tsx ← Full component — written
│       └── pages/               ← All pages stubbed with BUILD GUIDE comments
│
├── programs/                    ← Rust/Anchor Solana programs (Phase 2)
│   └── README.md                ← Phase 2 design doc — read before starting
│
└── infra/
    ├── docker/docker-compose.yml  ← Postgres + Redis — written
    └── .github/workflows/ci.yml  ← GitHub Actions CI — written
```

---

## Build Sequence

Follow this sequence across all three workstreams. Do not skip steps.

### Phase 1 — Foundation (Months 1–6)

#### Workstream A: Smart Contracts

Work through `contracts/BUILD.md` Steps 1–9 in order:

| Step | What | Status |
|---|---|---|
| 1 | Interfaces (IDataTypes, all I*.sol) | ✅ Written |
| 2 | Libraries (Escrow, Voting, MilestoneManager) | ⬜ TODO |
| 3 | PlatformNFTRegistry | ✅ Core written — needs test coverage |
| 4 | PlatformFactory (deployCommunity, deployBounty) | ⬜ TODO |
| 5 | CommunityRegistry (deployProject, full membership) | ⬜ TODO |
| 6 | ProjectContract (full state machine) | ⬜ TODO (most complex) |
| 7 | BountyContract (panel vote) | ⬜ TODO (mostly written) |
| 8 | Tests (all contracts, fuzz, integration) | ⬜ TODO |
| 9 | Deploy scripts + deployment verification | ⬜ TODO |

**Priority order within Step 6 (ProjectContract):**
1. `castProposalVote` + threshold check
2. `councilDecision`
3. `awardContract` (tiered logic)
4. `fundEscrow`
5. `submitMilestoneCompletion` + all three verification types
6. `castCompletionVote`
7. `raiseDispute` + `executeMediationRuling`
8. `requestPortionGrant` + `approvePortionGrant`

**Before audit submission:** complete the security checklist in `contracts/BUILD.md`.

---

#### Workstream B: Backend API

Work through `backend/BUILD.md` Steps 1–12 in order:

| Step | What | Status |
|---|---|---|
| 1 | Database schema + migrations | ✅ Schema written — run migrate |
| 2 | Config, utilities | ✅ Written |
| 3 | BlockchainService (all methods) | ⬜ TODO |
| 4 | IPFSService (Pinata) | ⬜ TODO |
| 5 | OnRampService (Onramper + webhook) | ⬜ TODO |
| 6 | AuthService + AuthController | ⬜ TODO |
| 7 | CommunityService + Controller | ⬜ TODO |
| 8 | ProjectService + Controller | ⬜ TODO (most complex) |
| 9 | BountyService + Controller | ⬜ TODO |
| 10 | NFT metadata endpoint | ⬜ TODO |
| 11 | NotificationService | ⬜ TODO |
| 12 | Tests (Jest + Supertest) | ⬜ TODO |

**Critical path (implement first):**
AuthService → BlockchainService.mintPlatformNFT → CommunityService → ProjectService.submitProposal

**ABI dependency:** BlockchainService requires compiled ABIs from Foundry.
Complete contracts workstream Steps 3–4 before starting Step 3 of backend.

---

#### Workstream C: Frontend

Work through `frontend/BUILD.md` Steps 1–11 in order:

| Step | What | Status |
|---|---|---|
| 1 | Auth pages (Login, Register) | ⬜ TODO |
| 2 | AppShell + navigation | ⬜ Stubbed |
| 3 | Dashboard | ⬜ TODO |
| 4 | Community pages | ⬜ TODO |
| 5 | Project detail | ⬜ TODO |
| 6 | New project (milestone form) | ⬜ TODO |
| 7 | Bounty pages | ⬜ TODO |
| 8 | Profile + settings | ⬜ TODO |
| 9 | EscrowFundingPanel (Onramper iframe) | ⬜ TODO |
| 10 | Crypto-Native mode components | ⬜ TODO |
| 11 | Mediation page | ⬜ TODO |

**Critical path (implement first):**
Login → Register → Dashboard → CommunityPage → ProjectDetailPage → EscrowFundingPanel

**Hooks are written.** The React Query hooks in `src/hooks/index.ts` are complete.
Pages just need to call them and render the results.

---

### Phase 2 — Multi-Chain & Identity (Months 7–12)

| Item | Owner | Notes |
|---|---|---|
| ZK-KYC integration | Backend + Contracts | Polygon ID or equivalent provider |
| Solana Anchor programs | Programs workstream | See programs/README.md |
| Solana backend integration | Backend | Add Solana provider to BlockchainService |
| Cross-chain community choice | Frontend + Backend | Chain selector in NewCommunityPage |
| NFT-gated membership mode | All | Requires ZK-KYC to be live |
| Analytics dashboard (council) | Frontend + Backend | New route: /api/v1/communities/:id/analytics |
| USSD voting groundwork | Backend | Relay API endpoint for USSD voting |

---

### Phase 3 — Scale (Month 13+)

| Item | Notes |
|---|---|
| USSD voting live | Integrate USSD gateway (Africa's Talking, Twilio) |
| Contractor insurance layer | Optional bonding mechanism per project |
| Additional EVM chains | On community demand — add to wagmiConfig + backend RPC |
| The Graph subgraph | Replace event polling with proper indexing |
| Platform advisory council | Governance upgrade — community council representatives |

---

## Cross-Workstream Dependencies

```
contracts/Build.sol (ABIs)
    ↓
backend/src/services/blockchain/BlockchainService.ts (imports ABIs)
    ↓
backend/src/services/project/ProjectService.ts (calls BlockchainService)
    ↓
backend/src/routes/projects.ts → controllers → services
    ↓
frontend/src/hooks/index.ts (calls backend API)
    ↓
frontend/src/pages/ProjectDetailPage.tsx (renders data)
```

**If you are working solo:** complete contracts → backend → frontend in sequence.
**If you have a team:** contracts and backend can run in parallel after Step 3 of contracts
(PlatformNFTRegistry) is complete and can be compiled to generate ABIs.

---

## Environment Setup Checklist

Before writing a single line of implementation code, complete this:

- [ ] PostgreSQL running (via docker-compose)
- [ ] Redis running (via docker-compose)
- [ ] `backend/.env` filled in (copy from .env.example)
- [ ] `frontend/.env` filled in (copy from .env.example)
- [ ] `contracts/.env` filled in (copy from .env.example)
- [ ] Foundry installed (`foundryup`)
- [ ] `forge install` run inside `contracts/`
- [ ] `npm install` run inside `backend/` and `frontend/`
- [ ] `npx prisma migrate dev` run inside `backend/`
- [ ] Anvil running locally (`anvil` in a terminal)
- [ ] Contracts deployed to local Anvil (`forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast`)
- [ ] Contract addresses copied to `backend/.env`
- [ ] Backend API running (`npm run dev` in `backend/`)
- [ ] Frontend running (`npm run dev` in `frontend/`)

---

## Key Design Decisions (Do Not Change Without Full Review)

| Decision | Rationale |
|---|---|
| Mandatory escrow | Non-optional. Without it, contractors can't be held accountable. |
| Milestone-based release | Single lump-sum payment is not acceptable for large projects. |
| Final milestone = community vote always | Council alone cannot sign off on final delivery. |
| Soulbound NFT (non-transferable) | Reputation must follow the person, not be sold. |
| No central treasury | Every project is its own escrow. No pooled funds. |
| Company-governed platform | Clear legal accountability. Not a DAO at platform level. |
| Stablecoins only (USDT/USDC) | No price volatility risk for community funds. |
| IPFS for attachments | Files too large for on-chain storage; IPFS hashes are immutable. |
| Standard Mode hides blockchain | Blockchain is infrastructure, not the product. |
| Portion grant capped at 30% | Protects community funds if contractor abandons project. |

---

## Getting Help

- **Smart contracts:** See `contracts/BUILD.md` for step-by-step implementation guide
- **Backend:** See `backend/BUILD.md` for service dependency map and implementation order
- **Frontend:** See `frontend/BUILD.md` for page-by-page build guide and component list
- **Product decisions:** See `docs/The Working App_Idea_Doc_v0.3.md` and `docs/The Working App_PRD_v1.0.docx`
