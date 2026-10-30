"""
Brahmi Script Tokenizer Engine for Maataa Sovereign AI Runtime
Unicode Range: U+11000 - U+1107F

Python mirror of the canonical Rust tokenizer in src/brahmi_tokenizer.rs
(ADR 0002). Segmentation must match tests/fixtures/brahmi_aksharas.json;
change the Rust module and the fixture first, then this file.
"""

import re
from typing import List, Dict, Any

class BrahmiScriptTokenizer:
    # Character Classes
    VOWELS = set(range(0x11005, 0x11013))
    CONSONANTS = set(range(0x11013, 0x11038))
    VOWEL_SIGNS = set(range(0x11038, 0x11047))
    VIRAMA = 0x11046
    # Candrabindu, anusvara and visarga attach to the preceding akshara.
    VARIOUS_SIGNS = set(range(0x11000, 0x11003))
    NUMERALS = set(range(0x11066, 0x11070))

    def __init__(self):
        self.vocab: Dict[str, int] = {}
        self.inv_vocab: Dict[int, str] = {}
        self._build_base_vocabulary()

    def _build_base_vocabulary(self):
        """Initializes vocabulary mapping for all standard Brahmi characters."""
        idx = 0
        for cp in range(0x11000, 0x11080):
            char = chr(cp)
            self.vocab[char] = idx
            self.inv_vocab[idx] = char
            idx += 1
        
        # Add Special Control Tokens
        self.vocab["[PAD]"] = idx; idx += 1
        self.vocab["[UNK]"] = idx; idx += 1
        self.vocab["[BOS]"] = idx; idx += 1
        self.vocab["[EOS]"] = idx; idx += 1

    def tokenize(self, text: str) -> List[str]:
        """Splits Brahmi text into grapheme clusters (Aksharas)."""
        tokens = []
        current_cluster = ""
        
        for char in text:
            cp = ord(char)
            # Check if character belongs to Brahmi block
            if 0x11000 <= cp <= 0x1107F:
                if cp in self.CONSONANTS or cp in self.VOWELS:
                    if current_cluster:
                        tokens.append(current_cluster)
                    current_cluster = char
                elif cp in self.VOWEL_SIGNS or cp == self.VIRAMA or cp in self.VARIOUS_SIGNS:
                    current_cluster += char
                else:
                    if current_cluster:
                        tokens.append(current_cluster)
                        current_cluster = ""
                    tokens.append(char)
            else:
                if current_cluster:
                    tokens.append(current_cluster)
                    current_cluster = ""
                tokens.append(char)

        if current_cluster:
            tokens.append(current_cluster)

        return tokens

    def encode(self, text: str) -> List[int]:
        """Converts Brahmi text string into token IDs."""
        # The vocabulary holds single code points; a multi-code-point akshara
        # is encoded as its code points so that decode() round-trips.
        ids: List[int] = []
        for token in self.tokenize(text):
            if token in self.vocab:
                ids.append(self.vocab[token])
            else:
                ids.extend(self.vocab.get(ch, self.vocab["[UNK]"]) for ch in token)
        return ids

    def decode(self, token_ids: List[int]) -> str:
        """Converts token IDs back to text string."""
        return "".join([self.inv_vocab.get(tid, "") for tid in token_ids])

# Quick Unit Test
if __name__ == "__main__":
    tokenizer = BrahmiScriptTokenizer()
    sample_brahmi = "𑀮𑀺𑀧𑀺"  # 'Lipi' in Brahmi script
    tokens = tokenizer.tokenize(sample_brahmi)
    encoded = tokenizer.encode(sample_brahmi)
    decoded = tokenizer.decode(encoded)
    
    print(f"Sample Input: {sample_brahmi}")
    print(f"Tokens (Aksharas): {tokens}")
    print(f"Encoded IDs: {encoded}")
    print(f"Decoded Text: {decoded}")
    assert decoded == sample_brahmi, "Decode mismatch!"
    print("Tokenizer Test Passed!")