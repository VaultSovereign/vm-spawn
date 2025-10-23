import { describe, it, expect } from '@jest/globals';
import { classifyError, AnchorErrorType } from '../../src/errors';

describe('classifyError', () => {
  it('detects network', () => {
    expect(classifyError(new Error('ECONNREFUSED'))).toBe(AnchorErrorType.NETWORK);
  });
  it('detects auth', () => {
    expect(classifyError(new Error('Unauthorized 401'))).toBe(AnchorErrorType.AUTH);
  });
  it('detects validation', () => {
    expect(classifyError(new Error('invalid payload'))).toBe(AnchorErrorType.VALIDATION);
  });
  it('falls back', () => {
    expect(classifyError(new Error('weird error'))).toBe(AnchorErrorType.UNKNOWN);
  });
});

