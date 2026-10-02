import { describe, it, expect } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";

// Checks data/ashtadhyayi.json itself (no WASM build needed). build.rs refuses the same
// problems at compile time; this test explains them faster.
const root = path.resolve(__dirname, "..");
const data = JSON.parse(fs.readFileSync(path.join(root, "data/ashtadhyayi.json"), "utf8"));
const byId = new Map<string, any>(data.sutras.map((s: any) => [s.id, s]));

describe("Ashtadhyayi dataset", () => {
  it("names a licensed source", () => {
    expect(data.source.license).toBe("MIT");
    expect(data.source.url).toBe("https://github.com/ambuda-org/vidyut");
    expect(fs.existsSync(path.join(root, data.source.license_file))).toBe(true);
  });

  it("has all 3,983 sutras, in order, in 32 padas", () => {
    expect(data.total_sutras).toBe(3983);
    expect(data.sutras.length).toBe(3983);
    const perPada = new Map<string, number[]>();
    for (const s of data.sutras) {
      const key = `${s.chapter}.${s.pada}`;
      if (!perPada.has(key)) perPada.set(key, []);
      perPada.get(key)!.push(s.number);
      expect(s.id).toBe(`${s.chapter}.${s.pada}.${s.number}`);
    }
    expect(perPada.size).toBe(32);
    for (const nums of perPada.values()) {
      expect(nums).toEqual(nums.map((_, i) => i + 1));
    }
    expect(perPada.get("1.1")!.length).toBe(75);
    expect(perPada.get("8.4")!.length).toBe(68);
  });

  it("has no placeholder text", () => {
    for (const s of data.sutras) {
      expect(s.sutra).not.toMatch(/अष्टाध्यायी सूत्र|पदपाठ|[0-9A-Za-z]/);
      expect(s.slp1.length).toBeGreaterThan(0);
      if (s.arth_hindi) expect(s.arth_hindi).not.toMatch(/का पाणिनीय अर्थ एवं नियम विनिर्देश/);
    }
  });

  it("reads known sutras correctly", () => {
    const known: Record<string, string> = {
      "1.1.1": "वृद्धिरादैच्",
      "1.1.2": "अदेङ् गुणः",
      "1.1.3": "इको गुणवृद्धी",
      "1.1.68": "स्वं रूपं शब्दस्याशब्दसंज्ञा",
      "1.4.54": "स्वतन्त्रः कर्ता",
      "3.1.1": "प्रत्ययः",
      "6.1.77": "इको यणचि",
      "6.1.87": "आद्गुणः",
      "6.1.101": "अकः सवर्णे दीर्घः",
      "8.4.40": "स्तोः श्चुना श्चुः",
      "8.4.68": "अ अ",
    };
    for (const [id, text] of Object.entries(known)) expect(byId.get(id)?.sutra, id).toBe(text);
    expect(byId.has("1.1.101")).toBe(false);
  });

  it("cites only sutras that exist from the Rust sources", () => {
    const cited = new Set<string>();
    const walk = (dir: string) => {
      for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, f.name);
        if (f.isDirectory()) walk(p);
        else if (f.name.endsWith(".rs"))
          // Unit tests (after #[cfg(test)]) may name missing sutras on purpose.
          for (const m of fs.readFileSync(p, "utf8").split("#[cfg(test)]")[0].matchAll(/(?:sutra_id|id):\s*"([1-8]\.[1-4]\.\d+)"/g)) cited.add(m[1]);
      }
    };
    walk(path.join(root, "src"));
    expect(cited.size).toBeGreaterThan(0);
    for (const id of cited) expect(byId.has(id), id).toBe(true);
  });

  it("classifies only curated sutras", () => {
    const classified = data.sutras.filter((s: any) => s.category);
    expect(classified.length).toBeLessThan(50);
    expect(byId.get("1.1.1").category).toBe("संज्ञा (Saṁjñā)");
    expect(byId.get("8.4.68").category).toBeNull();
  });
});
