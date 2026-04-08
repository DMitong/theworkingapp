# Frontend — Build Guide

React 18 + TypeScript + Vite + Tailwind CSS + React Query + Wagmi.
Mobile-first. Every primary flow designed for 375px viewport.

---

## Setup

```bash
cd frontend
npm install
cp .env.example .env   # Fill in API URL, WalletConnect project ID
npm run dev            # Start dev server at http://localhost:3000
```

---

## Design Principles (Non-negotiable)

1. **Blockchain invisibility in Standard Mode.** Never show wallet addresses, chain names, gas fees,
   NFT terminology, or transaction hashes to Standard Mode users. Use plain language:
   - "wallet" → "account"
   - "NFT" → "membership card" or "profile"
   - "transaction" → "action" or "update"
   - "gas fee" → never show it (platform absorbs)
   - "on-chain" → never show it

2. **Mobile-first.** Build every screen at 375px first. Desktop layout is an enhancement.

3. **48px minimum touch targets.** All buttons, links, and interactive elements must be at least 48px tall.

4. **Optimistic UI for votes.** Proposal votes, milestone votes, and completion votes should
   update the UI instantly (before server response). React Query's `onMutate` handles this.
   See `useProjectDetail` and `useCastProposalVoteMutation` in `src/hooks/index.ts`.

5. **Real-time where it matters.** Vote counts and project state changes should update
   without a page refresh via Socket.IO. See `useProjectDetail` for the pattern.

---

## Build Order

### Step 1 — Auth Pages

**`src/pages/LoginPage.tsx`**
- Email + password form
- "Don't have an account? Register" link
- Submit calls `useAuth().login()`
- On success: navigate to /dashboard
- Error: show inline error message (not a toast)
- Loading state on button while request in flight

**`src/pages/RegisterPage.tsx`**
- Email, handle (@username), password, confirm password fields
- Handle field: real-time availability check (debounced GET /api/v1/users/check-handle?handle=xxx)
- Submit calls `useAuth().register()`
- On success: navigate to /dashboard
- Show "Your membership card is being set up…" message (NFT minting in background)

---

### Step 2 — AppShell & Navigation

**`src/components/common/AppShell.tsx`** — Stubbed. Complete it:
- Replace unicode icon placeholders with Heroicons SVGs
- Add notification badge (red dot) on profile avatar
- Desktop: switch bottom nav to left sidebar at md breakpoint
- Add "⛓ On-chain" mode badge in header for Crypto-Native users

---

### Step 3 — Dashboard

**`src/pages/DashboardPage.tsx`** — See detailed BUILD GUIDE in the file.

Data requirements:
- User's communities (GET /api/v1/users/me/memberships)
- Active projects in those communities (per community, filtered by state)
- Open proposal votes (state=PROPOSED or COUNCIL_REVIEW)

Socket.IO:
- Join rooms for each community on mount
- Update vote counts + project states in real time

---

### Step 4 — Community Pages

**`src/pages/DiscoverPage.tsx`**
- Search bar → calls `useSearchCommunities(query)` with 300ms debounce
- Community cards: name, type badge, member count, project count, "View" button
- Filter by type (chips: All, Residential, Professional, Alumni, etc.)
- "Create a community" CTA at top for logged-in users

**`src/pages/CommunityPage.tsx`** — Most complex page.
Tabs: Overview | Projects | Members | Governance (council only)

Overview tab:
- Community stats (total members, active projects, total value completed)
- Recent activity feed
- "Apply to join" CTA (if not a member) / "You're a member" badge

Projects tab:
- Filter by state (chips)
- Each project card: title, state badge, milestone bar, upvote count
- "Submit proposal" FAB (floating action button) at bottom right

Members tab (council only):
- Member list with role badges, join date, KYC status indicator
- Approve/reject pending applications

Governance tab (council only):
- Current governance params (thresholds, windows, tier amounts)
- Edit form (requires council multisig — collect signatures from other council members)

**`src/pages/NewCommunityPage.tsx`**
Multi-step form:
1. Community details (name, type, description, scope)
2. Council setup (add council member addresses/handles, set threshold)
3. Governance config (thresholds, voting windows, award tiers)
4. Membership verification mode selection
5. Review + deploy (shows gas estimate for Crypto-Native users, hidden for Standard)

---

### Step 5 — Project Detail Page

**`src/pages/ProjectDetailPage.tsx`** — Second most complex page.

Uses `useProjectDetail(projectId)` — already handles real-time updates.

Sections (stack vertically on mobile):
1. Project header: title, community name, state badge, proposer, created date
2. Proposal description (from IPFS — fetch `project.ipfsProposalHash` via GET /api/v1/ipfs/:hash)
3. Vote tally (if state=PROPOSED): `<VoteTally>` + "Vote For / Vote Against" buttons
4. Council decision panel (if state=COUNCIL_REVIEW, user is council): Approve/Revise/Close buttons
5. Bids list (if state=TENDERING):
   - Each bid: contractor handle, amount, timeline, reputation card, "View full bid" link
   - Award button (council only, per tier logic)
6. Milestone tracker (if state=ACTIVE+): `<MilestoneTracker>` component — already built
7. Escrow funding panel (if state=AWARDED):
   - Shows total amount, milestone breakdown
   - "Fund Escrow" button → calls `useInitiateEscrowFunding()` → opens Onramper iframe
8. Completion vote (if state=COMPLETION_VOTE):
   - Evidence display
   - Vote options: Completed / Partially / Not satisfactory / Dispute
9. Dispute panel (if state=DISPUTED): timeline, evidence, ruling (if issued)

**Onramper iframe integration:**
```tsx
// After useInitiateEscrowFunding() returns { checkoutUrl }:
<iframe
  src={checkoutUrl}
  allow="accelerometer; autoplay; camera; gyroscope; payment"
  className="w-full h-[600px] rounded-card border-0"
/>
```

---

### Step 6 — New Project Page

**`src/pages/NewProjectPage.tsx`**
Multi-step form:
1. Project basics (title, description, scope, budget range, priority)
2. Milestones (add/remove milestone rows; each: name, description, amount, expected date, verification type)
   - Live validation: milestone amounts must sum to total budget
   - Visual: running total shown below milestone list
3. Visibility settings (which community/public exposure)
4. Required contractor documentation (checklist of required docs)
5. Review + submit (uploads to IPFS, then deploys ProjectContract)

Milestone form component (`src/components/project/MilestoneForm.tsx`):
- Dynamic list: Add/remove milestone rows
- Drag-to-reorder (react-beautiful-dnd or @dnd-kit/core)
- Verification type selector per milestone
- Amount input with running total validation
- Note: Final milestone is always "Full Community Vote" — enforce in UI

---

### Step 7 — Bounty Pages

**`src/pages/BountyListPage.tsx`**
- Filter tabs: All | My Communities | Targeted at Me | My Bounties
- Sort: Newest | Ending Soon | Highest Value
- Bounty card: title, amount, milestone count, deadline, visibility badge, bid count

**`src/pages/BountyDetailPage.tsx`**
- Similar to ProjectDetailPage but simpler (no community governance)
- Bid list + select bid (creator only)
- Milestone tracker (same component)
- Escrow funding + completion flow

**`src/pages/NewBountyPage.tsx`**
- Similar to NewProjectPage but without community governance fields
- Extra: visibility selector (target specific communities via search)
- Completion panel size selector (0 = creator only, 3 = 3 random platform members)

---

### Step 8 — Profile & Settings

**`src/pages/ProfilePage.tsx`** (public, accessible by handle)
- Avatar (initials based for MVP), handle, member since date
- KYC verified badge
- Reputation metrics (completion rate, community rating, dispute rate)
- Communities list
- Project history (completed, active, awarded)
- Standard Mode: no wallet address shown
- Crypto-Native Mode: wallet address shown + link to block explorer

**`src/pages/SettingsPage.tsx`**
Sections:
- Account (email, password change)
- Mode toggle (Standard ↔ Crypto-Native) with explanation of what changes
- Connected wallet (Crypto-Native: shows address + disconnect; Standard: hidden)
- KYC verification status + "Verify identity" CTA
- Notification preferences
- Danger zone (delete account — with 30-day grace period)

---

### Step 9 — EscrowFundingPanel Component

**`src/components/escrow/EscrowFundingPanel.tsx`**

This is a critical path component — the payment flow.

```
[Fund Escrow] button
    ↓ (calls useInitiateEscrowFunding)
Loading state while session is created
    ↓
Onramper iframe opens in a bottom sheet modal
    ↓
User pays with Mastercard / bank transfer
    ↓
Onramper sends webhook to backend
    ↓
Backend funds escrow on-chain
    ↓
Frontend polls GET /escrow/:address/balance every 10 seconds
    ↓
Once balance > 0: show "Escrow funded ✓" and project moves to ACTIVE
```

For Crypto-Native mode:
- Show "Connect wallet and pay directly" option
- Use wagmi's `useWriteContract` to call `fundEscrow()` directly

---

### Step 10 — Crypto-Native Mode Components

**`src/components/common/WalletConnect.tsx`**
- "Connect Wallet" button using wagmi's `useConnect()`
- Shows connected address (truncated) + ENS name if available
- "Disconnect" option
- Chain selector (only show supported chains: Base, Polygon)
- Show native ETH balance for gas awareness
- This component is only visible in Crypto-Native mode (behind mode check)

**`src/components/common/ModeToggle.tsx`**
- Toggle switch: Standard ↔ Crypto-Native
- Standard → Crypto-Native: prompt to connect external wallet
- Crypto-Native → Standard: confirm dialog ("Switch to simplified view?")
- Calls PUT /api/v1/users/me/mode on toggle

---

### Step 11 — Mediation Page (Platform Admin)

**`src/pages/MediationPage.tsx`**
- Only accessible to platform mediation team (check user role)
- Shows all dispute evidence from both parties
- Timeline of project events
- Ruling form: contractor amount, funder refund, rationale
- Submit calls POST /api/v1/projects/:id/mediation/ruling

---

## Component File List (Complete)

```
src/components/
├── common/
│   ├── AppShell.tsx           ← Stubbed — complete in Step 2
│   ├── index.tsx              ← Built: StateBadge, MilestoneBar, VoteTally, etc.
│   ├── WalletConnect.tsx      ← TODO: Step 10
│   └── ModeToggle.tsx         ← TODO: Step 10
├── community/
│   ├── CommunityCard.tsx      ← TODO: used in DiscoverPage
│   ├── MemberCard.tsx         ← TODO: used in CommunityPage Members tab
│   └── ProposalCard.tsx       ← TODO: used in DashboardPage + CommunityPage
├── project/
│   ├── MilestoneTracker.tsx   ← Built — wire up action callbacks
│   ├── MilestoneForm.tsx      ← TODO: Step 6 (new project/bounty forms)
│   ├── BidCard.tsx            ← TODO: used in ProjectDetailPage
│   └── ProjectCard.tsx        ← TODO: used in DashboardPage + CommunityPage
├── bounty/
│   └── BountyCard.tsx         ← TODO: used in BountyListPage
├── escrow/
│   └── EscrowFundingPanel.tsx ← TODO: Step 9
└── reputation/
    └── ReputationCard.tsx     ← TODO: used in BidCard + ProfilePage
```

---

## State Management

- **Server state:** React Query (all API data)
- **UI state:** Local `useState` in components (modals, form state, tab selection)
- **Global client state:** Zustand for user preferences that don't need to hit the server
  (e.g. dismissed banners, selected chain in Crypto-Native mode)
- **No Redux.** React Query + Zustand is sufficient for this application.

---

## Testing

Use Vitest (configured via Vite) + React Testing Library.

Key tests:
- `MilestoneTracker.test.tsx` — renders all milestone states, action buttons appear for correct roles
- `VoteTally.test.tsx` — percentage calculation, zero-vote edge case
- `AuthContext.test.tsx` — login, logout, token persistence
- `useProjectDetail.test.ts` — Socket.IO event handler updates cache correctly
