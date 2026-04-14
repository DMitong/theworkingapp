# Real-World Tracking Sheet

This sheet tracks the required configuration and "real-world" information needed to fully operationalize The Working App.

## 1. Blockchain Configuration
| Key | Description | Status | Where to Fix |
|---|---|---|---|
| `PLATFORM_PRIVATE_KEY` | Private key for the platform's deployer wallet. | ❌ PLACEHOLDER | `backend/.env` |
| `PLATFORM_WALLET_ADDRESS` | Public address for the platform's deployer wallet. | ❌ PLACEHOLDER | `backend/.env` |
| `MEDIATION_KEY_ADDRESS` | Address that can sign off on mediation rulings. | ❌ PLACEHOLDER | `backend/.env` |
| `PLATFORM_FACTORY_ADDRESS` | Deployed address of the PlatformFactory contract. | ❌ EMPTY | `backend/.env` |
| `PLATFORM_NFT_REGISTRY_ADDRESS` | Deployed address of the PlatformNFTRegistry contract. | ❌ EMPTY | `backend/.env` |

## 2. External Services
| Service | Key | Status | Where to Fix |
|---|---|---|---|
| **Pinata** | `PINATA_API_KEY`, `PINATA_SECRET_API_KEY` | ❌ PLACEHOLDER | `backend/.env` |
| **Onramper** | `ONRAMPER_API_KEY` | ❌ PLACEHOLDER | `backend/.env` |
| **Transak** | `TRANSAK_API_KEY` | ❌ PLACEHOLDER | `backend/.env` |
| **SendGrid** | `SENDGRID_API_KEY` | ❌ PLACEHOLDER | `backend/.env` |

## 3. Database & Infrastructure
| Item | Action Required | Status | Command |
|---|---|---|---|
| **PostgreSQL** | Ensure container is running. | ⚠️ CHECK | `docker-compose -f infra/docker/docker-compose.yml up -d` |
| **Prisma Migrations** | Sync schema with real database. | ❌ PENDING | `npx prisma migrate dev --name init` |
| **Redis** | Ensure container is running. | ⚠️ CHECK | `docker-compose -f infra/docker/docker-compose.yml up -d` |

## 4. Pending Implementation Wiring
| Item | Description | Status | File |
|---|---|---|---|
| `BlockchainService.init()` | Initialize the static ethers provider and wallet. | ❌ WIRING TODO | `backend/src/index.ts` |
| `listenToBounty()` | Add event listener for BountyContract events. | ❌ WIRING TODO | `backend/src/services/blockchain/eventListener.ts` |
| `reattachActiveBounties()`| Re-attach listeners for active bounties on startup. | ❌ WIRING TODO | `backend/src/services/blockchain/eventListener.ts` |

---
**Last Updated:** Tuesday, April 14, 2026
