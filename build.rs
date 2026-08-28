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
    category: String,
    hardware_gate: Option<String>,
}

#[derive(Deserialize, Debug)]
#[allow(dead_code)]
struct SutraDataset {
    total_sutras: Option<usize>,
    sutras: Vec<SutraItem>,
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

    // 3. Generate PHF static hash map code
    let phf_out_path = Path::new(&out_dir).join("phf_sutras.rs");
    let mut phf_file = BufWriter::new(File::create(&phf_out_path).unwrap());

    let mut map = phf_codegen::Map::new();

    for sutra in &dataset.sutras {
        let gate = sutra.hardware_gate.as_deref().unwrap_or("DEFAULT_GATE");
        let value_str = format!(
            "(\"{}\", \"{}\", \"{}\")",
            sutra.sutra.replace('"', "\\\""),
            sutra.category.replace('"', "\\\""),
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
