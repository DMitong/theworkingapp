import crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';
import { AppError } from '../../utils/AppError';

/**
 * OnRampService
 *
 * Handles fiat-to-stablecoin on-ramp via Onramper (primary) and Transak (fallback).
 * Also handles stablecoin-to-fiat off-ramp for contractor payouts.
 */
export class OnRampService {
  /**
   * Create an Onramper checkout session for funding an escrow.
   * Returns the checkout URL to embed in the frontend.
   *
   * @param params.destinationWallet - The ProjectContract address (escrow recipient)
   * @param params.amountUsd - The amount to fund in USD
   * @param params.token - 'USDT' or 'USDC'
   * @param params.chainId - Target chain ID for the stablecoin
   */
  static async createFundingSession(params: {
    destinationWallet: string;
    amountUsd: number;
    token: 'USDT' | 'USDC';
    chainId: number;
    projectId: string;
  }): Promise<{ checkoutUrl: string; sessionId: string }> {
    logger.info(`Creating on-ramp session for project ${params.projectId}`);

    const sessionId = uuidv4();

    // Onramper widget URL parameters
    // Docs: https://docs.onramper.com/docs/create-widget-url
    const queryParams = new URLSearchParams({
      apiKey: env.ONRAMPER_API_KEY || 'pk_test_x', // Fallback for dev if not set
      defaultCrypto: params.token,
      defaultFiat: 'USD',
      defaultAmount: params.amountUsd.toString(),
      wallets: `${params.token}:${params.destinationWallet}`,
      onlyCryptos: params.token,
      isAddressEditable: 'false',
      partnerContext: JSON.stringify({
        projectId: params.projectId,
        sessionId: sessionId,
      }),
    });

    const checkoutUrl = `https://buy.onramper.com?${queryParams.toString()}`;

    return { checkoutUrl, sessionId };
  }

  /**
   * Verify and process an on-ramp webhook from Onramper.
   * Called by POST /api/v1/escrow/fund/confirm
   */
  static async processOnRampWebhook(body: any, signature: string): Promise<{
    projectId: string;
    amountUsdc: bigint;
    txHash: string;
  }> {
    // 1. Verify signature
    // Onramper uses HMAC-SHA256 with API key as secret
    const expectedSignature = crypto
      .createHmac('sha256', env.ONRAMPER_API_KEY || '')
      .update(JSON.stringify(body))
      .digest('hex');

    if (!crypto.timingSafeEqual(Buffer.from(expectedSignature), Buffer.from(signature))) {
      logger.warn('Invalid Onramper webhook signature');
      throw new AppError('Invalid webhook signature', 401);
    }

    // 2. Parse payload
    // Note: Actual Onramper payload structure may vary, this is a generalized implementation
    const { transaction, partnerContext } = body;

    if (!transaction || transaction.status !== 'completed') {
      logger.info('On-ramp transaction not yet completed', { status: transaction?.status });
      throw new AppError('Transaction not completed', 400);
    }

    const context = typeof partnerContext === 'string' ? JSON.parse(partnerContext) : partnerContext;
    const projectId = context?.projectId;

    if (!projectId) {
      throw new AppError('Project ID missing from webhook context', 400);
    }

    // Convert amount to BigInt (assuming USDC/USDT 6 decimals)
    // Onramper usually provides amount in units (e.g. 100.50)
    const amountUsdc = BigInt(Math.round(transaction.amount * 1_000_000));

    return {
      projectId,
      amountUsdc,
      txHash: transaction.txHash || '',
    };
  }

  /**
   * Create an off-ramp session for a contractor to withdraw stablecoin earnings.
   */
  static async createWithdrawalSession(params: {
    contractorWallet: string;
    amountUsdc: bigint;
    token: 'USDT' | 'USDC';
  }): Promise<{ checkoutUrl: string }> {
    logger.info(`Creating off-ramp session for wallet ${params.contractorWallet}`);

    // Transak Off-ramp widget URL
    // Docs: https://docs.transak.com/docs/offramp
    const queryParams = new URLSearchParams({
      apiKey: env.TRANSAK_API_KEY || 'test-key',
      environment: env.TRANSAK_ENV,
      cryptoCurrency: params.token,
      walletAddress: params.contractorWallet,
      defaultCryptoAmount: (Number(params.amountUsdc) / 1_000_000).toString(),
      isReadOnly: 'true',
      productsAllowed: 'SELL',
    });

    const checkoutUrl = `https://global.transak.com?${queryParams.toString()}`;

    return { checkoutUrl };
  }
}
