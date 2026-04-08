import { createConfig, http } from 'wagmi';
import { base, baseSepolia, polygon, polygonAmoy, mainnet } from 'wagmi/chains';
import { injected, walletConnect } from 'wagmi/connectors';

export const wagmiConfig = createConfig({
  chains: [base, baseSepolia, polygon, polygonAmoy, mainnet],
  connectors: [
    injected(),
    walletConnect({ projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? '' }),
  ],
  transports: {
    [base.id]:        http(),
    [baseSepolia.id]: http(),
    [polygon.id]:     http(),
    [polygonAmoy.id]: http(),
    [mainnet.id]:     http(),
  },
});
