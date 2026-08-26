// ============================================================================
// API RESPONSE INTERFACES
// ============================================================================

export interface DerivationStep {
  step_number: number;
  rule_applied: string;
  intermediate_form: string;
}

export interface DerivationResult {
  original_form: string;
  final_form: string;
  derivation_history: DerivationStep[];
  execution_microseconds: number;
}

export interface SutraRecord {
  id: string;
  text: string;
  transliteration: string;
  sutra_type: string;
}

export interface ApiResponse<T> {
  success: boolean;
  error?: string;
  derivation?: T extends DerivationResult ? T : never;
  tokens?: T extends number[] ? T : never;
  sutra?: T extends SutraRecord ? T : never;
}

// ============================================================================
// BRAHMI WASM CLIENT CLASS
// ============================================================================

export class BrahmiClient {
  private baseUrl: string;

  constructor(baseUrl: string = "https://brahmi.allb.xyz") {
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  private async request<T>(payload: object): Promise<T> {
    const response = await fetch(this.baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      if (response.status === 429) {
        throw new Error("Rate limit exceeded. Please wait before retrying.");
      }
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * Executes native Rust Panini Engine rule evaluation via WASM on the edge.
   */
  async evaluateSandhi(baseTerm: string, pratyaya: string): Promise<DerivationResult> {
    const res = await this.request<{ success: boolean; derivation: DerivationResult }>({
      action: "evaluate",
      base_term: baseTerm,
      pratyaya: pratyaya,
    });
    return res.derivation;
  }

  /**
   * Tokenizes Brahmi script text using WASM Zero-Copy memory mapping.
   */
  async tokenizeBrahmi(text: string): Promise<number[]> {
    const res = await this.request<{ success: boolean; tokens: number[] }>({
      action: "tokenize",
      text: text,
    });
    return res.tokens;
  }

  /**
   * Performs an O(1) constant-time lookup for an Ashtadhyayi Sutra using static PHF maps.
   */
  async lookupSutra(sutraId: string): Promise<SutraRecord> {
    const res = await this.request<{ success: boolean; sutra: SutraRecord }>({
      action: "lookup",
      sutra_id: sutraId,
    });
    return res.sutra;
  }
}

// Export singleton instance for app-wide use
export const brahmiApi = new BrahmiClient();