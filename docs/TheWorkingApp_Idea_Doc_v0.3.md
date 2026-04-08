# The Working App — Decentralized Community Project Protocol
### Product Idea Document v0.3

---

## 1. Vision

What started as a civic governance tool has revealed itself to be something larger: **a universal protocol for community-governed work**.

The core framing — civic responsibilities, HOAs, local governments — remains valid and is the strongest initial entry point. But the underlying mechanism (verified community membership + democratic project governance + enforceable delivery accountability) applies to any trust-based community that needs to coordinate work, allocate resources, or commission projects.

**The Working App is a decentralized protocol for communities to govern, fund, and verify real-world work — with participation tied to verified membership and accountability anchored on-chain.**

The "civic" in The Working App refers not to government specifically, but to the civic act of participating in a community's collective decisions. Every community — formal or informal, public or private — has civic life. The Working App infrastructures it.

The Working App is incorporated as a company and administered by that company. It is not a decentralized autonomous organization at the platform governance level. The communities that use it are democratically self-governed; the platform itself is company-governed. This distinction is important for legal clarity, accountability, and product direction.

---

## 2. What It Is (and What It Isn't)

**It is:**
- A community-governed project marketplace
- A transparent contracting and accountability layer
- A membership identity protocol (NFT-based, ZK-verified, single-chain)
- A targeted work discovery network (bounties exposed to specific communities)
- A permanent, auditable record of community activity
- A user-experience layer that makes blockchain participation accessible to non-crypto users

**It is not:**
- A traditional DAO (no central on-chain treasury, no governance token)
- A platform governed by token holders
- A crypto-speculative product (stablecoins only, utility-first)
- A government replacement (works *with* existing governance structures)
- A freelancing platform (community is always the unit of trust)

---

## 3. Core Actors

| Actor | Description |
|---|---|
| **Community Council** | Governing body of a registered community. Sets rules, screens bids, awards contracts, manages membership. |
| **Community Member** | Verified member of one or more communities. Can propose projects, vote, apply for project work, and post bounties. |
| **Contractor / Service Provider** | Any registered platform user who bids on or applies for projects and bounties. May also be a community member. |
| **Individual Bounty Poster** | Any registered user posting a personal project, with control over who can see and bid on it. |
| **The Working App Company** | Owns and administers the platform. Sets platform-wide policies, handles mediation, manages chain deployments, and makes all administrative decisions. |

---

## 4. User Experience Layer — Crypto-Native vs. Standard Mode

The Working App is built to serve two meaningfully different types of users without compromise for either. Every registered user has a **mode toggle** in their profile settings.

### Standard Mode (Default)
Designed for users who are not familiar with, or not interested in, the mechanics of blockchain. The experience feels like a modern civic app or project management platform. All blockchain activity is masked and abstracted:

- No wallet addresses shown in primary UI
- No chain names, gas fees, or transaction hashes surfaced during normal use
- Voting is as simple as tapping a button — the underlying on-chain transaction is handled invisibly by an embedded wallet (the platform manages a custodial or semi-custodial wallet on the user's behalf)
- Payments and escrow are handled through familiar fiat and card interfaces
- Profile is presented as a standard user profile — no NFT terminology unless the user seeks it out
- When a restriction applies (e.g., jurisdiction blocks crypto escrow), the user sees a plain-language message, not a blockchain error

### Crypto-Native Mode
For users who want full visibility and control over their on-chain activity:

- Full wallet connectivity (MetaMask, Phantom, WalletConnect, etc.)
- Chain selection visible — user can see and choose which deployment they are interacting with
- Transaction hashes displayed and linkable to block explorers
- NFT identity card visible with full on-chain metadata
- Gas fee estimates shown before actions
- Option to export or self-custody their platform NFT

### Mode Transition
Switching from Standard to Crypto-Native mode prompts the user to connect an external wallet. Their profile data and history migrate to the connected wallet. Switching back to Standard re-enables the platform-managed embedded wallet. The underlying on-chain records are the same regardless of mode — only the interface changes.

This design decision is critical: **the blockchain is the infrastructure, not the product.** The product is community governance and project accountability. The blockchain just makes it trustworthy.

---

## 5. Identity Layer — The Platform Membership NFT

Every registered user is issued a **dynamic, non-transferable (soulbound) NFT** — their platform identity card. This NFT is the single credential that gates all participation on the platform.

### Single-Chain Deployment
The platform NFT lives on one canonical chain chosen by The Working App at launch. Multi-chain capability on the platform refers to the *smart contracts for projects and communities*, not the identity NFT. The NFT chain is selected for low transaction costs, stability, and EVM compatibility. Cross-chain NFT portability may be explored with chain-specific investment partnerships in future, but is not in scope for the initial build.

### Structure

```
PlatformNFT (Soulbound Token — non-transferable)
{
  walletAddress
  platformID (unique handle)
  zkKYCHash (hash of verified identity — PII never stored on-chain)
  membershipList: [ { communityID, joinDate, role, status } ]
  reputationScore
  projectsCompleted
  projectsAwarded
  votesParticipated
  disputeHistory
  joinedDate
  mode: standard | crypto-native
}
```

### ZK-KYC Integration
When a user undergoes identity verification through a ZK-KYC provider, a cryptographic hash of their verified identity is stored on-chain and attached to their NFT:

- The platform confirms the user is a real, unique, verified person
- No personally identifiable information is stored on-chain or by the platform
- Communities requiring verified membership check for the presence of a valid ZK-KYC hash, without knowing who the user is
- Prevents Sybil attacks — one verified person, one NFT, forever

### What Updates the NFT
- Joining a community (membership list updated)
- Completing a project (completion record added)
- Casting a vote (governance participation updated)
- Receiving a contract award
- A dispute being recorded against them

In Standard Mode, users interact with all of this through a familiar profile screen. In Crypto-Native Mode, they can inspect the raw NFT metadata.

---

## 6. Community Types & Registration

The Working App imposes no restriction on community type. Any organised group may register.

### Example Community Types
- **Residential:** HOA, gated estate, apartment block
- **Civic:** City council, ward development association, local government area
- **Professional:** Civil engineers guild, architects association, bar council chapter
- **Alumni:** University alumni body, secondary school alumni association
- **Religious:** Parish council, mosque committee, synagogue board
- **Social:** Sports club, cultural association, diaspora group
- **Industry:** Trade association, cooperative, industry working group

### Community Registration Configuration

At registration, the council defines:

- Community name, type, and scope
- Council wallet addresses and multisig threshold
- **Minimum active members to proceed with projects:** council-defined; platform default is **2 members**
- Proposal approval threshold (% upvotes required to force council review)
- Award authority tiers (funding thresholds for direct award vs public vote)
- Completion vote window
- Membership verification mode

### Membership Verification Modes (Council's Choice)

Communities choose what proof is required to join. Modes can be combined:

| Mode | How It Works |
|---|---|
| **Open** | Anyone requests membership; council approves |
| **Invite Code** | Council generates codes distributed off-chain; user submits code |
| **Address Proof** | User submits physical/institutional address; council verifies off-chain, approves on-chain |
| **Domain Email** | User verifies via institutional email domain (e.g. @alumni.school.edu) |
| **ZK-KYC Required** | User must carry a verified ZK-KYC hash on their NFT |
| **Document Review** | User submits supporting documents; council reviews and approves |
| **NFT-Gated** | Membership auto-granted to holders of a specific external NFT |
| **Custom** | Community defines its own verification flow |

---

## 7. Bounty Visibility & Targeting — The Exposure System

When creating any project or bounty, the creator controls who can see it.

### Visibility Modes

**Community-Internal** — Visible only to members of the creator's own community.

**Platform-Public** — Visible to all registered platform users.

**Community-Targeted** — Creator selects one or more communities to expose the bounty to, even without being a member of those communities. The wider platform cannot see it.

> *A property developer wants foundation work done and knows the Civil Engineers Guild has verified members. They target the bounty exclusively at that community. No one else sees it. They get bids from verified professionals.*

**Dual Publicity** — Simultaneously visible to a targeted community and the general platform public.

**Multi-Community Targeted** — Exposed to multiple specific communities in parallel (e.g., civil engineers guild + quantity surveyors association for a large build).

### Why This Matters
Community membership becomes a commercial trust signal, not just a governance credential. Communities are incentivised to maintain rigorous membership standards because their members become preferentially discoverable by outside clients. The platform becomes more valuable as more specialised communities form and their membership becomes meaningful.

---

## 8. The Project Lifecycle (Community Track)

```
PROPOSAL → COMMUNITY VOTE → CONTRACTING ROUND → SCREENING & AWARD → EXECUTION → COMPLETION VOTE → ESCROW RELEASE
```

### Stage 1 — Proposal Submission
Any registered community member or council officer submits:
- Title, description, scope of work, deliverables
- Estimated budget range
- Priority classification (Infrastructure / Maintenance / Social / Security / etc.)
- Supporting documents, images, site references
- Proposed contractor requirements and documentation (any documentation the project creator deems necessary for bid assessment — this is fully flexible and set per project)

### Stage 2 — Community Vote (Proposal Approval)
- Proposal published to community dashboard
- Members vote within the configured window
- If approval threshold is met, the council is contractually obligated to formally review — the contract state machine blocks them from ignoring it
- Council options: Approve → Contracting | Request Revision → Back to proposal | Close → Archived on-chain with written reason

### Stage 3 — Contracting Round (Open Tender)
- Approved project published as a tender per its visibility settings
- Any eligible contractor may submit a bid within the bidding window
- Bid submission fields are partially standard (cost, timeline, credentials) and partially defined by the project creator (additional documentation, certifications, or other requirements set at proposal stage)
- All bids are publicly visible on-chain by default (communities may configure screening-phase bid privacy as a governance setting)

### Stage 4 — Screening & Award

Tiered by funding size, with thresholds set by each community at registration:

| Funding Range | Award Process |
|---|---|
| Below Tier 1 | Council awards directly |
| Tier 1 to Tier 2 | Council shortlists → community votes on final selection |
| Above Tier 2 | Full open community vote, extended window; optional external audit flag |

- Award and rejection decisions are both recorded on-chain with written rationale

### Stage 5 — Execution
- Project enters Active status on dashboard
- Contractor submits progress updates attached to contract record
- Council or designated community members may log milestone confirmations
- Contractor may request a Portion Grant (see Section 10)

### Stage 6 — Completion Vote
- Contractor submits completion declaration with evidence
- Community members vote within configured window
- Vote options: Completed as specified / Partially completed / Not satisfactory / Dispute

Payout logic:
- Majority approval → Full escrow released
- Majority partial → Partial release; remainder held pending remediation
- Dispute → Platform mediation triggered; escrow held

### Stage 7 — Escrow Release & Permanent Archive
- Payment released from escrow to contractor wallet on approval
- Full project record archived permanently on-chain
- Project appears in community's completed history, visible on public community profile

---

## 9. Individual Bounties (Open Track)

For personal projects that don't require community governance.

- Creator posts bounty: description, deliverables, budget, deadline, required documentation (if any), visibility setting
- Service providers submit bids (publicly or privately per visibility mode)
- Creator selects preferred bid; funds enter escrow
- On delivery, creator triggers completion vote — optionally with a small randomly-selected panel of platform-verified users for objectivity
- Escrow releases on vote approval
- Both parties rated; records update their platform NFTs

---

## 10. Portion Grant (Mobilisation Funding)

Contractors who need advance funding to commence work submit a Portion Grant Request:

- Amount requested, percentage of total contract value, and purpose breakdown
- Goes to community vote (or council decision for sub-threshold projects)
- If approved, amount released from escrow immediately
- Tracked as a deduction from final payout — not additional funds
- Remaining escrow balance updated on-chain

This prevents smaller contractors from being systematically excluded by working capital constraints.

---

## 11. Escrow Architecture

Escrow is mandatory on The Working App for all funded projects. This is a design principle, not a feature.

### Supported Currencies
- USDT (Tether) — primary
- USDC (USD Coin) — primary
- Additional stablecoins added by platform governance as needed

### Fiat On-Ramp (How Users Fund Escrow)

Users fund their escrow using familiar payment methods — no prior crypto knowledge required. The platform integrates fiat-to-stablecoin on-ramp providers:

**Recommended providers:**

| Provider | Why |
|---|---|
| **Transak** | Supports 130+ countries including many emerging markets; Mastercard, Visa, and bank transfer; clean SDK integration; reasonable fees |
| **MoonPay** | Widely used, strong compliance infrastructure, card payments, broad currency support |
| **Ramp Network** | Strong bank transfer support; good for markets where card crypto purchases face restrictions; solid developer tools |
| **Stripe Crypto Onramp** | If Stripe is already integrated for platform fees, their crypto ramp is seamless and developer-friendly; card-first |
| **Onramper** | An aggregator that routes through multiple providers to get best rates and availability by geography |

**Recommended approach:** Integrate Onramper as the primary on-ramp aggregator, with Transak and Ramp Network as direct fallbacks for markets where aggregator coverage is thin. This gives users a simple Mastercard/Visa deposit flow that works across the widest possible geography. The stablecoin arrives in escrow; the user sees a familiar payment screen.

### Off-Ramp
Contractor payouts from escrow similarly go through an off-ramp provider — converting stablecoin to local fiat and depositing to a bank account or mobile money wallet. The same providers (Transak, Ramp Network) offer off-ramp services.

### Availability
- Crypto escrow available only in jurisdictions where cryptocurrency is legally permitted
- In restricted jurisdictions: platform remains usable for governance, transparency, and record-keeping; payment is handled off-chain and the payment confirmation recorded manually on-chain

### Escrow Flow
```
Project Awarded
    ↓
Creator funds escrow via fiat on-ramp (Mastercard / bank transfer → USDT/USDC)
    ↓
Funds held in project smart contract escrow
    ↓
Optional: Portion Grant request → community vote → partial release to contractor
    ↓
Project execution
    ↓
Completion vote approved → remaining balance released from escrow
    ↓
Contractor receives stablecoin (or converts via off-ramp to local fiat)
    ↓
Dispute → funds held in mediation escrow until resolved
```

---

## 12. Dispute Resolution — Platform Mediation

When a completion vote results in a Dispute, the case enters platform mediation administered by The Working App.

### Process
1. **Case Filing** — Both parties submit their position and evidence through the platform
2. **Record Review** — Mediation team reviews all on-chain records: proposal, award terms, progress logs, completion declaration, vote breakdown, plus submitted evidence
3. **Ruling** — The Working App issues a binding ruling within 14 business days:
   - Full release to contractor
   - Partial release with defined split
   - Full refund to community/poster
   - Remediation required before release
4. **Execution** — Smart contract executes the ruling automatically via platform mediation key
5. **Appeal** — One appeal permitted per party within 7 days; final decision is binding
6. **On-chain record** — Every dispute, ruling, and outcome is permanently recorded

### Mediation Fee
A fixed mediation fee is charged when a dispute case is opened, shared between both parties or assigned to the losing party per ruling.

---

## 13. Multi-Chain Smart Contract Deployment

Multi-chain on The Working App refers to where **community and project contracts are deployed** — not the identity NFT (which lives on one canonical platform chain).

### Chain Support Strategy

The Working App maintains smart contract templates in both Solidity and Rust, supporting:

**Solidity / EVM-compatible chains:**
Ethereum, Polygon, Base, Arbitrum, Optimism, Avalanche C-Chain, BNB Chain, Gnosis Chain, and future EVM chains.

**Rust-compatible chains:**
Solana (Anchor framework), NEAR Protocol, Polkadot/ink!, and compatible chains.

### Who Chooses the Chain?
- The Working App deploys the platform NFT and factory contract on a **primary canonical chain** (Phase 1 recommendation: Base or Polygon — low gas, high EVM compatibility, stable ecosystem)
- Community councils choose which supported chain to deploy their Registration Pool Contract on at registration
- Project child contracts deploy on the same chain as their parent community
- Crypto-native users see chain details; standard-mode users do not

### Phase Approach
- **Phase 1:** Single-chain launch with Solidity contracts. Recommended: Base or Polygon
- **Phase 2:** Solana/Rust deployment. Communities can choose EVM or Solana at registration
- **Phase 3:** Additional chains added on demonstrated community demand; potential chain-specific investment partnerships for NFT bridging

---

## 14. Smart Contract Architecture

```
PlatformFactory (per chain)
│
├── PlatformNFTRegistry (canonical chain only)
│   └── MemberNFT { soulbound, dynamic metadata, ZK-KYC hash }
│
├── CommunityRegistry (per community, deployed on council's chosen chain)
│   ├── MembershipPool
│   │   └── MemberRecord { nftID, role, joinDate, verificationMode, status }
│   ├── CouncilConfig { signers, multisigThreshold, governanceParams, awardTiers }
│   ├── EscrowConfig { currency: USDT|USDC, onRampProvider }
│   ├── MinimumMemberThreshold (default: 2, council-configurable)
│   └── ProjectIndex [ projectContractAddresses ]
│
├── ProjectContract (per community project)
│   ├── ProposalData { description, scope, budgetRange, requiredDocs[], customRequirements[] }
│   ├── CommunityVoteRecord
│   ├── BiddingRound { bids[], bidDocuments[], awardedBid, rejectedBids[] }
│   ├── EscrowBalance
│   ├── PortionGrantRequests []
│   ├── ExecutionLog { milestones[], progressUpdates[] }
│   ├── CompletionVote { votes[], outcome }
│   ├── DisputeRecord (if triggered)
│   └── PaymentRecord
│
└── BountyContract (per individual bounty)
    ├── BountyDetails { visibility, targetCommunities[], requiredDocs[] }
    ├── BidSubmissions []
    ├── SelectionRecord
    ├── EscrowBalance
    ├── CompletionVote
    ├── DisputeRecord (if triggered)
    └── PaymentRecord
```

---

## 15. Community Dashboard

### Member View
- Active Projects — status, contractor, milestone progress, days remaining, open vote actions
- Completed Projects — full history with vote outcomes and payment confirmations
- Open Proposals — pending community vote with upvote/downvote
- Open Tenders — current bidding rounds with submitted bids
- Community Metrics — total value spent, projects completed, average delivery time, member participation rate
- My Activity — personal voting history, proposals submitted, projects applied for

### Council View (additional panels)
- Bid screening and shortlisting queue
- Pending award decisions
- Member registration approvals
- Dispute case status
- Governance settings management

### Public Community Profile (visible to all platform users)
- Community type, scope, and member count
- Completed project count and total value
- Active project count
- Average completion vote approval rate
- Top contractors by projects completed within this community

---

## 16. Contractor Reputation System

Every contractor's platform NFT carries a live reputation record visible across all communities:

| Attribute | Description |
|---|---|
| Completion Rate | % of awarded projects completed to community approval |
| Community Rating | Average score from completion votes across all projects |
| Dispute Rate | Disputes as % of total projects |
| Response Rate | Bids submitted on time and complete |
| Community Memberships | Which verified communities the contractor belongs to |
| ZK-KYC Status | Verified / Unverified |
| Specialisations | Self-declared, community-endorsed categories |

Communities can set minimum reputation thresholds for who may bid on their projects.

---

## 17. Governance Philosophy — Layered Democracy

| Decision | Authority |
|---|---|
| Should this project exist? | Community members (proposal vote) |
| Who should build it? | Council (small) / Council + Community (medium) / Community (large) |
| Should advance funding be released? | Community members (grant vote) |
| Was the work done properly? | Community members (completion vote) |
| How should a dispute be resolved? | The Working App platform mediation |
| Should community governance rules change? | Council (with optional member vote) |
| Should platform-wide policies change? | The Working App company |

The council retains operational authority. The community retains accountability authority. The platform holds the arbitration layer. No single party can fully override the others within their designated domain.

---

## 18. Platform Scope — More Than Civic Governance

The civic governance framing is the *origin* and the strongest market entry point, because it has the clearest pain points (corruption, opacity, disengagement) and the most defensible blockchain value proposition.

But what has been designed is a **community-governed work coordination protocol**. The mechanism works wherever a group of people share a trust context and need to commission or verify work.

| Layer | What It Is | Example |
|---|---|---|
| Civic Governance | Communities governing public works | HOA gate replacement, council drainage project |
| Community Contracting | Any group coordinating and commissioning work | Alumni hostel project, mosque renovation |
| Trust-Gated Marketplace | Individuals targeting verified professional communities | Developer posting bounty to civil engineers guild |
| Open Bounties | Individual personal project requests | Homeowner seeking fence construction bids |

Enter through the civic layer. Grow naturally into the others as community membership becomes a trusted signal across the platform.

---

## 19. Revenue Model

| Source | Model |
|---|---|
| Community Registration | One-time onboarding fee per community |
| Project Completion Fee | 1–2% of escrow value, charged on successful release |
| Bounty Fee | Flat fee or 1–2% for individual bounties |
| Dispute Mediation Fee | Fixed fee per dispute case opened |
| Premium Council Tools | Subscription: analytics, multi-community management, custom verification |
| Contractor Verified Badge | Paid credential verification and enhanced profile visibility |
| Community Featured Listing | Paid visibility in community discovery directory |

---

## 20. Future Considerations

- **USSD Voting Integration:** Deferred. The voting mechanism is designed so a vote can be submitted via any interface — the smart contract only cares that it came from an authenticated member, not how it was submitted. USSD relay can be built as a later layer without changing core contracts.
- **Cross-Chain NFT Portability:** Deferred pending chain-specific investment partnerships.
- **Platform Governance Evolution:** As the platform matures, The Working App may explore a council-of-councils governance model for platform-level decisions — community councils having advisory input into platform direction. This does not change the company-governed structure but creates a formal feedback channel.
- **Insurance Layer:** For large projects, an optional on-chain insurance or bonding mechanism for contractors could reduce platform mediation load and give communities more comfort on high-value awards.
- **Multi-Signature Milestone Escrow:** Release escrow in tranches tied to council-confirmed milestones rather than a single completion vote — a more granular payout structure for complex, long-running projects.

---

*Document version 0.3 — Incorporates founder clarifications on NFT chain strategy, minimum community size, platform governance structure, fiat on-ramp approach, and per-project contractor documentation flexibility. All open questions from v0.2 resolved.*
