import { PinataSDK } from 'pinata';
import { env } from '../../config/env';
import { logger } from '../../utils/logger';

/**
 * IPFSService
 *
 * Handles uploading files and JSON objects to IPFS via Pinata.
 * All user-uploaded documents (proposals, bid files, evidence) go through here.
 * The returned IPFS hash is stored on-chain; the content lives on IPFS.
 */
export class IPFSService {
  private static pinata = new PinataSDK({
    pinataApiKey: env.PINATA_API_KEY,
    pinataSecretApiKey: env.PINATA_SECRET_API_KEY,
  });

  /**
   * Upload a JSON object to IPFS. Returns the IPFS hash (CID).
   * Used for: proposal metadata, bid packages, evidence reports, NFT metadata.
   */
  static async uploadJSON(data: Record<string, unknown>, name?: string): Promise<string> {
    logger.debug(`Uploading JSON to IPFS: ${name || 'theworkingapp-data'}`);
    try {
      const result = await this.pinata.upload.json(data).addMetadata({
        name: name || 'theworkingapp-data',
      });
      return result.IpfsHash;
    } catch (error) {
      logger.error('Failed to upload JSON to IPFS', { name, error });
      throw new Error('IPFS upload failed');
    }
  }

  /**
   * Upload a file buffer to IPFS. Returns the IPFS hash (CID).
   * Used for: project images, bid document PDFs, completion evidence photos.
   */
  static async uploadFile(buffer: Buffer, filename: string, mimeType: string): Promise<string> {
    logger.debug(`Uploading file to IPFS: ${filename} (${mimeType})`);
    try {
      // Create a File object from the buffer
      const file = new File([buffer], filename, { type: mimeType });
      const result = await this.pinata.upload.file(file);
      return result.IpfsHash;
    } catch (error) {
      logger.error('Failed to upload file to IPFS', { filename, error });
      throw new Error('IPFS upload failed');
    }
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
