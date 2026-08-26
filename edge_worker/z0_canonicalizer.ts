import canonicalize from 'canonicalize';

/**
 * Z0 Canonicalizer Layer
 * Ensures deterministic JSON payload serialization before signature verification.
 */

export interface CanonicalizationOptions {
  stripUndefined?: boolean;
  sortKeys?: boolean;
}

/**
 * Canonicalizes an arbitrary JSON-compatible object using the RFC 8785 JSON Canonicalization Scheme (JCS).
 *
 * @param payload - The input object or array to canonicalize.
 * @returns RFC 8785 canonicalized JSON string, or undefined if input is invalid/unserializable.
 */
export function canonicalizePayload(payload: unknown, options: CanonicalizationOptions = {}): string {
  if (payload === null || payload === undefined) {
    throw new Error('Canonicalization Error: Input payload cannot be null or undefined.');
  }

  // Sanitize object if stripUndefined option is active
  const targetPayload = options.stripUndefined ? sanitizePayload(payload) : payload;

  const result = canonicalize(targetPayload);

  if (result === undefined) {
    throw new Error('Canonicalization Error: Failed to produce deterministic canonical representation.');
  }

  return result;
}

/**
 * Recursively strips undefined values and functions from objects/arrays prior to JCS processing.
 */
function sanitizePayload(obj: unknown): unknown {
  if (Array.isArray(obj)) {
    return obj.map(sanitizePayload);
  }
  
  if (obj !== null && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj)
        .filter(([_, value]) => value !== undefined && typeof value !== 'function')
        .map(([key, value]) => [key, sanitizePayload(value)])
    );
  }

  return obj;
}

/**
 * Helper to encode canonicalized string to Uint8Array for Web Crypto API operations.
 */
export function canonicalizeToBytes(payload: unknown, options?: CanonicalizationOptions): Uint8Array {
  const canonicalString = canonicalizePayload(payload, options);
  return new TextEncoder().encode(canonicalString);
}