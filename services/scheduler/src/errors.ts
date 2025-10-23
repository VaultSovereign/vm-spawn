export enum AnchorErrorType {
  NETWORK = 'network',
  AUTH = 'auth',
  VALIDATION = 'validation',
  UNKNOWN = 'unknown',
}

export function classifyError(error: Error): AnchorErrorType {
  const msg = (error.message || '').toLowerCase();
  if (msg.includes('econnrefused') || msg.includes('timeout') || msg.includes('network')) return AnchorErrorType.NETWORK;
  if (msg.includes('unauthorized') || msg.includes('forbidden') || msg.includes('403') || msg.includes('401')) return AnchorErrorType.AUTH;
  if (msg.includes('invalid') || msg.includes('schema') || msg.includes('malformed')) return AnchorErrorType.VALIDATION;
  return AnchorErrorType.UNKNOWN;
}

