# Consonant and visarga sandhi: reference model vs Vidyut

Agree: 1305 of 1314 word-boundary rules (vowel + vowel pairs are checked separately by tb_panini_datapath).

| First | Second | Vidyut | This model | Why |
| --- | --- | --- | --- | --- |
| fr | r | F r | fr | 6.3.111 lengthens only aṇ = अ इ उ (the earlier ण्, as everywhere except 1.1.69); Vidyut also lengthens ऋ |
| fs | r | F r | fr | same as above |
| t | Y | n Y | YY / jY | 8.4.40 makes त् + ञ into ज्ञ (or ञ्ञ by 8.4.45); Vidyut skips 8.4.40 here. No word begins with ञ |
| t | R | n R | RR / qR | 8.4.41 makes त् + ण into ड्ण (or ण्ण); Vidyut skips 8.4.41 here. No word begins with ण |
| n | l | Ml l | ~ll | Vidyut's extra 'Ml l' is a fallback for scripts without nasal vowels; its main entry ल्ँल agrees |
| n | S | c C | YS / YcC / YcS | Vidyut lists 'c C' (from its त् rules); with 8.3.31 शि तुक् the form is ञ्च्छ, keeping ञ्. Its other entry ञ्श agrees |
| n | h | d D | nh | Vidyut lists 'd D' (from its त् rules); 8.4.62 needs a झय् stop before ह, and न् is not one, so न् + ह stays |
| n | Y | n Y | YY | 8.4.40 makes न् + ञ into ञ्ञ; Vidyut keeps न्. No word begins with ञ |
| n | R | n R | RR | 8.4.41 makes न् + ण into ण्ण; Vidyut keeps न्. No word begins with ण |
