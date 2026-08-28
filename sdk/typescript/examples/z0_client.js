/**
 * Z0-Vault Client Integration Core
 * Client-Side Ed25519 WebCrypto Engine, Demurrage Decay Math,
 * & Remote API Endpoint Synchronizer
 */

const DEFAULT_TX_ENDPOINT = "https://brahmi.allb.xyz/api/tx";

// ----------------------------------------------------------------------------
// 1. Demurrage Decay Math Engine
// ----------------------------------------------------------------------------

/**
 * Calculates decayed balance subject to demurrage over time.
 * @param {number} principal - Initial Z0 balance token amount.
 * @param {number} annualRate - Annual demurrage decay rate (e.g., 0.05 for 5%).
 * @param {number} lastTimestampSec - Last epoch timestamp in seconds.
 * @param {number} currentTimestampSec - Current epoch timestamp in seconds.
 * @returns {number} Decayed balance rounded to 6 decimal places.
 */
export function calculateDemurrageBalance(principal, annualRate, lastTimestampSec, currentTimestampSec) {
    if (currentTimestampSec <= lastTimestampSec || principal <= 0) {
        return principal;
    }
    
    const SECONDS_IN_YEAR = 31536000;
    const timeDeltaSec = currentTimestampSec - lastTimestampSec;
    const elapsedYears = timeDeltaSec / SECONDS_IN_YEAR;
    
    // Continuous decay formula: Balance(t) = P * e^(-r * t)
    const decayedValue = principal * Math.exp(-annualRate * elapsedYears);
    return Math.floor(decayedValue * 1e6) / 1e6;
}

// ----------------------------------------------------------------------------
// 2. Client-Side WebCrypto Ed25519 Key Management, Signing & API Sync
// ----------------------------------------------------------------------------

export class Z0VaultWallet {
    constructor(apiEndpoint = DEFAULT_TX_ENDPOINT) {
        this.keyPair = null;
        this.publicKeyHex = null;
        this.apiEndpoint = apiEndpoint;
    }

    /**
     * Generate an Ed25519 Keypair natively using WebCrypto API.
     */
    async generateKeypair() {
        this.keyPair = await window.crypto.subtle.generateKey(
            { name: "Ed25519" },
            true,
            ["sign", "verify"]
        );

        const exportedPub = await window.crypto.subtle.exportKey("raw", this.keyPair.publicKey);
        this.publicKeyHex = Array.from(new Uint8Array(exportedPub))
            .map(b => b.toString(16).padStart(2, "0"))
            .join("");

        return {
            publicKey: this.publicKeyHex,
            keyPair: this.keyPair
        };
    }

    /**
     * Sign a transaction payload with the client-side private key.
     * @param {Object} txPayload - Transaction metadata (sender, recipient, amount, timestamp).
     * @returns {Object} Signed transaction object containing signature and hex payload.
     */
    async signTransaction(txPayload) {
        if (!this.keyPair) {
            throw new Error("Wallet keypair not initialized. Call generateKeypair() first.");
        }

        const encoder = new TextEncoder();
        const payloadBytes = encoder.encode(JSON.stringify(txPayload));
        
        const signatureBuffer = await window.crypto.subtle.sign(
            { name: "Ed25519" },
            this.keyPair.privateKey,
            payloadBytes
        );

        const signatureHex = Array.from(new Uint8Array(signatureBuffer))
            .map(b => b.toString(16).padStart(2, "0"))
            .join("");

        return {
            payload: txPayload,
            signature: signatureHex,
            signerPublicKey: this.publicKeyHex
        };
    }

    /**
     * Post a signed transaction object directly to the Cloudflare Worker API endpoint.
     * @param {Object} signedTx - Signed transaction object (output of signTransaction).
     * @param {string} [endpointOverride] - Optional URL override for custom endpoints.
     * @returns {Promise<Object>} API response JSON from Cloudflare Worker.
     */
    async submitTransaction(signedTx, endpointOverride = null) {
        const url = endpointOverride || this.apiEndpoint;

        try {
            const response = await fetch(url, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-Z0-Client-Version": "1.0.0"
                },
                body: JSON.stringify(signedTx)
            });

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(
                    `Transaction Submission Failed [HTTP ${response.status}]: ${
                        errorData.message || response.statusText
                    }`
                );
            }

            return await response.json();
        } catch (error) {
            console.error("[Z0-Client] Error submitting transaction to API:", error);
            throw error;
        }
    }
}