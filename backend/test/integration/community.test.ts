import request from 'supertest';
import app from '../../src/index';
import { prisma } from '../../src/models/prisma';

// Mock BlockchainService to avoid live contract calls during tests
jest.mock('../../src/services/blockchain/BlockchainService', () => ({
  BlockchainService: {
    init: jest.fn(),
    deployCommunity: jest.fn().mockResolvedValue({ contractAddress: '0xabc', txHash: '0x789' }),
  },
}));

describe('Community Integration Tests', () => {
  let accessToken: string;

  beforeAll(async () => {
    // 1. Create a user and get token
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `comm-test-${Date.now()}@example.com`,
        password: 'password123',
        handle: `comm-tester-${Date.now()}`,
      });
    
    accessToken = res.body.data.accessToken;
  });

  afterAll(async () => {
    // 2. Cleanup
    await prisma.community.deleteMany({
      where: { name: { contains: 'Test Community' } },
    });
    await prisma.user.deleteMany({
      where: { email: { contains: 'example.com' } },
    });
    await prisma.$disconnect();
  });

  describe('POST /api/v1/communities', () => {
    it('should create a new community (pending on-chain deployment)', async () => {
      const communityData = {
        name: 'Test Community',
        type: 'RESIDENTIAL',
        description: 'A test community for integration tests',
        councilSigners: ['0x123'],
        councilThreshold: 1,
        governanceParams: {
          proposalApprovalThreshold: 6000,
          proposalVotingWindow: 604800,
          completionVoteWindow: 864000,
          bidWindow: 1209600,
          councilReviewWindow: 1209600,
          tier1Threshold: '1000000',
          tier2Threshold: '10000000',
          minMembers: 2,
          portionGrantMaxPercent: 30,
          verificationMode: 'OPEN'
        }
      };

      const res = await request(app)
        .post('/api/v1/communities')
        .set('Authorization', `Bearer ${accessToken}`)
        .send(communityData);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(communityData.name);
    });
  });

  describe('GET /api/v1/communities/search', () => {
    it('should return a list of communities', async () => {
      const res = await request(app)
        .get('/api/v1/communities/search')
        .query({ q: 'Test' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data.data)).toBe(true);
    });
  });
});
