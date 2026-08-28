import React, { useState, useEffect, useCallback } from "react";

// ============================================================================
// TypeScript Interfaces for brahmi.allb.xyz API
// ============================================================================

export interface SandhiTrace {
  sutra_id: string;
  gate_triggered: string;
  sthani: string;
  adesha: string;
  result_form_devanagari: string;
}

export interface SandhiResponse {
  original_left: string;
  original_right: string;
  combined_form: string;
  trace?: SandhiTrace;
}

export interface SutraResponse {
  id: string;
  sutra: string;
  category: string;
  hardware_gate: string;
  error?: string;
}

export interface BrahmiResponse {
  tokens: string[];
}

export interface HealthResponse {
  status: string;
  service: string;
  environment: string;
}

export interface Z0SovereignBarProps {
  apiBaseUrl: string;
}

// ============================================================================
// Main Component
// ============================================================================

export const Z0SovereignBar: React.FC<Z0SovereignBarProps> = ({ apiBaseUrl }) => {
  const normalizedApiBaseUrl = apiBaseUrl.replace(/\/$/, "");
  // Navigation / Mode state
  const [activeTab, setActiveTab] = useState<"sandhi" | "sutra" | "brahmi">("sandhi");

  // Health State
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [isHealthLoading, setIsHealthLoading] = useState<boolean>(true);

  // Sandhi State
  const [leftWord, setLeftWord] = useState<string>("यदि");
  const [rightWord, setRightWord] = useState<string>("अपि");
  const [sandhiResult, setSandhiResult] = useState<SandhiResponse | null>(null);
  const [isSandhiLoading, setIsSandhiLoading] = useState<boolean>(false);
  const [sandhiLatency, setSandhiLatency] = useState<number | null>(null);

  // Sutra Lookup State
  const [sutraId, setSutraId] = useState<string>("1.1.1");
  const [sutraResult, setSutraResult] = useState<SutraResponse | null>(null);
  const [isSutraLoading, setIsSutraLoading] = useState<boolean>(false);

  // Brahmi State
  const [brahmiInput, setBrahmiInput] = useState<string>("𑀅𑀆𑀇𑀈");
  const [brahmiResult, setBrahmiResult] = useState<BrahmiResponse | null>(null);
  const [isBrahmiLoading, setIsBrahmiLoading] = useState<boolean>(false);

  // Global Error State
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // --------------------------------------------------------------------------
  // Fetch Edge Health Status
  // --------------------------------------------------------------------------
  const checkHealth = useCallback(async () => {
    setIsHealthLoading(true);
    try {
      const res = await fetch(`${normalizedApiBaseUrl}/health`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: HealthResponse = await res.json();
      setHealth(data);
    } catch (err: any) {
      setHealth(null);
      console.error("Health check failed:", err);
    } finally {
      setIsHealthLoading(false);
    }
  }, [normalizedApiBaseUrl]);

  useEffect(() => {
    checkHealth();
  }, [checkHealth]);

  // --------------------------------------------------------------------------
  // Execute Sandhi Transform Gate
  // --------------------------------------------------------------------------
  const handleExecuteSandhi = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!leftWord.trim() || !rightWord.trim()) return;

    setIsSandhiLoading(true);
    setErrorMessage(null);
    const startTime = performance.now();

    try {
      const res = await fetch(`${normalizedApiBaseUrl}/api/z0/sandhi`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ left: leftWord.trim(), right: rightWord.trim() }),
      });

      if (!res.ok) throw new Error(`Sandhi Execution Error: HTTP ${res.status}`);
      const data: SandhiResponse = await res.json();
      setSandhiResult(data);
      setSandhiLatency(Math.round(performance.now() - startTime));
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to execute Sandhi transform");
      setSandhiResult(null);
    } finally {
      setIsSandhiLoading(false);
    }
  };

  // --------------------------------------------------------------------------
  // Execute O(1) Sutra Lookup
  // --------------------------------------------------------------------------
  const handleLookupSutra = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!sutraId.trim()) return;

    setIsSutraLoading(true);
    setErrorMessage(null);

    try {
      const res = await fetch(`${normalizedApiBaseUrl}/api/z0/sutra/${encodeURIComponent(sutraId.trim())}`);
      if (!res.ok) {
        if (res.status === 404) {
          throw new Error(`सूत्र '${sutraId}' PHF टेबल में नहीं मिला।`);
        }
        throw new Error(`Sutra Lookup Error: HTTP ${res.status}`);
      }
      const data: SutraResponse = await res.json();
      setSutraResult(data);
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to lookup Sutra");
      setSutraResult(null);
    } finally {
      setIsSutraLoading(false);
    }
  };

  // --------------------------------------------------------------------------
  // Execute Brahmi Tokenizer
  // --------------------------------------------------------------------------
  const handleTokenizeBrahmi = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!brahmiInput.trim()) return;

    setIsBrahmiLoading(true);
    setErrorMessage(null);

    try {
      const res = await fetch(`${normalizedApiBaseUrl}/api/z0/tokenize-brahmi`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: brahmiInput }),
      });

      if (!res.ok) throw new Error(`Brahmi Tokenizer Error: HTTP ${res.status}`);
      const data: BrahmiResponse = await res.json();
      setBrahmiResult(data);
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to tokenize Brahmi text");
      setBrahmiResult(null);
    } finally {
      setIsBrahmiLoading(false);
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto my-6 bg-slate-900 border border-slate-800 rounded-xl shadow-2xl font-sans text-slate-100 overflow-hidden">
      {/* ------------------- HEADER & HEALTH BADGE ------------------- */}
      <div className="flex flex-wrap items-center justify-between px-6 py-4 bg-slate-950/80 border-b border-slate-800">
        <div className="flex items-center space-x-3">
          <div className="w-3 h-3 rounded-full bg-emerald-500 animate-pulse" />
          <h2 className="text-lg font-bold tracking-wide text-slate-100">
            MAATAA <span className="text-amber-400 font-mono text-xs px-2 py-0.5 rounded bg-amber-400/10 border border-amber-400/20">Z0-VESP ENGINE</span>
          </h2>
        </div>

        {/* Edge Node Health Status */}
        <div className="flex items-center space-x-2 text-xs font-mono">
          <span className="text-slate-400">Node:</span>
          {isHealthLoading ? (
            <span className="text-slate-500 animate-pulse">Connecting...</span>
          ) : health ? (
            <span className="px-2 py-1 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
              {health.service} / {health.environment} [{health.status}]
            </span>
          ) : (
            <span className="px-2 py-1 rounded bg-rose-500/10 text-rose-400 border border-rose-500/30">
              OFFLINE
            </span>
          )}
        </div>
      </div>

      {/* ------------------- TAB NAVIGATION ------------------- */}
      <div className="flex border-b border-slate-800 bg-slate-900/50">
        <button
          onClick={() => { setActiveTab("sandhi"); setErrorMessage(null); }}
          className={`flex-1 py-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === "sandhi"
              ? "border-amber-400 text-amber-400 bg-amber-400/5"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          1-Byte Sandhi Gate
        </button>
        <button
          onClick={() => { setActiveTab("sutra"); setErrorMessage(null); }}
          className={`flex-1 py-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === "sutra"
              ? "border-amber-400 text-amber-400 bg-amber-400/5"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          O(1) Sutra Lookup
        </button>
        <button
          onClick={() => { setActiveTab("brahmi"); setErrorMessage(null); }}
          className={`flex-1 py-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === "brahmi"
              ? "border-amber-400 text-amber-400 bg-amber-400/5"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          Brahmi Tokenizer
        </button>
      </div>

      {/* ------------------- ERROR BANNER ------------------- */}
      {errorMessage && (
        <div className="px-6 py-3 bg-rose-500/10 border-b border-rose-500/20 text-rose-300 text-xs font-mono">
          ⚠️ {errorMessage}
        </div>
      )}

      {/* ------------------- TAB 1: SANDHI GATE ------------------- */}
      {activeTab === "sandhi" && (
        <div className="p-6 space-y-6">
          <form onSubmit={handleExecuteSandhi} className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1">पूर्व पद (Left Word)</label>
              <input
                type="text"
                value={leftWord}
                onChange={(e) => setLeftWord(e.target.value)}
                placeholder="उदा. यदि"
                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-slate-100 focus:outline-none focus:border-amber-400 font-serif"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1">उत्तर पद (Right Word)</label>
              <input
                type="text"
                value={rightWord}
                onChange={(e) => setRightWord(e.target.value)}
                placeholder="उदा. अपि"
                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-slate-100 focus:outline-none focus:border-amber-400 font-serif"
              />
            </div>
            <div className="flex items-end">
              <button
                type="submit"
                disabled={isSandhiLoading}
                className="w-full py-2 px-4 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold rounded-lg transition shadow-lg shadow-amber-500/10 disabled:opacity-50"
              >
                {isSandhiLoading ? "Executing Gate..." : "Transform Sandhi"}
              </button>
            </div>
          </form>

          {/* Preset Quick Actions */}
          <div className="flex flex-wrap gap-2 text-xs">
            <span className="text-slate-500 self-center">Presets:</span>
            {[
              { l: "यदि", r: "अपि", label: "यण् (यद्यपि)" },
              { l: "नर", r: "इन्द्र", label: "गुण (नरेन्द्र)" },
              { l: "ने", r: "अन", label: "अयादि (नयन)" },
              { l: "एक", r: "एक", label: "वृद्धि (एकैक)" },
              { l: "सत्", r: "चित्", label: "श्चुत्व (सच्चित)" },
              { l: "मनः", r: "हर", label: "उत्व (मनोहर)" },
            ].map((p, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => { setLeftWord(p.l); setRightWord(p.r); }}
                className="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded border border-slate-700 font-serif"
              >
                {p.label}
              </button>
            ))}
          </div>

          {/* Sandhi Result Display */}
          {sandhiResult && (
            <div className="p-4 bg-slate-950/70 border border-slate-800 rounded-lg space-y-3 font-mono">
              <div className="flex items-center justify-between text-xs text-slate-400 border-b border-slate-800 pb-2">
                <span>EXECUTION_GATE_RESULT</span>
                {sandhiLatency !== null && (
                  <span className="text-emerald-400">Latency: {sandhiLatency}ms</span>
                )}
              </div>
              <div className="flex items-baseline space-x-3">
                <span className="text-slate-400 text-sm">Combined Form:</span>
                <span className="text-2xl font-bold text-amber-300 font-serif">{sandhiResult.combined_form}</span>
              </div>

              {sandhiResult.trace && (
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2 pt-2 text-xs border-t border-slate-800/60">
                  <div>
                    <span className="text-slate-500 block">Sutra ID</span>
                    <span className="text-slate-200">{sandhiResult.trace.sutra_id}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block">Gate Type</span>
                    <span className="text-amber-400 font-bold">{sandhiResult.trace.gate_triggered}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block">स्थानिन् (Sthani)</span>
                    <span className="text-slate-200">{sandhiResult.trace.sthani}</span>
                  </div>
                  <div>
                    <span className="text-slate-500 block">आदेश (Adesha)</span>
                    <span className="text-slate-200">{sandhiResult.trace.adesha}</span>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* ------------------- TAB 2: SUTRA LOOKUP ------------------- */}
      {activeTab === "sutra" && (
        <div className="p-6 space-y-6">
          <form onSubmit={handleLookupSutra} className="flex gap-4">
            <div className="flex-1">
              <label className="block text-xs font-medium text-slate-400 mb-1">अष्टाध्यायी सूत्र क्रमांक (Sutra ID)</label>
              <input
                type="text"
                value={sutraId}
                onChange={(e) => setSutraId(e.target.value)}
                placeholder="उदा. 1.1.1, 1.1.2, 6.1.77"
                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-slate-100 focus:outline-none focus:border-amber-400 font-mono"
              />
            </div>
            <div className="flex items-end">
              <button
                type="submit"
                disabled={isSutraLoading}
                className="py-2 px-6 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold rounded-lg transition shadow-lg shadow-amber-500/10 disabled:opacity-50"
              >
                {isSutraLoading ? "Searching..." : "Lookup O(1)"}
              </button>
            </div>
          </form>

          {sutraResult && (
            <div className="p-4 bg-slate-950/70 border border-slate-800 rounded-lg space-y-3 font-mono">
              <div className="flex items-center justify-between text-xs text-slate-400 border-b border-slate-800 pb-2">
                <span>PHF_HASH_MATCH_FOUND</span>
                <span className="text-amber-400">ID: {sutraResult.id}</span>
              </div>
              <div className="flex items-baseline space-x-3">
                <span className="text-slate-400 text-sm">सूत्र (Sutra):</span>
                <span className="text-2xl font-bold text-amber-300 font-serif">{sutraResult.sutra}</span>
              </div>
              <div className="grid grid-cols-2 gap-2 pt-2 text-xs border-t border-slate-800/60">
                <div>
                  <span className="text-slate-500 block">Category</span>
                  <span className="text-slate-200">{sutraResult.category}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Hardware Gate</span>
                  <span className="text-emerald-400 font-bold">{sutraResult.hardware_gate}</span>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ------------------- TAB 3: BRAHMI TOKENIZER ------------------- */}
      {activeTab === "brahmi" && (
        <div className="p-6 space-y-6">
          <form onSubmit={handleTokenizeBrahmi} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1">ब्राह्मी लिपि टेक्स्ट (Brahmi Unicode Input)</label>
              <input
                type="text"
                value={brahmiInput}
                onChange={(e) => setBrahmiInput(e.target.value)}
                placeholder="𑀅𑀆𑀇𑀈"
                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-slate-100 focus:outline-none focus:border-amber-400 font-serif text-lg"
              />
            </div>
            <button
              type="submit"
              disabled={isBrahmiLoading}
              className="w-full py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold rounded-lg transition shadow-lg shadow-amber-500/10 disabled:opacity-50"
            >
              {isBrahmiLoading ? "Tokenizing..." : "Tokenize Brahmi Script"}
            </button>
          </form>

          {brahmiResult && (
            <div className="p-4 bg-slate-950/70 border border-slate-800 rounded-lg space-y-3 font-mono">
              <div className="text-xs text-slate-400 border-b border-slate-800 pb-2">
                TOKEN_ARRAY_OUTPUT (Count: {brahmiResult.tokens.length})
              </div>
              <div className="flex flex-wrap gap-2 pt-1">
                {brahmiResult.tokens.map((token, index) => (
                  <span
                    key={index}
                    className="px-3 py-1.5 bg-slate-900 border border-amber-400/30 rounded-md text-amber-300 text-xl font-serif shadow-sm"
                  >
                    {token}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default Z0SovereignBar;
