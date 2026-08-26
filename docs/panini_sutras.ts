import { canonicalize } from 'json-canonicalize';

export interface VespPayload {
  embedding: number[];
  confidence: number;
  timestamp: number;
  signerPublicKey: string;
  nonce: string;
}

export interface SutraEvaluation {
  sutraId: string;
  name: string;
  passed: boolean;
  message: string;
}

export interface PaniniValidationReport {
  overallPassed: boolean;
  canonicalJson: string;
  canonicalDigest: string;
  evaluations: SutraEvaluation[];
  truthScore: number;
  entropyDelta: number;
}

export class PaniniSutraEngine {
  private static readonly REPLAY_WINDOW_SEC = 300;
  private static readonly ALPHA = 0.6;
  private static readonly MIN_TRUTH_SCORE = 0.85;

  /**
   * Complete Phase 1 Validation Flow
   */
  public static async validatePayload(
    rawPayload: VespPayload,
    consensusVector: number[],
    currentEntropy: number
  ): Promise<PaniniValidationReport> {
    const evaluations: SutraEvaluation[] = [];

    // 1. RFC 8785 Canonicalization
    const canonicalJson = canonicalize(rawPayload);
    const canonicalDigest = await this.sha256Hex(canonicalJson);

    // -------------------------------------------------------------------------
    // Sutra Group 1: Samjna (Type, Bounds & Structural Integrity)
    // -------------------------------------------------------------------------
    const confidenceValid = rawPayload.confidence >= 0 && rawPayload.confidence <= 1;
    evaluations.push({
      sutraId: 'Sutra_1_1_Samjna',
      name: 'Confidence Range Constraint',
      passed: confidenceValid,
      message: confidenceValid ? 'Confidence score in [0.0, 1.0]' : 'Confidence out of bounds'
    });

    const dimValid = Array.isArray(rawPayload.embedding) && rawPayload.embedding.length === consensusVector.length;
    evaluations.push({
      sutraId: 'Sutra_1_2_Samjna',
      name: 'Embedding Dimension Alignment',
      passed: dimValid,
      message: dimValid ? `Vector dimension matches consensus (${consensusVector.length})` : 'Dimension mismatch'
    });

    // -------------------------------------------------------------------------
    // Sutra Group 2: Paribhasha (Temporal & Contextual Constraints)
    // -------------------------------------------------------------------------
    const nowSec = Math.floor(Date.now() / 1000);
    const timeDelta = Math.abs(nowSec - rawPayload.timestamp);
    const timestampValid = timeDelta <= this.REPLAY_WINDOW_SEC;
    evaluations.push({
      sutraId: 'Sutra_2_1_Paribhasha',
      name: 'Temporal Freshness Constraint',
      passed: timestampValid,
      message: timestampValid ? `Payload age (${timeDelta}s) within 300s window` : `Stale timestamp (${timeDelta}s)`
    });

    // -------------------------------------------------------------------------
    // Sutra Group 3: Vidhi (Cosine Alignment & Shannon Entropy Delta)
    // -------------------------------------------------------------------------
    let cosineSim = 0;
    if (dimValid) {
      cosineSim = this.computeCosineSimilarity(rawPayload.embedding, consensusVector);
    }
    
    // Entropy Reduction Equation: ΔH = H_new - H_old
    const estimatedNewEntropy = currentEntropy - (cosineSim * rawPayload.confidence);
    const entropyDelta = estimatedNewEntropy - currentEntropy; // ΔH < 0 represents noise reduction

    const entropyValid = entropyDelta <= 0;
    evaluations.push({
      sutraId: 'Sutra_3_1_Vidhi',
      name: 'Shannon Entropy Delta Reduction (ΔH <= 0)',
      passed: entropyValid,
      message: entropyValid ? `Entropy reduced by ${Math.abs(entropyDelta).toFixed(4)}` : 'Entropy increased (Noise detected)'
    });

    // Final Truth Score: T_final = Confidence * ( α * Cosine + (1 - α) * Sigmoid(-ΔH) )
    const sigmoidEntropy = 1 / (1 + Math.exp(entropyDelta));
    const truthScore = rawPayload.confidence * (this.ALPHA * cosineSim + (1 - this.ALPHA) * sigmoidEntropy);

    const scoreValid = truthScore >= this.MIN_TRUTH_SCORE;
    evaluations.push({
      sutraId: 'Sutra_3_2_Vidhi',
      name: 'Truth Score Threshold (T_final >= 0.85)',
      passed: scoreValid,
      message: scoreValid ? `Truth score ${truthScore.toFixed(4)} >= 0.85` : `Insufficient truth score (${truthScore.toFixed(4)})`
    });

    const overallPassed = evaluations.every(e => e.passed);

    return {
      overallPassed,
      canonicalJson,
      canonicalDigest,
      evaluations,
      truthScore,
      entropyDelta
    };
  }

  private static computeCosineSimilarity(a: number[], b: number[]): number {
    let dot = 0, normA = 0, normB = 0;
    for (let i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return normA === 0 || normB === 0 ? 0 : dot / (Math.sqrt(normA) * Math.sqrt(normB));
  }

  private static async sha256Hex(text: string): Promise<string> {
    const data = new TextEncoder().encode(text);
    const hash = await crypto.subtle.digest('SHA-256', data);
    return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
  }
}