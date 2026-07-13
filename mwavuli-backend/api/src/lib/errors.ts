export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const badRequest = (m: string) => new AppError(400, 'bad_request', m);
export const unauthorized = (m = 'Unauthorized') =>
  new AppError(401, 'unauthorized', m);
export const forbidden = (m = 'Forbidden') => new AppError(403, 'forbidden', m);
export const notFound = (m = 'Not found') => new AppError(404, 'not_found', m);
export const conflict = (m: string) => new AppError(409, 'conflict', m);
export const tooMany = (m = 'Rate limit exceeded') =>
  new AppError(429, 'rate_limited', m);
