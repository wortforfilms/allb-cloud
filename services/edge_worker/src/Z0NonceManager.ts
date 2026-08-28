export interface NonceVerificationResult {
  valid: boolean;
  errorCode?: "EXPIRED_TIMESTAMP" | "REPLAY_ATTACK_DETECTED" | "INVALID_NONCE_FORMAT";
}

export class Z0NonceManager {
  private kvNamespace: KVNamespace;
  private readonly REPLAY_WINDOW_SEC = 300; // 5 Minutes
  private readonly KV_EXPIRATION_TTL_SEC = 600; // 10 Minutes

  constructor(kvNamespace: KVNamespace) {
    this.kvNamespace = kvNamespace;
  }

  /**
   * Validates nonce freshness and registers it to prevent future replay attacks.
   */
  async validateAndConsumeNonce(
    nonce: string,
    requestTimestampUtc: string,
    signerPubKeyHex: string
  ): Promise<NonceVerificationResult> {
    // 1. Validate Nonce Format (16-byte hex format: 0x...)
    if (!/^0x[a-fA-F0-9]{32}$/.test(nonce)) {
      return { valid: false, errorCode: "INVALID_NONCE_FORMAT" };
    }

    // 2. Validate Request Timestamp Skew (+/- 300s)
    const requestTimeMs = new Date(requestTimestampUtc).getTime();
    const currentTimeMs = Date.now();
    const timeDeltaSec = Math.abs(currentTimeMs - requestTimeMs) / 1000;

    if (timeDeltaSec > this.REPLAY_WINDOW_SEC) {
      return { valid: false, errorCode: "EXPIRED_TIMESTAMP" };
    }

    // 3. Construct KV Key Target
    const kvKey = `z0:nonce:${nonce}`;

    // 4. Query KV for Existing Nonce Entry
    const existingEntry = await this.kvNamespace.get(kvKey);
    if (existingEntry !== null) {
      return { valid: false, errorCode: "REPLAY_ATTACK_DETECTED" };
    }

    // 5. Atomic-Style Record Write with Auto-Garbage Collection TTL
    const payloadValue = `${requestTimeMs}:${signerPubKeyHex.substring(0, 16)}`;
    
    await this.kvNamespace.put(kvKey, payloadValue, {
      expirationTtl: this.KV_EXPIRATION_TTL_SEC,
    });

    return { valid: true };
  }
}