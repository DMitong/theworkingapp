import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createServer } from 'http';
import { Server as SocketServer } from 'socket.io';

import { env } from './config/env';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { rateLimiter } from './middleware/rateLimiter';
import { requestLogger } from './middleware/requestLogger';

// Routes
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import communityRoutes from './routes/communities';
import projectRoutes from './routes/projects';
import bountyRoutes from './routes/bounties';
import escrowRoutes from './routes/escrow';
import nftRoutes from './routes/nft';

// Services
import { BlockchainService } from './services/blockchain/BlockchainService';
import { BlockchainEventListener } from './services/blockchain/eventListener';

const app = express();
const httpServer = createServer(app);

// ── Socket.IO (real-time vote and project updates) ───────────
export const io = new SocketServer(httpServer, {
  cors: { origin: env.FRONTEND_URL, credentials: true },
});

io.on('connection', (socket) => {
  logger.info(`Socket connected: ${socket.id}`);

  socket.on('join:community', (communityId: string) => {
    socket.join(`community:${communityId}`);
  });

  socket.on('join:project', (projectId: string) => {
    socket.join(`project:${projectId}`);
  });

  socket.on('disconnect', () => {
    logger.info(`Socket disconnected: ${socket.id}`);
  });
});

// ── Middleware ────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: env.FRONTEND_URL, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(rateLimiter);
app.use(requestLogger);

// ── Health check ──────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: env.API_VERSION, ts: new Date().toISOString() });
});

// ── API Routes ────────────────────────────────────────────────
const apiBase = `/api/${env.API_VERSION}`;
app.use(`${apiBase}/auth`, authRoutes);
app.use(`${apiBase}/users`, userRoutes);
app.use(`${apiBase}/communities`, communityRoutes);
app.use(`${apiBase}/projects`, projectRoutes);
app.use(`${apiBase}/bounties`, bountyRoutes);
app.use(`${apiBase}/escrow`, escrowRoutes);
app.use(`${apiBase}/nft`, nftRoutes);

// ── Error handler (must be last) ─────────────────────────────
app.use(errorHandler);

// ── Start server ──────────────────────────────────────────────
const PORT = env.PORT;

httpServer.listen(PORT, async () => {
  logger.info(`The Working App API running on port ${PORT} [${env.NODE_ENV}]`);

  // Start blockchain services
  try {
    BlockchainService.init();
    await BlockchainEventListener.start();
    logger.info('Blockchain services initialized');
  } catch (err) {
    logger.error('Failed to initialize blockchain services', err);
  }
});

export default app;
