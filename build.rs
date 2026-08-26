use serde::Deserialize;
use std::env;
use std::fs::File;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;
use flate2::write::GzEncoder;
use flate2::Compression;


#[derive(Deserialize)]
struct RawSutra {
    id: String,
    text: String,
    transliteration: String,
    r#type: String,
}

fn main() {
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();

    // Only compile native C++ HAL drivers for non-WASM targets (Linux / macOS / Windows)
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

    let path = Path::new(&env::var("OUT_DIR").unwrap()).join("phf_sutras.rs");
    let mut file = BufWriter::new(File::create(&path).unwrap());

    // Sample data: Replace with reading your 4,000 sutras from a JSON/CSV file
    let sutras = vec![
        ("1.1.1", "वृद्धिरादैच्", "vriddhi_adaich"),
        ("1.1.2", "अदेङ्गुणः", "ad_gunah"),
        ("6.1.87", "आद्गुणः", "ad_gunah_sandhi"),
    ];

    let mut map = phf_codegen::Map::new();
    for (id, devanagari, name) in sutras {
        let value_str = format!("(\"{}\", \"{}\")", devanagari, name);
        map.entry(id, &value_str);
    }

    write!(
        &mut file,
        "static ASHTADHYAYI_SUTRAS: phf::Map<&'static str, (&'static str, &'static str)> = {};\n",
        map.build()
    ).unwrap();

    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("ashtadhyayi_compressed.bin");

    // Replace with reading your actual 4000 sutra JSON payload
    let raw_sutra_json = r#"[
        {"id":"1.1.1","text":"वृद्धिरादैच्","type":"samjna"},
        {"id":"1.1.2","text":"अदेङ्गुणः","type":"samjna"}
    ]"#;

    let file = File::create(&dest_path).unwrap();
    let mut encoder = GzEncoder::new(file, Compression::best());
    encoder.write_all(raw_sutra_json.as_bytes()).unwrap();
    encoder.finish().unwrap();

    println!("cargo:rerun-if-changed=build.rs");

    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let json_path = Path::new(&manifest_dir).join("data/ashtadhyayi.json");

    // Inform Cargo to re-run this build script if the JSON file changes
    println!("cargo:rerun-if-changed={}", json_path.display());

    // 1. Read and parse the input JSON file
    let file = File::open(&json_path)
        .unwrap_or_else(|_| panic!("Failed to open sutra JSON file at {}", json_path.display()));
    let reader = BufReader::new(file);
    let sutras: Vec<RawSutra> = serde_json::from_reader(reader)
        .expect("Failed to parse Ashtadhyayi JSON data");

    // 2. Prepare the output file in OUT_DIR
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("phf_ashtadhyayi.rs");
    let mut out_file = BufWriter::new(File::create(&dest_path).unwrap());

    // 3. Construct the PHF Map generator
    let mut map = phf_codegen::Map::new();

    for sutra in &sutras {
        // Construct the Rust tuple value string to embed in the PHF map:
        // (&'static str, &'static str, &'static str) -> (text, transliteration, sutra_type)
        let value_tuple = format!(
            "(\"{}\", \"{}\", \"{}\")",
            sutra.text.replace('"', "\\\""),
            sutra.transliteration.replace('"', "\\\""),
            sutra.r#type.replace('"', "\\\"")
        );

        map.entry(sutra.id.clone(), &value_tuple);
    }

    // 4. Write generated Rust code to OUT_DIR
    writeln!(
        &mut out_file,
        "/// Compile-time perfect hash map of all Ashtadhyayi Sutras\n\
         pub static ASHTADHYAYI_MAP: phf::Map<&'static str, (&'static str, &'static str, &'static str)> = {};",
        map.build()
    )
    .unwrap();
}