import { Z0VaultWallet } from './z0_client.js';

const wallet = new Z0VaultWallet();

async function executeTxPipeline() {
    // 1. Generate Ed25519 Keypair
    await wallet.generateKeypair();

    // 2. Prepare Payload
    const payload = {
        sender: wallet.publicKeyHex,
        recipient: "z0_vault_pool_0x99",
        amount: 25.5,
        timestamp: Math.floor(Date.now() / 1000)
    };

    // 3. Sign Locally
    const signedTx = await wallet.signTransaction(payload);

    // 4. Submit to Cloudflare Worker API
    const response = await wallet.submitTransaction(signedTx);
    console.log("Transaction successfully confirmed:", response);
}