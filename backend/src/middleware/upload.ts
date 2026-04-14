import multer from 'multer';
import { AppError } from '../utils/AppError';

/**
 * Multer configuration for memory storage.
 * Files are kept in memory as buffers before being uploaded to IPFS.
 */
const storage = multer.memoryStorage();

/**
 * File filter to allow only images and PDFs.
 */
const fileFilter = (_req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  ];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new AppError('Invalid file type. Only JPEG, PNG, WEBP and PDF are allowed.', 400) as any);
  }
};

/**
 * Upload middleware with a 50MB file size limit.
 */
export const uploadMiddleware = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB
  },
});
