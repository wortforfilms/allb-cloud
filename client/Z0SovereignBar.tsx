import React, { useEffect, useState } from "react";

interface Z0Metadata {
  utf8Script: string;
  confidenceScore: number;
  vocalFrequencyRange: [number, number];
  shiftStatus: string;
  zoneHash: string;
}

export const Z0SovereignBar: React.FC = () => {
  const [metadata, setMetadata] = useState<Z0Metadata | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 1. Fetch metadata headers or .z0.json endpoint
    const hostname = window.location.hostname;
    const subdomain = hostname.split(".")[0];

    fetch(`/.well-known/${subdomain}.z0.json`)
      .then((res) => {
        if (!res.ok) throw new Error("Metadata unreachable");
        return res.json();
      })
      .then((data) => {
        setMetadata({
          utf8Script: data.brahmi_phonetic_metadata.utf8_script,
          confidenceScore: data.observational_truth_vectors[0]?.confidence_score || 0.0,
          vocalFrequencyRange: data.brahmi_phonetic_metadata.vocal_frequency_hz_range,
          shiftStatus: data.z0_genesis.epistemological_shift_status,
          zoneHash: data.bdns_record.zone_hash,
        });
      })
      .catch((err) => setError(err.message));
  }, []);

  if (error) return null; // Fallback to standard web render if not Z0-anchored
  if (!metadata) return <div style={styles.loading}>Resolving B-DNS Truth Vector...</div>;

  const isVerified = metadata.confidenceScore >= 0.85;

  return (
    <div style={styles.headerContainer}>
      <div style={styles.leftSection}>
        <span style={styles.brahmiGlyph}>{metadata.utf8Script}</span>
        <span style={styles.divider}>|</span>
        <span style={styles.fqdn}>{window.location.hostname}</span>
      </div>

      <div style={styles.centerSection}>
        <span style={{ ...styles.badge, backgroundColor: isVerified ? "#00c853" : "#ffd600" }}>
          {isVerified ? "✓ Z0 VERIFIED" : "⚠ PENDING VERIFICATION"} ({metadata.confidenceScore * 100}%)
        </span>
        <span style={styles.freqTag}>
          ⚡ {metadata.vocalFrequencyRange[0]}-{metadata.vocalFrequencyRange[1]} Hz
        </span>
      </div>

      <div style={styles.rightSection}>
        <span style={styles.hashTag} title={metadata.zoneHash}>
          🛡️ {metadata.zoneHash.substring(0, 10)}...
        </span>
      </div>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  headerContainer: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "8px 16px",
    backgroundColor: "#0a0a0c",
    color: "#ffffff",
    fontFamily: "monospace",
    fontSize: "13px",
    borderBottom: "1px solid #1a1a24",
    position: "sticky",
    top: 0,
    zIndex: 99999,
  },
  leftSection: { display: "flex", alignItems: "center", gap: "8px" },
  brahmiGlyph: { fontSize: "18px", color: "#00e5ff", fontWeight: "bold" },
  divider: { color: "#333344" },
  fqdn: { color: "#aaaabb" },
  centerSection: { display: "flex", alignItems: "center", gap: "12px" },
  badge: { padding: "2px 8px", borderRadius: "4px", color: "#000", fontWeight: "bold", fontSize: "11px" },
  freqTag: { color: "#b388ff", fontSize: "12px" },
  rightSection: { display: "flex", alignItems: "center" },
  hashTag: { color: "#666677", fontSize: "11px", cursor: "pointer" },
  loading: { padding: "8px", background: "#0a0a0c", color: "#666", fontSize: "12px" },
};