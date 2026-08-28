use std::collections::HashMap;

pub struct BrahmiScriptTokenizer {
    vocab: HashMap<String, usize>,
    embedding_dim: usize,
}

impl BrahmiScriptTokenizer {
    pub fn new(embedding_dim: usize) -> Self {
        let mut vocab = HashMap::new();
        let mut idx = 0;

        // Base Brahmi Unicode Block (U+11000 - U+1107F)
        for cp in 0x11000..=0x1107F {
            if let Some(ch) = std::char::from_u32(cp) {
                vocab.insert(ch.to_string(), idx);
                idx += 1;
            }
        }
        vocab.insert("[UNK]".to_string(), idx);

        Self {
            vocab,
            embedding_dim,
        }
    }

    pub fn tokenize(&self, text: &str) -> Vec<String> {
        let mut tokens = Vec::new();
        let mut cluster = String::new();

        for ch in text.chars() {
            let cp = ch as u32;
            if (0x11013..=0x11038).contains(&cp) || (0x11005..=0x11012).contains(&cp) {
                if !cluster.is_empty() {
                    tokens.push(cluster.clone());
                }
                cluster = ch.to_string();
            } else if (0x11038..=0x11047).contains(&cp) {
                cluster.push(ch);
            } else {
                if !cluster.is_empty() {
                    tokens.push(cluster.clone());
                    cluster.clear();
                }
                tokens.push(ch.to_string());
            }
        }
        if !cluster.is_empty() {
            tokens.push(cluster);
        }
        tokens
    }

    pub fn tokens_to_embedding(&self, tokens: &[String]) -> Vec<f32> {
        let mut embedding = vec![0.0f32; self.embedding_dim];
        for (i, token) in tokens.iter().enumerate() {
            let token_id = *self
                .vocab
                .get(token)
                .unwrap_or(self.vocab.get("[UNK]").unwrap_or(&0));
            let slot = i % self.embedding_dim;
            embedding[slot] += (token_id as f32) / 256.0f32;
        }
        embedding
    }

    pub fn is_ancient_sovereign_script(c: char) -> bool {
        matches!(c,
            '\u{11000}'..='\u{1107F}' | // Brahmi (11000–1107F)
            '\u{10A00}'..='\u{10A5F}' | // Kharosthi (10A00–10A5F)
            '\u{11580}'..='\u{115FF}'   // Siddham (11580–115FF)
        )
    }
}
