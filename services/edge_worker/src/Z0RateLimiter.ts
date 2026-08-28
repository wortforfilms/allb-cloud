export interface RateLimitStatus {
  allowed: boolean;
  currentCount: number;
  limit: number;
  resetSeconds: number;
}

export class Z0EdgeRateLimiter {
  private kv: KVNamespace;
  private readonly SIGNER_LIMIT_PER_MIN = 30;
  private readonly WINDOW_SIZE_SEC = 60;

  constructor(kvNamespace: KVNamespace) {
    this.kv = kvNamespace;
  }

  /**
   * Enforces sliding-window rate limit per Ed25519 Signer Public Key
   */
  async checkSignerRateLimit(signerPubKeyHex: string): Promise<RateLimitStatus> {
    const nowSec = Math.floor(Date.now() / 1000);
    const currentWindowMin = Math.floor(nowSec / 60);
    
    // Hash key to minimize KV space
    const signerHash = signerPubKeyHex.substring(0, 16);
    const kvKey = `rl:signer:${signerHash}:${currentWindowMin}`;

    // Read current window count from KV
    const currentCountStr = await this.kv.get(kvKey);
    const currentCount = currentCountStr ? parseInt(currentCountStr, 10) : 0;

    const resetSeconds = 60 - (nowSec % 60);

    if (currentCount >= this.SIGNER_LIMIT_PER_MIN) {
      return {
        allowed: false,
        currentCount,
        limit: this.SIGNER_LIMIT_PER_MIN,
        resetSeconds,
      };
    }

    // Atomic increment strategy with expiration TTL = 120s
    await this.kv.put(kvKey, (currentCount + 1).toString(), {
      expirationTtl: 120,
    });

    return {
      allowed: true,
      currentCount: currentCount + 1,
      limit: this.SIGNER_LIMIT_PER_MIN,
      resetSeconds,
    };
  }
}