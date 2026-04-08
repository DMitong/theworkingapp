# The Working App

> Decentralized Community Project Protocol — blockchain-anchored civic governance, transparent contracting, and milestone-based escrow for any organized community.

---

## Repository Structure

```
theworkingapp/
├── docs/                        # Product documents (idea doc, PRD)
├── contracts/                   # Solidity smart contracts (Foundry)
│   ├── src/
│   │   ├── interfaces/          # Contract interfaces
│   │   ├── libraries/           # Shared libraries
│   │   ├── PlatformFactory.sol
│   │   ├── PlatformNFTRegistry.sol
│   │   ├── CommunityRegistry.sol
│   │   ├── ProjectContract.sol
│   │   └── BountyContract.sol
│   ├── test/                    # Foundry tests
│   ├── script/                  # Deployment scripts
│   └── lib/                     # Foundry dependencies (git submodules)
├── backend/                     # Node.js / TypeScript API
│   └── src/
│       ├── routes/
│       ├── controllers/
│       ├── services/
│       ├── models/
│       ├── middleware/
│       ├── types/
│       ├── utils/
│       └── config/
├── frontend/                    # React web application (mobile-first)
│   └── src/
│       ├── components/
│       ├── pages/
│       ├── hooks/
│       ├── context/
│       └── utils/
├── programs/                    # Rust / Anchor — Solana contracts (Phase 2)
└── infra/                       # Docker, CI/CD, deployment scripts
```

---

## Quick Start

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Node.js | ≥ 20 | Backend & frontend |
| Foundry | latest | Smart contract development |
| Git | any | Submodule management |
| Docker | ≥ 24 | Local infra (Postgres, Redis) |

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone and install dependencies

```bash
git clone <repo-url> theworkingapp
cd theworkingapp

# Install Foundry dependencies (OpenZeppelin etc.)
cd contracts && forge install && cd ..

# Install backend dependencies
cd backend && npm install && cd ..

# Install frontend dependencies
cd frontend && npm install && cd ..
```

### 3. Set up environment variables

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
# Edit both .env files with your values
```

### 4. Start local services

```bash
# Start Postgres + Redis
docker-compose -f infra/docker/docker-compose.yml up -d

# Start local Anvil chain (Foundry's local node)
anvil
```

### 5. Deploy contracts locally

```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 6. Run backend

```bash
cd backend
npm run dev
```

### 7. Run frontend

```bash
cd frontend
npm run dev
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts (EVM) | Solidity 0.8.x, Foundry |
| Smart Contracts (Solana, Phase 2) | Rust, Anchor |
| Backend | Node.js, TypeScript, Express, Prisma |
| Database | PostgreSQL |
| Cache | Redis |
| Frontend | React, TypeScript, Viem, Wagmi |
| File Storage | IPFS via Pinata |
| On-Ramp | Onramper, Transak |
| Blockchain Data | The Graph (indexing) |

---

## Development Workflow

- **Contracts:** Write in `contracts/src/`, test with `forge test`, deploy with `forge script`
- **Backend:** API routes → controllers → services → models. Services contain all blockchain interaction logic.
- **Frontend:** Pages use hooks that call the backend API. Blockchain interaction abstracted behind a `useWallet` context.

---

## Phase Plan

| Phase | Focus | Timeline |
|---|---|---|
| Phase 1 | Core contracts + API + frontend on single EVM chain | Months 1–6 |
| Phase 2 | Solana contracts, ZK-KYC, premium features | Months 7–12 |
| Phase 3 | USSD, insurance layer, additional chains | Month 13+ |

See `/docs` for the full PRD and idea document.

---

## Licence

Proprietary — The Working App. All rights reserved.
