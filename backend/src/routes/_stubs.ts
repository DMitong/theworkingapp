import { Router } from 'express';
import { authenticate } from '../middleware/auth';

// ── Communities ───────────────────────────────────────────────
export const communityRouter = Router();

communityRouter.get('/search', communityRouter.use(authenticate as any), (_req, res) => res.json({ TODO: 'search communities' }));
communityRouter.post('/', authenticate, (_req, res) => res.json({ TODO: 'create community — see CommunityController' }));
communityRouter.get('/:id', (_req, res) => res.json({ TODO: 'get community public profile' }));
communityRouter.get('/:id/members', authenticate, (_req, res) => res.json({ TODO: 'list members (council only)' }));
communityRouter.get('/:id/projects', (_req, res) => res.json({ TODO: 'list community projects' }));
communityRouter.post('/:id/membership/apply', authenticate, (_req, res) => res.json({ TODO: 'apply for membership' }));
communityRouter.put('/:id/membership/:userId', authenticate, (_req, res) => res.json({ TODO: 'approve/reject membership (council)' }));
communityRouter.put('/:id/governance', authenticate, (_req, res) => res.json({ TODO: 'update governance params (council multisig)' }));

// ── Projects ──────────────────────────────────────────────────
export const projectRouter = Router();

projectRouter.post('/communities/:communityId/projects', authenticate, (_req, res) => res.json({ TODO: 'submit project proposal' }));
projectRouter.get('/:id', (_req, res) => res.json({ TODO: 'get project detail with milestones' }));
projectRouter.post('/:id/vote/proposal', authenticate, (_req, res) => res.json({ TODO: 'cast proposal vote' }));
projectRouter.put('/:id/council-decision', authenticate, (_req, res) => res.json({ TODO: 'council decision on proposal' }));
projectRouter.put('/:id/publish', authenticate, (_req, res) => res.json({ TODO: 'publish tender with visibility' }));
projectRouter.post('/:id/bids', authenticate, (_req, res) => res.json({ TODO: 'submit bid' }));
projectRouter.get('/:id/bids', authenticate, (_req, res) => res.json({ TODO: 'list bids' }));
projectRouter.put('/:id/award', authenticate, (_req, res) => res.json({ TODO: 'award contract (council/vote)' }));
projectRouter.post('/:id/milestones/:n/claim', authenticate, (_req, res) => res.json({ TODO: 'submit milestone claim' }));
projectRouter.post('/:id/milestones/:n/sign', authenticate, (_req, res) => res.json({ TODO: 'sign milestone (council)' }));
projectRouter.post('/:id/milestones/:n/vote', authenticate, (_req, res) => res.json({ TODO: 'vote on milestone (member)' }));
projectRouter.post('/:id/vote/completion', authenticate, (_req, res) => res.json({ TODO: 'cast completion vote' }));
projectRouter.post('/:id/dispute', authenticate, (_req, res) => res.json({ TODO: 'raise dispute' }));
projectRouter.post('/:id/portion-grant/request', authenticate, (_req, res) => res.json({ TODO: 'request portion grant' }));
projectRouter.post('/:id/portion-grant/approve', authenticate, (_req, res) => res.json({ TODO: 'approve portion grant' }));
projectRouter.post('/:id/mediation/ruling', authenticate, (_req, res) => res.json({ TODO: 'submit mediation ruling (platform only)' }));

// ── Bounties ──────────────────────────────────────────────────
export const bountyRouter = Router();

bountyRouter.post('/', authenticate, (_req, res) => res.json({ TODO: 'create bounty — deploys BountyContract' }));
bountyRouter.get('/', authenticate, (_req, res) => res.json({ TODO: 'list bounties filtered by visibility/membership' }));
bountyRouter.get('/:id', authenticate, (_req, res) => res.json({ TODO: 'bounty detail' }));
bountyRouter.post('/:id/bids', authenticate, (_req, res) => res.json({ TODO: 'submit bid on bounty' }));
bountyRouter.put('/:id/select', authenticate, (_req, res) => res.json({ TODO: 'select winning bid' }));
bountyRouter.post('/:id/milestones/:n/claim', authenticate, (_req, res) => res.json({ TODO: 'milestone claim' }));
bountyRouter.post('/:id/milestones/:n/approve', authenticate, (_req, res) => res.json({ TODO: 'approve milestone' }));
bountyRouter.post('/:id/dispute', authenticate, (_req, res) => res.json({ TODO: 'raise dispute' }));

// ── Escrow ────────────────────────────────────────────────────
export const escrowRouter = Router();

escrowRouter.post('/fund/initiate', authenticate, (_req, res) => res.json({ TODO: 'initiate on-ramp session (Onramper)' }));
escrowRouter.post('/fund/confirm', (_req, res) => res.json({ TODO: 'on-ramp webhook — confirm escrow deposit' }));
escrowRouter.get('/:contractAddress/balance', authenticate, (_req, res) => res.json({ TODO: 'escrow balance + milestone allocations' }));
escrowRouter.post('/offramp/initiate', authenticate, (_req, res) => res.json({ TODO: 'initiate stablecoin → fiat off-ramp' }));

// ── Users ─────────────────────────────────────────────────────
export const userRouter = Router();

userRouter.get('/me', authenticate, (_req, res) => res.json({ TODO: 'current user profile + NFT data' }));
userRouter.put('/me/mode', authenticate, (_req, res) => res.json({ TODO: 'toggle standard/crypto-native mode' }));
userRouter.post('/me/wallet/connect', authenticate, (_req, res) => res.json({ TODO: 'connect external wallet (crypto-native mode)' }));
userRouter.post('/me/kyc/initiate', authenticate, (_req, res) => res.json({ TODO: 'return ZK-KYC provider session URL' }));
userRouter.get('/:handle/profile', (_req, res) => res.json({ TODO: 'public user profile + reputation' }));

// ── NFT metadata ──────────────────────────────────────────────
export const nftRouter = Router();

nftRouter.get('/:tokenId/metadata', (_req, res) => res.json({ TODO: 'dynamic NFT metadata JSON (called by tokenURI)' }));
