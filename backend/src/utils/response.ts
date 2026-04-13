import { Response } from 'express';

interface SuccessResponse<T> {
  success: true;
  data: T;
}

interface ErrorResponse {
  success: false;
  error: {
    message: string;
    code?: string;
  };
}

export function sendSuccess<T>(res: Response, data: T, status: number = 200): void {
  const body: SuccessResponse<T> = { success: true, data };
  res.status(status).json(body);
}

export function sendError(res: Response, message: string, status: number = 500, code?: string): void {
  const body: ErrorResponse = { success: false, error: { message, ...(code && { code }) } };
  res.status(status).json(body);
}

export function sendCreated<T>(res: Response, data: T): void {
  sendSuccess(res, data, 201);
}

export function sendNoContent(res: Response): void {
  res.status(204).end();
}
