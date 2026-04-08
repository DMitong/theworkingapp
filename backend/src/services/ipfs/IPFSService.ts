import { env } from '../../config/env';
import { logger } from '../../utils/logger';

/**
 * IPFSService
 *
 * Handles uploading files and JSON objects to IPFS via Pinata.
 * All user-uploaded documents (proposals, bid files, evidence) go through here.
 * The returned IPFS hash is stored on-chain; the content lives on IPFS.
 *
 * BUILD GUIDE:
 * ─────────────────────────────────────────────────────────────
 * 1. Install Pinata SDK: npm install pinata
 * 2. Use env.PINATA_API_KEY and env.PINATA_SECRET_API_KEY
 * 3. All uploads are pinned to the platform's Pinata account
 * 4. Content addressing: every IPFS hash is content-addressed — identical
 *    files produce identical hashes, so de-duplication is automatic.
 * 5. Gateway: use env.PINATA_GATEWAY for retrieving content
 *    (e.g. https://gateway.pinata.cloud/ipfs/{hash})
 * 6. File size limits: enforce max 50MB per file in the upload middleware
 * ─────────────────────────────────────────────────────────────
 */
export class IPFSService {
  /**
   * Upload a JSON object to IPFS. Returns the IPFS hash (CID).
   * Used for: proposal metadata, bid packages, evidence reports, NFT metadata.
   *
   * @example
   * const hash = await IPFSService.uploadJSON({
   *   title: 'New Gate Project',
   *   description: 'Replace estate entrance gate',
   *   scope: '...',
   *   budget: { min: 500000, max: 800000, currency: 'USDC' },
   * });
   * // hash = 'QmXyz...'
   * // Store hash in ProjectContract at deploy time
   */
  static async uploadJSON(data: Record<string, unknown>, name?: string): Promise<string> {
    // TODO: Implement with Pinata SDK
    // const pinata = new PinataSDK({ pinataApiKey: env.PINATA_API_KEY, pinataSecretApiKey: env.PINATA_SECRET_API_KEY })
    // const result = await pinata.pinJSONToIPFS(data, { pinataMetadata: { name: name || 'theworkingapp-data' } })
    // return result.IpfsHash
    logger.debug('IPFSService.uploadJSON called (not yet implemented)', { name });
    throw new Error('IPFSService.uploadJSON not yet implemented');
  }

  /**
   * Upload a file buffer to IPFS. Returns the IPFS hash (CID).
   * Used for: project images, bid document PDFs, completion evidence photos.
   */
  static async uploadFile(buffer: Buffer, filename: string, mimeType: string): Promise<string> {
    // TODO: Implement with Pinata SDK
    // const stream = Readable.from(buffer)
    // const result = await pinata.pinFileToIPFS(stream, { pinataMetadata: { name: filename } })
    // return result.IpfsHash
    throw new Error('IPFSService.uploadFile not yet implemented');
  }

  /**
   * Retrieve JSON content from IPFS via the platform gateway.
   */
  static async getJSON(ipfsHash: string): Promise<Record<string, unknown>> {
    const url = `${env.PINATA_GATEWAY}/ipfs/${ipfsHash}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`IPFS fetch failed for ${ipfsHash}: ${res.status}`);
    return res.json();
  }

  static getGatewayUrl(ipfsHash: string): string {
    return `${env.PINATA_GATEWAY}/ipfs/${ipfsHash}`;
  }
}
