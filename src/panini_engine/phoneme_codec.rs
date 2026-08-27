/// देवनागरी स्ट्रिंग को 1-Byte ASCII (SLP1) मानक में बदलता है
pub fn devanagari_to_slp1(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let chars: Vec<char> = input.chars().collect();
    let len = chars.len();
    let mut i = 0;

    while i < len {
        let ch = chars[i];
        let next_ch = if i + 1 < len { Some(chars[i + 1]) } else { None };

        match ch {
            // स्वतंत्र स्वर (Independent Vowels)
            'अ' => out.push('a'), 'आ' => out.push('A'), 'इ' => out.push('i'), 'ई' => out.push('I'),
            'उ' => out.push('u'), 'ऊ' => out.push('U'), 'ऋ' => out.push('f'), 'ए' => out.push('e'),
            'ऐ' => out.push('E'), 'ओ' => out.push('o'), 'औ' => out.push('O'),

            // मात्राएँ (Vowel Signs)
            'ा' => out.push('A'), 'ि' => out.push('i'), 'ी' => out.push('I'), 'ु' => out.push('u'),
            'ू' => out.push('U'), 'ृ' => out.push('f'), 'े' => out.push('e'), 'ै' => out.push('E'),
            'ो' => out.push('o'), 'ौ' => out.push('O'),

            // हलन्त एवं अनुस्वार/विसर्ग
            '्' => {}, // हलन्त स्वतः 'a' को रोक देता है
            'ं' => out.push('M'), 'ः' => out.push('H'),

            // व्यंजन (हलन्त या मात्रा न होने पर अंतर्निहित 'a' जोड़ता है)
            _ if is_devanagari_consonant(ch) => {
                out.push_str(dev_consonant_to_slp1(ch));

                let has_virama_or_matra = match next_ch {
                    Some(n) => n == '्' || is_devanagari_matra(n),
                    None => false,
                };

                if !has_virama_or_matra {
                    out.push('a');
                }
            }

            _ => out.push(ch),
        }
        i += 1;
    }

    out
}

/// 1-Byte ASCII (SLP1) परिणाम को पुनः शुद्ध देवनागरी (UTF-8) में बदलता है
pub fn slp1_to_devanagari(input: &str) -> String {
    let mut out = String::with_capacity(input.len() * 3);
    let mut prev_was_consonant = false;

    for ch in input.chars() {
        if is_slp1_vowel(ch) {
            if prev_was_consonant {
                if ch != 'a' {
                    out.push_str(slp1_vowel_to_matra(ch));
                }
            } else {
                out.push_str(slp1_vowel_to_independent(ch));
            }
            prev_was_consonant = false;
        } else if is_slp1_consonant(ch) {
            if prev_was_consonant {
                out.push('्');
            }
            out.push_str(slp1_consonant_to_dev(ch));
            prev_was_consonant = true;
        } else {
            if prev_was_consonant && ch == 'M' {
                out.push('ं');
            } else if prev_was_consonant && ch == 'H' {
                out.push('ः');
            } else {
                out.push(ch);
            }
            prev_was_consonant = false;
        }
    }

    out
}

fn is_devanagari_consonant(c: char) -> bool {
    matches!(c, 'क'..='ङ' | 'च'..='ञ' | 'ट'..='ण' | 'त'..='न' | 'प'..='म' | 'य' | 'र' | 'ल' | 'व' | 'श' | 'ष' | 'स' | 'ह')
}

fn is_devanagari_matra(c: char) -> bool {
    matches!(c, 'ा' | 'ि' | 'ी' | 'ु' | 'ू' | 'ृ' | 'े' | 'ै' | 'ो' | 'ौ')
}

fn dev_consonant_to_slp1(c: char) -> &'static str {
    match c {
        'क' => "k", 'ख' => "K", 'ग' => "g", 'घ' => "G", 'ङ' => "N",
        'च' => "c", 'छ' => "C", 'ज' => "j", 'झ' => "J", 'ञ' => "Y",
        'ट' => "w", 'ठ' => "W", 'ड' => "q", 'ढ' => "Q", 'ण' => "R",
        'त' => "t", 'थ' => "T", 'द' => "d", 'ध' => "D", 'न' => "n",
        'प' => "p", 'फ' => "P", 'ब' => "b", 'भ' => "B", 'म' => "m",
        'य' => "y", 'र' => "r", 'ल' => "l", 'व' => "v",
        'श' => "S", 'ष' => "z", 'स' => "s", 'ह' => "h",
        _ => "",
    }
}

fn is_slp1_vowel(c: char) -> bool {
    matches!(c, 'a' | 'A' | 'i' | 'I' | 'u' | 'U' | 'f' | 'e' | 'E' | 'o' | 'O')
}

fn is_slp1_consonant(c: char) -> bool {
    matches!(c, 'k'|'K'|'g'|'G'|'N'|'c'|'C'|'j'|'J'|'Y'|'w'|'W'|'q'|'Q'|'R'|'t'|'T'|'d'|'D'|'n'|'p'|'P'|'b'|'B'|'m'|'y'|'r'|'l'|'v'|'S'|'z'|'s'|'h')
}

fn slp1_vowel_to_independent(c: char) -> &'static str {
    match c {
        'a' => "अ", 'A' => "आ", 'i' => "इ", 'I' => "ई", 'u' => "उ", 'U' => "ऊ",
        'f' => "ऋ", 'e' => "ए", 'E' => "ऐ", 'o' => "ओ", 'O' => "औ",
        _ => "",
    }
}

fn slp1_vowel_to_matra(c: char) -> &'static str {
    match c {
        'A' => "ा", 'i' => "ि", 'I' => "ी", 'u' => "ु", 'U' => "ू",
        'f' => "ृ", 'e' => "े", 'E' => "ै", 'o' => "ो", 'O' => "ौ",
        _ => "",
    }
}

fn slp1_consonant_to_dev(c: char) -> &'static str {
    match c {
        'k' => "क", 'K' => "ख", 'g' => "ग", 'G' => "घ", 'N' => "ङ",
        'c' => "च", 'C' => "छ", 'j' => "ज", 'J' => "झ", 'Y' => "ञ",
        'w' => "ट", 'W' => "ठ", 'q' => "ड", 'Q' => "ढ", 'R' => "ण",
        't' => "त", 'T' => "थ", 'd' => "द", 'D' => "ध", 'n' => "न",
        'p' => "प", 'P' => "फ", 'b' => "ब", 'B' => "भ", 'm' => "म",
        'y' => "य", 'r' => "र", 'l' => "ल", 'v' => "व",
        'S' => "श", 'z' => "ष", 's' => "स", 'h' => "ह",
        _ => "",
    }
}