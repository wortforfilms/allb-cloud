use flate2::write::GzEncoder;
use flate2::Compression;
use serde::Deserialize;
use std::env;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::Path;

#[derive(Deserialize, Debug)]
struct SutraItem {
    id: String,
    sutra: String,
    slp1: Option<String>,
    category: Option<String>,
    hardware_gate: Option<String>,
}

#[derive(Deserialize, Debug)]
struct SutraSource {
    license: String,
    url: String,
}

#[derive(Deserialize, Debug)]
struct SutraDataset {
    total_sutras: usize,
    source: Option<SutraSource>,
    sutras: Vec<SutraItem>,
}

/// Number of sutras in the source edition (data/sources/vidyut/sutrapatha.tsv).
const EXPECTED_SUTRAS: usize = 3983;

/// Refuses to build from an incomplete, renumbered or placeholder dataset.
/// Regenerate it with `python3 scripts/build_ashtadhyayi.py`.
fn validate(dataset: &SutraDataset) -> Result<(), String> {
    let source = dataset
        .source
        .as_ref()
        .ok_or("no `source` block: the dataset must name its licensed source")?;
    if source.license.trim().is_empty() || source.url.trim().is_empty() {
        return Err("`source.license` and `source.url` must be filled in".into());
    }
    if dataset.sutras.len() != EXPECTED_SUTRAS || dataset.total_sutras != EXPECTED_SUTRAS {
        return Err(format!(
            "expected {} sutras, found {} (total_sutras says {})",
            EXPECTED_SUTRAS,
            dataset.sutras.len(),
            dataset.total_sutras
        ));
    }
    let mut seen = std::collections::HashSet::new();
    let mut last: (u32, u32, u32) = (0, 0, 0);
    for item in &dataset.sutras {
        let parts: Vec<u32> = item
            .id
            .split('.')
            .map(|p| p.parse::<u32>())
            .collect::<Result<_, _>>()
            .map_err(|_| format!("bad sutra id {:?}", item.id))?;
        if parts.len() != 3 || !(1..=8).contains(&parts[0]) || !(1..=4).contains(&parts[1]) {
            return Err(format!("bad sutra id {:?}", item.id));
        }
        let here = (parts[0], parts[1], parts[2]);
        let next_in_pada = here.0 == last.0 && here.1 == last.1 && here.2 == last.2 + 1;
        let starts_pada = here.2 == 1 && (here.0, here.1) > (last.0, last.1);
        if !(next_in_pada || starts_pada) || !seen.insert(item.id.clone()) {
            return Err(format!(
                "sutra {} is out of order after {}.{}.{}",
                item.id, last.0, last.1, last.2
            ));
        }
        last = here;
        let text = item.sutra.trim();
        let placeholder = text.is_empty()
            || text.contains("अष्टाध्यायी सूत्र")
            || text.contains("पदपाठ")
            || text.chars().any(|c| c.is_ascii_alphanumeric());
        if placeholder {
            return Err(format!(
                "sutra {} has placeholder text: {:?}",
                item.id, text
            ));
        }
        if item.slp1.as_deref().map(str::trim).unwrap_or("").is_empty() {
            return Err(format!("sutra {} has no source text (slp1)", item.id));
        }
    }
    Ok(())
}

fn main() {
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = env::var("OUT_DIR").unwrap();

    // 1. C++ HAL drivers for non-WASM targets
    if target_arch != "wasm32" {
        cc::Build::new()
            .cpp(true)
            .std("c++17")
            .file("c_src/maataa_hal.cpp")
            .include("c_src")
            .compile("maataa_hal");

        println!("cargo:rerun-if-changed=c_src/maataa_hal.cpp");
        println!("cargo:rerun-if-changed=c_src/maataa_hal.hpp");
    }

    // 2. Locate and track Ashtadhyayi JSON file
    let json_path = Path::new(&manifest_dir).join("data/ashtadhyayi.json");
    println!("cargo:rerun-if-changed={}", json_path.display());

    let json_file = File::open(&json_path).unwrap_or_else(|_| {
        panic!(
            "Failed to open Ashtadhyayi JSON file at {}",
            json_path.display()
        )
    });

    let dataset: SutraDataset =
        serde_json::from_reader(json_file).expect("Failed to parse Ashtadhyayi JSON dataset");
    if let Err(problem) = validate(&dataset) {
        panic!(
            "data/ashtadhyayi.json is not a real, complete Ashtadhyayi: {}. \
             Regenerate it with `python3 scripts/build_ashtadhyayi.py`.",
            problem
        );
    }

    // 3. Generate PHF static hash map code
    let phf_out_path = Path::new(&out_dir).join("phf_sutras.rs");
    let mut phf_file = BufWriter::new(File::create(&phf_out_path).unwrap());

    let mut map = phf_codegen::Map::new();

    for sutra in &dataset.sutras {
        let gate = sutra.hardware_gate.as_deref().unwrap_or("DEFAULT_GATE");
        let value_str = format!(
            "(\"{}\", \"{}\", \"{}\")",
            sutra.sutra.replace('"', "\\\""),
            sutra.category.as_deref().unwrap_or("").replace('"', "\\\""),
            gate.replace('"', "\\\"")
        );
        map.entry(sutra.id.clone(), &value_str);
    }

    writeln!(
        &mut phf_file,
        "/// Compile-time perfect hash map of all Ashtadhyayi Sutras\n\
         pub static ASHTADHYAYI_MAP: phf::Map<&'static str, (&'static str, &'static str, &'static str)> = {};",
        map.build()
    ).unwrap();

    // 4. Compress JSON payload into runtime binary stream (Gzip)
    let compressed_out_path = Path::new(&out_dir).join("ashtadhyayi_compressed.bin");
    let raw_json_bytes =
        std::fs::read(&json_path).expect("Failed to read raw JSON bytes for compression");

    let compressed_file = File::create(&compressed_out_path).unwrap();
    let mut encoder = GzEncoder::new(compressed_file, Compression::best());
    encoder.write_all(&raw_json_bytes).unwrap();
    encoder.finish().unwrap();

    println!("cargo:rerun-if-changed=build.rs");
}
