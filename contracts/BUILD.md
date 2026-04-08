# Contracts — Build Guide

This directory contains all Solidity smart contracts for The Working App, managed with **Foundry**.

---

## Setup

```bash
# Install Foundry if not already installed
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable

# Compile
forge build

# Run tests
forge test -vvv

# Format
forge fmt
```

---

## Contract Build Order

Build and fully test each contract before moving to the next. Each depends on the one above it.

### Step 1 — `src/interfaces/` — Define all interfaces first

Write the interfaces before any implementation. This locks the API surface and lets backend/frontend type generation happen in parallel.

**`IDataTypes.sol`**
- Central file for all shared structs and enums used across contracts.
- Define: `ProjectState`, `MilestoneVerificationType`, `VoteOutcome`, `VisibilityMode`, `MemberRole`, `ReputationUpdate`, `MilestoneDefinition`, `BidData`, `CouncilConfig`, `GovernanceParams`.
- No logic — structs and enums only.

**`IPlatformNFTRegistry.sol`**
- `mint(address user, string calldata handle) external returns (uint256 tokenId)`
- `setKYCHash(uint256 tokenId, bytes32 hash) external`
- `addCommunityMembership(uint256 tokenId, address community, uint8 role) external`
- `updateReputation(uint256 tokenId, ReputationUpdate calldata update) external`
- `isVerified(uint256 tokenId) external view returns (bool)`
- `isMember(uint256 tokenId, address community) external view returns (bool)`
- `getMemberships(uint256 tokenId) external view returns (address[] memory)`

**`ICommunityRegistry.sol`**
- `registerMember(address user) external`
- `approveMember(address user) external`
- `removeMember(address user) external`
- `deployProject(bytes calldata projectParams) external returns (address projectContract)`
- `isMember(address user) external view returns (bool)`
- `getProjectIndex() external view returns (address[] memory)`
- `getGovernanceParams() external view returns (GovernanceParams memory)`

**`IProjectContract.sol`**
- All project lifecycle functions (see PRD Section 8.4 for full list).
- `submitProposal(...)`, `castProposalVote(bool)`, `councilDecision(uint8, string)`, `submitBid(...)`, `awardContract(...)`, `acceptAward()`, `fundEscrow(uint256, address)`, `requestPortionGrant(...)`, `approvePortionGrant()`, `submitMilestoneCompletion(uint8, string)`, `signMilestone(uint8)`, `castMilestoneVote(uint8, uint8)`, `raiseDispute(string)`, `executeMediationRuling(...)`, `castCompletionVote(uint8)`

**`IBountyContract.sol`**
- `createBounty(...)`, `submitBid(...)`, `selectBid(address)`, `fundEscrow(...)`, `submitMilestoneCompletion(uint8, string)`, `approveMilestone(uint8)`, `raiseDispute(string)`, `executeMediationRuling(...)`

---

### Step 2 — `src/libraries/`

**`Escrow.sol`**
- Internal library for all escrow operations. Imported by ProjectContract and BountyContract.
- Functions: `deposit(...)`, `releaseMilestone(address recipient, uint256 amount, address token)`, `freeze()`, `unfreeze()`, `releaseAll(address recipient, address token)`, `refundAll(address funder, address token)`, `getMilestoneBalance(uint8 milestoneIndex)`
- Handles USDT/USDC ERC-20 transfers. Use `SafeERC20` from OpenZeppelin.
- Tracks: total escrowed, per-milestone allocations, amount released, amount held in dispute.

**`Voting.sol`**
- Internal library for vote counting and threshold logic.
- Functions: `castVote(mapping votes, address voter, uint8 choice)`, `getResult(mapping votes, uint256 totalEligible, uint8 threshold)`, `hasVoted(mapping votes, address voter)`, `getVoteCounts(...)`
- Supports yes/no votes (proposal), multi-choice votes (completion), and multi-sig threshold checks (milestone sign-off).

**`MilestoneManager.sol`**
- Internal library for milestone state tracking.
- Manages the array of MilestoneDefinition structs.
- Functions: `initializeMilestones(...)`, `claimMilestone(uint8 index)`, `signMilestone(uint8 index, address signer)`, `completeMilestone(uint8 index)`, `rejectMilestone(uint8 index)`, `getRemainingEscrow()`, `isAllMilestonesPaid()`
- Enforces that milestones are claimed sequentially (can't claim milestone 3 before 2 is paid).

---

### Step 3 — `src/PlatformNFTRegistry.sol`

Soulbound (non-transferable) ERC-721 contract.

**Key implementation notes:**
- Inherit from OpenZeppelin `ERC721`, override `transferFrom`, `safeTransferFrom`, and `approve` to always revert with `"Soulbound: non-transferable"`.
- Use OpenZeppelin `Ownable` — owner is the PlatformFactory (later upgradeable to company multisig).
- `tokenURI` returns a base64-encoded JSON pointing to off-chain metadata server for dynamic attributes. On-chain: store only `platformHandle`, `kycHash`, `communityCount`, `reputationScore`.
- Emit events on every state change: `NFTMinted`, `KYCHashSet`, `MembershipAdded`, `ReputationUpdated`.
- Access control: Only PlatformFactory can mint. Only registered CommunityRegistry contracts can call `addCommunityMembership`. Only registered Project/Bounty contracts can call `updateReputation`.
- Store a mapping of `address => uint256 tokenId` for reverse lookup (wallet to token ID).

---

### Step 4 — `src/PlatformFactory.sol`

The root contract. Deployed once per chain.

**Key implementation notes:**
- `Ownable` — owner is the company multisig.
- Maintains: array of deployed CommunityRegistry addresses, array of deployed BountyContract addresses.
- `deployCommunit(CouncilConfig calldata config, GovernanceParams calldata params) external returns (address)` — deploys a new CommunityRegistry using `new CommunityRegistry{salt: keccak256(...)}(...)`. Use CREATE2 for deterministic addresses.
- `deployBounty(BountyParams calldata params) external returns (address)` — deploys a new BountyContract.
- `registerNFTRegistry(address registry) external onlyOwner` — stores PlatformNFTRegistry address, used by child contracts for NFT callbacks.
- `setMediationKey(address key) external onlyOwner` — the platform's mediation signing address.
- `pause() / unpause()` — emergency pause propagated to all child contracts via interface call (or use a global pause registry).
- Emit: `CommunityDeployed`, `BountyDeployed`.

---

### Step 5 — `src/CommunityRegistry.sol`

One deployed per community.

**Key implementation notes:**
- Initialized via constructor (not upgradeable proxy in v1 — keep it simple).
- Store: `CouncilConfig` (signers array, threshold), `GovernanceParams` (proposal threshold, award tiers, voting windows, min members, membership verification mode).
- Multisig pattern for council actions: functions requiring council approval collect signatures off-chain and verify with `ECDSA.recover` (or use a simple nonce + hash approach). Alternative: require sequential `approve()` calls from council members with threshold check — simpler and more auditable.
- `registerMember`: behaviour depends on `verificationMode`. For Open/InviteCode/DomainEmail: council pre-approves off-chain, backend calls `approveMember`. For ZKKYCRequired: check `IPlatformNFTRegistry.isVerified` on-chain before adding.
- `deployProject`: only callable by council (after multisig). Deploys new ProjectContract via `new ProjectContract(...)`. Records in `projectIndex`.
- Emit: `MemberRegistered`, `MemberRemoved`, `ProjectDeployed`, `GovernanceUpdated`.

---

### Step 6 — `src/ProjectContract.sol`

The most complex contract. One per community project.

**Key implementation notes:**
- Constructor receives: `communityRegistry` address, `platformFactory` address, `proposalData` (IPFS hash), `milestones` array (can be set at deploy or at award — use a two-phase init), `escrowToken` (USDT or USDC address), `councilConfig` (copied from community at deploy time — snapshot, not live reference).
- Implement the full state machine. Use a `ProjectState public state` variable. Every state-changing function has a `requireState(ProjectState.X)` modifier.
- Voting maps: `mapping(address => uint8) proposalVotes`, `mapping(address => uint8) completionVotes`, `mapping(uint8 => mapping(address => bool)) milestoneSignatures`.
- Milestone array: `MilestoneDefinition[] public milestones`. Each milestone has: `name`, `description`, `ipfsEvidence`, `valueWei`, `verificationRequired` (enum), `signaturesReceived`, `state` (Pending/UnderReview/Paid/Rejected).
- Escrow: use the `Escrow` library. `fundEscrow` calls `IERC20(escrowToken).transferFrom(msg.sender, address(this), amount)`. Validate amount matches sum of milestone values.
- Portion grant: `portionGrantRequested`, `portionGrantAmount`, `portionGrantApproved`. Deduct from first milestone balance on approval.
- `executeMediationRuling`: only callable by `platformFactory.mediationKey()`. Emits `MediationRulingExecuted`. Transfers escrow per ruling.
- Gas consideration: avoid loops over unbounded arrays for vote counting. Use running counters.
- Emit events on every state transition — the backend's event listener drives dashboard updates.

---

### Step 7 — `src/BountyContract.sol`

Simpler version of ProjectContract for individual bounties.

**Key implementation notes:**
- Constructor: `creator`, `platformFactory`, `bountyData` (IPFS hash), `visibilityMode`, `targetCommunities[]`, `milestones[]`, `escrowToken`.
- Visibility enforcement is off-chain (API layer) — on-chain stores the visibility config for auditability, but access control on viewing bids is not enforced on-chain.
- Final milestone approval: `creator` sign-off + optional `completionPanel[]` (array of platform-selected addresses). Configurable at creation.
- Rest of lifecycle mirrors ProjectContract (fund, claim, approve, dispute, ruling).

---

### Step 8 — `test/`

**`test/PlatformNFTRegistry.t.sol`**
- Test: mint, soulbound (transfer reverts), KYC hash set/get, membership add, reputation update, access control (only factory can mint, only community can add membership).

**`test/PlatformFactory.t.sol`**
- Test: deploy community, deploy bounty, mediation key setting, pause/unpause.

**`test/CommunityRegistry.t.sol`**
- Test: member registration for each verification mode, council multisig threshold, project deployment, governance param updates.

**`test/ProjectContract.t.sol`** — most extensive test file
- Test full happy path: propose → vote → council approve → tender → bid → award → escrow fund → milestone claim → sign-off → completion vote → payout.
- Test each milestone verification type independently.
- Test portion grant: request → approve → deduction from first milestone.
- Test dispute: raise → mediation ruling (full release, partial, refund).
- Test edge cases: vote window expired, below-threshold votes, double-voting reverts, wrong-state function calls revert.
- Fuzz test: random vote counts, random milestone values (must sum to total), random portion grant amounts (must respect 30% cap).

**`test/BountyContract.t.sol`**
- Test happy path, dispute, visibility config storage.

**`test/integration/FullLifecycle.t.sol`**
- End-to-end test: deploy factory → deploy NFT registry → deploy community → register members → full project lifecycle from proposal to final payout.

---

### Step 9 — `script/`

**`script/Deploy.s.sol`**
- Deploys in order: PlatformNFTRegistry → PlatformFactory (with NFT registry address) → saves all addresses to `deployments/{chainId}.json`.
- Use `vm.broadcast()` with deployer private key from env.
- After deploy, call `factory.registerNFTRegistry(nftRegistry)` and `factory.setMediationKey(mediationKey)`.

**`script/DeployCommunity.s.sol`**
- Example script: deploy a test CommunityRegistry via factory with sample config.
- Reads factory address from `deployments/{chainId}.json`.

**`script/Upgrade.s.sol`** *(Phase 2 — if proxy pattern adopted)*
- Placeholder for upgrade scripts.

---

## Security Checklist (before audit submission)

- [ ] All external calls follow checks-effects-interactions pattern
- [ ] `SafeERC20` used for all ERC-20 transfers
- [ ] Reentrancy guards on all escrow-releasing functions
- [ ] No unbounded loops in state-changing functions
- [ ] All roles (factory, council, mediation key) enforced with modifiers
- [ ] State machine: every function asserts correct state before executing
- [ ] Overflow protection (Solidity 0.8.x built-in, but verify arithmetic)
- [ ] Emergency pause tested
- [ ] Events emitted for every state change
- [ ] Fuzz tests pass at 10,000 runs
- [ ] Invariant tests: escrow balance always >= sum of unpaid milestones
