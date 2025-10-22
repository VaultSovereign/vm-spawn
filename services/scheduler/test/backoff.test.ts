import { describe, expect, test } from '@jest/globals';
import { calculateBackoffDelay, MAX_BACKOFF_ATTEMPTS } from '../src/backoff';

describe('φ-backoff algorithm', () => {
  test('calculates golden ratio based backoff', () => {
    // Base delay is 5s, golden ratio φ is approximately 1.618
    expect(calculateBackoffDelay(0)).toBe(5);      // 5 * 1.618^0 ≈ 5
    expect(calculateBackoffDelay(1)).toBe(8);      // 5 * 1.618^1 ≈ 8.09
    expect(calculateBackoffDelay(2)).toBe(13);     // 5 * 1.618^2 ≈ 13.09
    expect(calculateBackoffDelay(3)).toBe(21);     // 5 * 1.618^3 ≈ 21.18
    expect(calculateBackoffDelay(4)).toBe(34);     // 5 * 1.618^4 ≈ 34.27
    expect(calculateBackoffDelay(5)).toBe(55);     // 5 * 1.618^5 ≈ 55.44
    expect(calculateBackoffDelay(6)).toBe(90);     // 5 * 1.618^6 ≈ 89.7
    expect(calculateBackoffDelay(7)).toBe(145);    // 5 * 1.618^7 ≈ 145.14
  });

  test('respects max attempts', () => {
    // Should cap at MAX_BACKOFF_ATTEMPTS (7)
    const largeK = MAX_BACKOFF_ATTEMPTS + 5; 
    const maxK = MAX_BACKOFF_ATTEMPTS;
    
    expect(calculateBackoffDelay(largeK)).toBe(calculateBackoffDelay(maxK));
    expect(calculateBackoffDelay(100)).toBe(calculateBackoffDelay(MAX_BACKOFF_ATTEMPTS));
  });

  test('handles invalid inputs', () => {
    expect(calculateBackoffDelay(-1)).toBe(5);     // negative should return base delay
    expect(calculateBackoffDelay(NaN)).toBe(5);    // NaN should return base delay
  });
});