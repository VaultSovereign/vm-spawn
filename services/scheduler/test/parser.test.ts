import { describe, expect, test } from '@jest/globals';
import { parseEvery } from '../src/parser';

describe('Cadence expression parser', () => {
  test('parses absolute time expressions', () => {
    expect(parseEvery('89s')).toBe(89);
    expect(parseEvery('5m')).toBe(300);
    expect(parseEvery('2h')).toBe(7200);
    expect(parseEvery('1d')).toBe(86400);
  });

  test('parses relative time expressions', () => {
    expect(parseEvery('34*fast', 89)).toBe(3026);
    expect(parseEvery('2*fast', 300)).toBe(600);
    expect(parseEvery('7*strong', 0, { strong: 3600 })).toBe(25200);
  });

  test('throws on invalid expressions', () => {
    expect(() => parseEvery('invalid')).toThrow();
    expect(() => parseEvery('34*fast')).toThrow(); // missing base value
    expect(() => parseEvery('-89s')).toThrow();
    expect(() => parseEvery('89x')).toThrow();
  });
});