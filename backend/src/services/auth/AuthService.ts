import { ethers } from 'ethers';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { prisma } from '../../models/prisma';
import { env } from '../../config/env';
import { AppError } from '../../utils/AppError';
import { BlockchainService } from '../blockchain/BlockchainService';
import { logger } from '../../utils/logger';

export interface AuthResponse {
  user: {
    id: string;
    email: string;
    handle: string;
    walletAddress: string;
    mode: string;
  };
  accessToken: string;
  refreshToken: string;
}

export class AuthService {
  private static readonly SALT_ROUNDS = 12;

  /**
   * Register a new user with an embedded wallet.
   */
  static async register(data: any): Promise<AuthResponse> {
    const { email, password, handle } = data;

    // 1. Check uniqueness
    const existing = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { handle }],
      },
    });

    if (existing) {
      throw new AppError('Email or handle already taken', 400);
    }

    // 2. Hash password
    const passwordHash = await bcrypt.hash(password, this.SALT_ROUNDS);

    // 3. Create embedded wallet
    // Note: In production, consider MPC providers like Privy or Dynamic.
    // For this build, we generate a random wallet and store the address.
    const wallet = ethers.Wallet.createRandom();
    const walletAddress = wallet.address;

    // 4. Create user in DB
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        handle,
        walletAddress,
        mode: 'STANDARD',
      },
    });

    // 5. Trigger NFT Minting (async - don't block registration)
    BlockchainService.mintPlatformNFT(walletAddress, handle)
      .then(async ({ tokenId }) => {
        await prisma.user.update({
          where: { id: user.id },
          data: { tokenId },
        });
        logger.info(`User ${user.id} NFT minted: tokenId=${tokenId}`);
      })
      .catch((err) => {
        logger.error(`Failed to mint NFT for user ${user.id}`, err);
      });

    // 6. Generate tokens
    const { accessToken, refreshToken } = this.generateTokens(user);

    return {
      user: {
        id: user.id,
        email: user.email,
        handle: user.handle,
        walletAddress: user.walletAddress,
        mode: user.mode,
      },
      accessToken,
      refreshToken,
    };
  }

  /**
   * Authenticate a user and return tokens.
   */
  static async login(data: any): Promise<AuthResponse> {
    const { email, password } = data;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new AppError('Invalid credentials', 401);
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      throw new AppError('Invalid credentials', 401);
    }

    const { accessToken, refreshToken } = this.generateTokens(user);

    return {
      user: {
        id: user.id,
        email: user.email,
        handle: user.handle,
        walletAddress: user.walletAddress,
        mode: user.mode,
      },
      accessToken,
      refreshToken,
    };
  }

  /**
   * Refresh access token using a valid refresh token.
   */
  static async refresh(token: string): Promise<{ accessToken: string; refreshToken: string }> {
    try {
      const payload = jwt.verify(token, env.REFRESH_TOKEN_SECRET) as any;
      const user = await prisma.user.findUnique({ where: { id: payload.sub } });

      if (!user) {
        throw new AppError('User not found', 401);
      }

      return this.generateTokens(user);
    } catch (err) {
      throw new AppError('Invalid refresh token', 401);
    }
  }

  /**
   * Generate JWT access and refresh tokens.
   */
  private static generateTokens(user: any) {
    const accessToken = jwt.sign(
      {
        sub: user.id,
        wallet: user.walletAddress,
        handle: user.handle,
        mode: user.mode,
      },
      env.JWT_SECRET,
      { expiresIn: env.JWT_EXPIRES_IN }
    );

    const refreshToken = jwt.sign(
      { sub: user.id },
      env.REFRESH_TOKEN_SECRET,
      { expiresIn: '30d' }
    );

    return { accessToken, refreshToken };
  }
}
