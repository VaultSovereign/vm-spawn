/**
 * Parser for cadence expressions
 * Supports:
 * - Absolute: "89s", "5m", "1h", "1d"
 * - Relative: "34*fast", "7*strong", "2*cold"
 */

/**
 * Parse a cadence expression into seconds
 * 
 * @param expr - Cadence expression (e.g., "89s", "5m", "34*fast")
 * @param baseFast - Base seconds for fast cadence (required for relative expressions)
 * @param baseCadences - Object with seconds for other cadence levels
 * @returns Time period in seconds
 */
export function parseEvery(
  expr: string, 
  baseFast?: number,
  baseCadences?: Record<string, number>
): number {
  // Absolute time units
  const absoluteMatch = expr.match(/^(\d+)(s|m|h|d)$/i);
  if (absoluteMatch) {
    const value = parseInt(absoluteMatch[1], 10);
    if (value <= 0) {
      throw new Error(`Invalid cadence value: ${value} (must be positive)`);
    }
    
    const unit = absoluteMatch[2].toLowerCase();
    if (unit === 's') return value;
    if (unit === 'm') return value * 60;
    if (unit === 'h') return value * 3600;
    if (unit === 'd') return value * 86400;
  }

  // Relative expressions (e.g., "34*fast")
  const relativeMatch = expr.match(/^(\d+)\*([a-z]+)$/i);
  if (relativeMatch) {
    const multiplier = parseInt(relativeMatch[1], 10);
    if (multiplier <= 0) {
      throw new Error(`Invalid multiplier: ${multiplier} (must be positive)`);
    }

    const base = relativeMatch[2].toLowerCase();
    
    if (base === 'fast') {
      if (typeof baseFast !== 'number') {
        throw new Error(`Base fast cadence is required for relative expression: ${expr}`);
      }
      return multiplier * baseFast;
    }
    
    if (baseCadences && typeof baseCadences[base] === 'number') {
      return multiplier * baseCadences[base];
    }
    
    throw new Error(`Unknown base cadence: ${base}`);
  }

  throw new Error(`Invalid cadence expression: ${expr}`);
}