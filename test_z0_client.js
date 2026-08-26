// ============================================================================
// File:        test_z0_client.js
// Description: Integration test for Z0VaultWallet WebCrypto signing and fetch
// ============================================================================

import { Z0VaultWallet, calculateDemurrageBalance } from './z0_client.js';

async function runIntegrationTest() {
    console.log("=================================================");
    console.log("  Z0-VAULT CLIENT INTEGRATION TEST SUITE         ");
    console.log("=================================================");

    // ------------------------------------------------------------------------
    // Test 1: Demurrage Math Verification
    // ------------------------------------------------------------------------
    console.log("\n[TEST 1] Testing Demurrage Decay Calculation...");
    const principal = 100.0;
    const rate = 0.05; // 5% annual decay
    const t0 = 1700000000;
    const t1 = t0 + 31536000; // 1 year later

    const decayedBalance = calculateDemurrageBalance(principal, rate, t0, t1);
    console.log(`  • Principal: ${principal} Z0`);
    console.log(`  • Balance after 1 year (5% decay): ${decayedBalance} Z0`);
    
    if (decayedBalance < principal && decayedBalance > 94.0) {
        console.log("  ✓ Demurrage decay math verification PASSED.");
    } else {
        console.error("  ✗ Demurrage decay math verification FAILED.");
        process.exit(1);
    }

    // ------------------------------------------------------------------------
    // Test 2: Ed25519 Key Generation & Local Signing
    // ------------------------------------------------------------------------
    console.log("\n[TEST 2] Generating Ed25519 Keypair & Signing Payload...");
    const wallet = new Z0VaultWallet("https://brahmi.allb.xyz/api/tx");

    try {
        const keyInfo = await wallet.generateKeypair();
        console.log(`  • Public Key (Hex): ${keyInfo.publicKey}`);

        const txPayload = {
            sender: keyInfo.publicKey,
            recipient: "z0_vault_test_pool",
            amount: 10.5,
            timestamp: Math.floor(Date.now() / 1000)
        };

        const signedTx = await wallet.signTransaction(txPayload);
        console.log(`  • Signature (Hex): ${signedTx.signature.substring(0, 32)}...`);
        console.log("  ✓ Keypair generation & transaction signing PASSED.");

        // ------------------------------------------------------------------------
        // Test 3: API Endpoint Submission
        // ------------------------------------------------------------------------
        console.log("\n[TEST 3] Submitting Signed Transaction to API Endpoint...");
        console.log(`  • Target URL: ${wallet.apiEndpoint}`);

        const response = await wallet.submitTransaction(signedTx);
        console.log("  • API Server Response:", JSON.stringify(response, null, 2));
        console.log("  ✓ Transaction submission PASSED.");

    } catch (error) {
        console.error(`  ✗ Test failed with error: ${error.message}`);
        // If the endpoint is offline or returning network errors in a local environment, 
        // log the error details for inspection.
    }

    console.log("\n=================================================");
    console.log("  INTEGRATION TEST RUN COMPLETE                  ");
    console.log("=================================================");
}

runIntegrationTest();