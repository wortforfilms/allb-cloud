export interface SandhiResult {
  left_term: string;
  right_term: string;
  combined_form: string;
  sutra_applied: string;
  sutra_id: string;
  deterministic_pass: boolean;
  execution_cycles: number;
}

export interface SutraRecord {
  id: string;
  /** Devanagari text from the licensed source (see data/ashtadhyayi.json `source`). */
  sutra: string;
  /** null until the sutra is classified in data/ashtadhyayi-curated.json. */
  category: string | null;
  hardware_gate: string;
  /** Attribution for the sutra text. */
  source: string;
}

export interface HealthResult {
  status: "OK";
  service: string;
  environment: string;
}

export class BrahmiClient {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    if (!/^https?:\/\//.test(baseUrl)) {
      throw new Error("BrahmiClient requires an explicit absolute HTTP(S) base URL");
    }
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  health(): Promise<HealthResult> {
    return this.request<HealthResult>("/health");
  }

  evaluateSandhi(left: string, right: string): Promise<SandhiResult> {
    return this.request<SandhiResult>("/api/z0/sandhi", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ left, right }),
    });
  }

  async tokenizeBrahmi(text: string): Promise<string[]> {
    const result = await this.request<{ tokens: string[] }>("/api/z0/tokenize-brahmi", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    return result.tokens;
  }

  lookupSutra(sutraId: string): Promise<SutraRecord> {
    return this.request<SutraRecord>(`/api/z0/sutra/${encodeURIComponent(sutraId)}`);
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, init);
    const body: unknown = await response.json().catch(() => null);
    if (!response.ok) {
      const message = typeof body === "object" && body !== null && "error" in body
        ? String((body as { error: unknown }).error)
        : `HTTP ${response.status}: ${response.statusText}`;
      throw new Error(message);
    }
    return body as T;
  }
}
