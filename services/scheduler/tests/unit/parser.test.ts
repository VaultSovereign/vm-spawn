import { describe, it, expect } from '@jest/globals';

function parseEvery(expr: string, baseFast?: number): number {
  const m = expr.match(/^(\d+)(s|m|h|d)$/i);
  if (m) {
    const n = parseInt(m[1], 10);
    return m[2] === 's' ? n : m[2] === 'm' ? n*60 : m[2] === 'h' ? n*3600 : n*86400;
  }
  const k = expr.match(/^(\d+)\*fast$/i);
  if (k && baseFast) return parseInt(k[1], 10) * baseFast;
  throw new Error(`invalid cadence: ${expr}`);
}

describe('parseEvery', () => {
  it('parses absolute units', () => {
    expect(parseEvery('89s')).toBe(89);
    expect(parseEvery('5m')).toBe(300);
    expect(parseEvery('1h')).toBe(3600);
    expect(parseEvery('1d')).toBe(86400);
  });
  it('parses relative multiples', () => {
    expect(parseEvery('34*fast', 90)).toBe(3060);
  });
  it('throws on invalid', () => {
    expect(() => parseEvery('fast')).toThrow();
  });
});

