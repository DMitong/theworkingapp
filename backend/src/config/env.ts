import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),
  API_VERSION: z.string().default('v1'),

  DATABASE_URL: z.string(),
  REDIS_URL: z.string().default('redis://localhost:6379'),

  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('7d'),
  REFRESH_TOKEN_SECRET: z.string().min(32),

  PRIMARY_CHAIN_ID: z.coerce.number().default(8453),
  PRIMARY_RPC_URL: z.string().url(),
  TESTNET_CHAIN_ID: z.coerce.number().optional(),
  TESTNET_RPC_URL: z.string().url().optional(),

  PLATFORM_PRIVATE_KEY: z.string(),
  PLATFORM_WALLET_ADDRESS: z.string(),
  MEDIATION_KEY_ADDRESS: z.string(),

  PLATFORM_FACTORY_ADDRESS: z.string().optional(),
  PLATFORM_NFT_REGISTRY_ADDRESS: z.string().optional(),

  PINATA_API_KEY: z.string(),
  PINATA_SECRET_API_KEY: z.string(),
  PINATA_GATEWAY: z.string().url().default('https://gateway.pinata.cloud'),

  ONRAMPER_API_KEY: z.string().optional(),
  TRANSAK_API_KEY: z.string().optional(),
  TRANSAK_ENV: z.enum(['STAGING', 'PRODUCTION']).default('STAGING'),

  SENDGRID_API_KEY: z.string().optional(),
  EMAIL_FROM: z.string().email().default('noreply@theworkingapp.io'),

  KYC_ORACLE_PRIVATE_KEY: z.string().optional(),
  KYC_PROVIDER_URL: z.string().url().optional(),

  PLATFORM_FEE_BPS: z.coerce.number().default(150),
  PORTION_GRANT_MAX_PCT: z.coerce.number().default(30),
  DEFAULT_MIN_MEMBERS: z.coerce.number().default(2),

  FRONTEND_URL: z.string().url().default('http://localhost:3000'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
