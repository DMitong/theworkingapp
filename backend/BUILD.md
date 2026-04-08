# Backend — Build Guide

Node.js / TypeScript API. Express + Prisma + Ethers.js + Socket.IO.

---

## Setup

```bash
cd backend
npm install
cp .env.example .env   # Fill in your values
npm run db:generate    # Generate Prisma client
npm run db:migrate     # Run migrations (requires Postgres running)
npm run dev            # Start with hot reload
```

---

## Build Order

Work through these layers in order. Each depends on the previous.

### Step 1 — Database Schema (`prisma/schema.prisma`)

Schema is written. Run migrations:

```bash
npx prisma migrate dev --name init
npx prisma generate
```

Verify in Prisma Studio:
```bash
npm run db:studio
```

---

### Step 2 — Config & Utilities

**`src/config/env.ts`** — Done. Add new env vars here as needed.

**`src/utils/logger.ts`** — Done.

**`src/utils/AppError.ts`** — Done.

**`src/utils/response.ts`** — TODO: Create a `sendSuccess(res, data, status?)` and `sendError(res, message, status?)` helper used by all controllers for consistent response shape.

**`src/utils/pagination.ts`** — TODO: Helper that takes `page` and `pageSize` query params and returns Prisma `skip`/`take` values and a `PaginatedResponse` wrapper.

---

### Step 3 — Blockchain Services

**`src/services/blockchain/BlockchainService.ts`**

Priority implementations (in order):

1. `init()` — Wire up provider and wallet. Call this from `src/index.ts` on startup.
2. `mintPlatformNFT()` — Called on user registration. Critical path.
3. `getNFTData()` — Called to populate user profiles. 
4. `deployCommunity()` — Called when a community council registers.
5. `getProjectContract()` — Used by ProjectService for all project interactions.
6. `fundProjectEscrow()` — Called after on-ramp webhook confirms payment.

**ABI management:**
After `forge build` in the `contracts/` directory, copy ABIs:
```bash
# From contracts/
forge build
# ABIs land in contracts/out/<Contract>.sol/<Contract>.json
# Copy or symlink to backend/src/abis/
mkdir -p backend/src/abis
cp contracts/out/PlatformFactory.sol/PlatformFactory.json backend/src/abis/
cp contracts/out/PlatformNFTRegistry.sol/PlatformNFTRegistry.json backend/src/abis/
cp contracts/out/CommunityRegistry.sol/CommunityRegistry.json backend/src/abis/
cp contracts/out/ProjectContract.sol/ProjectContract.json backend/src/abis/
cp contracts/out/BountyContract.sol/BountyContract.json backend/src/abis/
```

Then in `BlockchainService.ts`:
```typescript
import PlatformFactoryABI from '../abis/PlatformFactory.json';
const factory = new ethers.Contract(address, PlatformFactoryABI.abi, wallet);
```

**`src/services/blockchain/eventListener.ts`**

On server startup, the event listener must:
1. Attach to the PlatformFactory for new community/bounty deployments
2. Query all projects with state != COMPLETED from the DB
3. Call `listenToProject()` for each active project

This is the mechanism that keeps the PostgreSQL DB in sync with on-chain state.

---

### Step 4 — IPFS & Storage

**`src/services/ipfs/IPFSService.ts`**

Implement using the Pinata SDK:
```bash
npm install pinata
```

Key flows:
- `uploadJSON()` — Proposal data, bid packages, NFT metadata
- `uploadFile()` — Images, PDFs (completion evidence, bid documents)
- `getJSON()` — Fetch proposal/bid data by IPFS hash

File upload middleware (`src/middleware/upload.ts`):
```typescript
import multer from 'multer';
export const uploadMiddleware = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    cb(null, allowed.includes(file.mimetype));
  },
});
```

---

### Step 5 — On-Ramp Service

**`src/services/onramp/OnRampService.ts`**

See the detailed BUILD GUIDE comment inside the file.

Key webhook security implementation:
```typescript
import crypto from 'crypto';

function verifyOnramperWebhook(body: string, signature: string): boolean {
  const expected = crypto
    .createHmac('sha256', env.ONRAMPER_API_KEY)
    .update(body)
    .digest('hex');
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
}
```

---

### Step 6 — Auth Service & Controller

**`src/services/auth/AuthService.ts`** — TODO: Create.

Implement:
- `register(email, password, handle)`:
  1. Check email and handle uniqueness in DB
  2. Hash password with `bcrypt` (12 rounds)
  3. Create embedded wallet — use Privy, Dynamic.xyz, or Web3Auth SDK for MPC wallet
  4. Create User record in DB
  5. Trigger `BlockchainService.mintPlatformNFT()` — store txHash, update tokenId on confirm
  6. Sign and return JWT + refresh token (store refresh in Redis with TTL)
  7. Send verification email via SendGrid

- `login(email, password)`:
  1. Find user by email
  2. Compare password hash with bcrypt
  3. Return JWT + refresh token

- `refreshToken(token)`:
  1. Verify refresh token from Redis
  2. Issue new JWT
  3. Rotate refresh token

**JWT structure:**
```typescript
const payload = {
  sub: user.id,
  wallet: user.walletAddress,
  handle: user.handle,
  mode: user.mode,
  iat: Math.floor(Date.now() / 1000),
};
```

---

### Step 7 — Community Service & Controller

**`src/services/community/CommunityService.ts`** — TODO: Create.

- `createCommunity(data, founderId)`:
  1. Validate data
  2. Insert community record with `contractAddress: null` (pending deploy)
  3. Call `BlockchainService.deployCommunity()` — get txHash
  4. Event listener will update `contractAddress` when `CommunityDeployed` event fires
  5. Return community with status 'deploying'

- `applyForMembership(communityId, userId, proofData)`:
  1. Check community verification mode
  2. For OPEN mode: create Membership with pending status, auto-approve if no manual review required
  3. For other modes: create pending Membership record, notify council
  4. On council approval: call on-chain `approveMember()` if ZK_KYC_REQUIRED; else just update DB

- `searchCommunities(query, filters)`:
  1. Full-text search on name + description
  2. Filter by type, member count range, project count
  3. Return paginated results

**`src/controllers/CommunityController.ts`** — TODO: Create.

Wire controller methods to the routes in `src/routes/communities.ts`.

---

### Step 8 — Project Service & Controller

**`src/services/project/ProjectService.ts`** — TODO: Create. Most complex service.

- `submitProposal(communityId, userId, proposalData, files)`:
  1. Upload proposal attachments to IPFS
  2. Create IPFS metadata JSON (title, description, scope, budget, requirements)
  3. Upload metadata JSON to IPFS → get `ipfsProposalHash`
  4. Call `CommunityRegistry.deployProject()` on-chain via BlockchainService
  5. Create Project record in DB (contractAddress: null, state: PROPOSED)
  6. Event listener sets contractAddress on deployment confirmation
  7. Notify community members of new proposal

- `castProposalVote(projectId, userId, upvote)`:
  1. Check user is a community member
  2. Check voting window is open
  3. Check user hasn't voted already (ProposalVote record)
  4. Create ProposalVote record in DB
  5. Call `ProjectContract.castProposalVote()` on-chain (platform relay for Standard Mode)
  6. Update upvoteCount/downvoteCount in DB
  7. Check if threshold reached → notify council

- `awardContract(projectId, contractorAddress, milestones, councilSignatures)`:
  1. Verify caller is council member
  2. Check project is in TENDERING state
  3. Check project value vs tier thresholds
  4. If above Tier 1: require vote outcome; if below: require council signatures
  5. Call `ProjectContract.awardContract()` on-chain
  6. Update Project.awardedContractor, Project.state in DB
  7. Notify contractor

- `submitMilestoneClaim(projectId, milestoneIndex, userId, evidenceFiles)`:
  1. Upload evidence files to IPFS
  2. Create evidence metadata JSON → upload → get `ipfsEvidence`
  3. Call `ProjectContract.submitMilestoneCompletion()` on-chain
  4. Update Milestone.state = UNDER_REVIEW in DB
  5. Notify relevant signatories or open member vote

- `signMilestone(projectId, milestoneIndex, userId)`:
  1. Check user is council member
  2. Check milestone is UNDER_REVIEW and is COUNCIL_ONLY or COUNCIL_MEMBER_QUORUM type
  3. Check user hasn't signed already (MilestoneSignature record)
  4. Call `ProjectContract.signMilestone()` on-chain
  5. Create MilestoneSignature record in DB

---

### Step 9 — Bounty Service & Controller

**`src/services/bounty/BountyService.ts`** — TODO: Create.

Simpler than ProjectService. Main difference: no community governance, creator controls the flow.

- `createBounty(data, creatorId, files)`: Upload to IPFS, deploy BountyContract via factory, create DB record
- `submitBid(bountyId, contractorId, bidData)`: Record bid in DB + on-chain
- `selectBid(bountyId, contractorAddress, creatorId)`: On-chain selectBid(), update DB
- `approveMilestone(bountyId, milestoneIndex, userId)`: On-chain approveMilestone(), update DB

---

### Step 10 — NFT Metadata Endpoint

**`src/routes/nft.ts`** → `GET /:tokenId/metadata`

This is called by `PlatformNFTRegistry.tokenURI()`. Must return ERC-721 compatible JSON:

```json
{
  "name": "The Working App Identity — alice_handle",
  "description": "Soulbound platform identity for The Working App",
  "image": "https://api.theworkingapp.io/v1/nft/1/image",
  "attributes": [
    { "trait_type": "KYC Verified", "value": "true" },
    { "trait_type": "Communities", "value": 3 },
    { "trait_type": "Projects Completed", "value": 7 },
    { "trait_type": "Reputation Score", "value": 8750 },
    { "trait_type": "Dispute Count", "value": 0 }
  ]
}
```

Assemble this from `BlockchainService.getNFTData(tokenId)` combined with DB data.

---

### Step 11 — Notification Service

**`src/services/notifications/NotificationService.ts`** — TODO: Create.

Use SendGrid for email notifications. Trigger points:
- New proposal published → all community members
- Council review triggered → council members
- Project awarded → winning and losing contractors
- Milestone claim submitted → relevant signatories
- Milestone paid → contractor
- Completion vote opened → all community members
- Dispute raised → both parties + platform team
- Mediation ruling issued → both parties

Use Socket.IO for in-app real-time notifications.
Use Redis pub/sub as the transport layer between event listener and notification service.

---

### Step 12 — Tests

**`src/tests/`** — TODO: Create.

Use Jest + Supertest for integration tests.

Key test files:
- `auth.test.ts` — Registration, login, JWT validation
- `community.test.ts` — Create, join, governance updates
- `project.test.ts` — Full lifecycle from proposal to completion
- `bounty.test.ts` — Create, bid, select, complete
- `escrow.test.ts` — On-ramp webhook, balance queries

Use a test database (separate `DATABASE_URL` in `.env.test`).
Mock `BlockchainService` in unit tests — don't call live contracts in backend tests.

---

## Service Dependencies Map

```
AuthController
  └── AuthService → BlockchainService (mintNFT), Prisma, Redis, NotificationService

CommunityController
  └── CommunityService → BlockchainService (deployCommunity), Prisma, NotificationService

ProjectController
  └── ProjectService → BlockchainService (deployProject, castVote, award, milestones)
                     → IPFSService (proposal, evidence)
                     → Prisma
                     → NotificationService

BountyController
  └── BountyService → BlockchainService (deployBounty, milestones)
                    → IPFSService
                    → Prisma

EscrowController
  └── EscrowService → OnRampService (checkout URL, webhook)
                    → BlockchainService (fundEscrow)
                    → Prisma

EventListener (background)
  └── BlockchainService (read events)
  └── Prisma (update DB state)
  └── Socket.IO (real-time push)
  └── NotificationService (emails)
```
