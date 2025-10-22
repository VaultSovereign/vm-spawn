/**
 * φ-backoff algorithm implementation
 * Uses the golden ratio (φ ≈ 1.618) for exponential backoff
 * 
 * Formula: delay = BASE_DELAY * φ^k
 * Where k is the attempt number (capped at MAX_BACKOFF_ATTEMPTS)
 */

// Base delay in seconds
export const BASE_DELAY = 5;

// Golden ratio (φ)
export const PHI = 1.618;

// Maximum number of backoff attempts before capping
export const MAX_BACKOFF_ATTEMPTS = 7;

/**
 * Calculate backoff delay using golden ratio
 * 
 * @param attempts - Number of previous attempts (k)
 * @returns Delay in seconds
 */
export function calculateBackoffDelay(attempts: number): number {
  // Handle invalid inputs
  if (typeof attempts !== 'number' || isNaN(attempts) || attempts < 0) {
    return BASE_DELAY;
  }
  
  // Cap at maximum attempts
  const k = Math.min(Math.floor(attempts), MAX_BACKOFF_ATTEMPTS);
  
  // Calculate delay: BASE_DELAY * φ^k
  // Round to nearest integer
  return Math.round(BASE_DELAY * Math.pow(PHI, k));
}

/**
 * Get the next backoff state and delay
 * 
 * @param currentBackoff - Current backoff state
 * @returns Object with new backoff state and delay in seconds
 */
export function getNextBackoff(currentBackoff: number): { backoff: number, delay: number } {
  const nextBackoff = (currentBackoff || 0) + 1;
  return {
    backoff: nextBackoff,
    delay: calculateBackoffDelay(nextBackoff)
  };
}

/**
 * Reset backoff state
 * 
 * @returns Reset backoff state (0)
 */
export function resetBackoff(): number {
  return 0;
}