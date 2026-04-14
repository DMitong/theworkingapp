import request from 'supertest';
import app from '../../src/index';
import { prisma } from '../../src/models/prisma';
import { BlockchainService } from '../../src/services/blockchain/BlockchainService';

// Mock BlockchainService to avoid live contract calls during tests
jest.mock('../../src/services/blockchain/BlockchainService', () => ({
  BlockchainService: {
    init: jest.fn(),
    mintPlatformNFT: jest.fn().mockResolvedValue({ tokenId: 1, txHash: '0x123' }),
  },
}));

describe('Auth Integration Tests', () => {
  const testUser = {
    email: `test-${Date.now()}@example.com`,
    password: 'password123',
    handle: `tester-${Date.now()}`,
  };

  afterAll(async () => {
    // Cleanup test user
    await prisma.user.deleteMany({
      where: { email: { contains: 'example.com' } },
    });
    await prisma.$disconnect();
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user and return tokens', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send(testUser);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.user.email).toBe(testUser.email);
      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
    });

    it('should fail if email is already taken', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send(testUser);

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    it('should login and return new tokens', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: testUser.email,
          password: testUser.password,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('accessToken');
    });

    it('should fail with invalid credentials', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: testUser.email,
          password: 'wrongpassword',
        });

      expect(res.status).toBe(401);
    });
  });
});
