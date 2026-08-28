import json
import os

# 1. करेक्शन डिक्शनरी (Sutra ID -> Expected Correct Values)
# आप इसमें भविष्य में और भी सूत्र जोड़ सकते हैं।
CORRECTIONS_MAP = {
    "1.1.1": {
        "expected_category": "संज्ञा (Saṁjñā)",
        "hardware_gate": "SAMJNA_BINDING_GATE"
    },
    "1.1.2": {
        "expected_category": "संज्ञा (Saṁjñā)",
        "hardware_gate": "SAMJNA_BINDING_GATE"
    },
    "1.1.9": {
        "expected_category": "संज्ञा (Saṁjñā)",
        "hardware_gate": "SAMJNA_BINDING_GATE"
    }
}

def find_and_correct_sutras(input_path, output_path):
    if not os.path.exists(input_path):
        print(f"[Error] फ़ाइल नहीं मिली: {input_path}")
        return

    # डेटा लोड करें
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    sutras = data.get("sutras", [])
    total_found = 0
    total_corrected = 0

    print(f"--- स्कैनिंग प्रारंभ: {len(sutras)} सूत्र ---")

    for sutra in sutras:
        sutra_id = sutra.get("id")

        # 2. FIND (खोजना): क्या यह सूत्र हमारे करेक्शन मैप में है?
        if sutra_id in CORRECTIONS_MAP:
            target = CORRECTIONS_MAP[sutra_id]
            current_category = sutra.get("category", "")

            # चेक करें कि क्या वर्तमान श्रेणी गलत है
            if current_category != target["expected_category"]:
                total_found += 1
                print(f"\n[FOUND] त्रुटि मिली -> सूत्र {sutra_id} ({sutra.get('sutra')}):")
                print(f"  - वर्तमान श्रेणी: {current_category}")
                print(f"  - सही श्रेणी होनी चाहिए: {target['expected_category']}")

                # 3. CORRECTING (सुधार करना)
                sutra["category"] = target["expected_category"]
                sutra["hardware_gate"] = target["hardware_gate"]
                total_corrected += 1
                print(f"  -> [CORRECTED] सूत्र {sutra_id} की श्रेणी और हार्डवेयर गेट अपडेट कर दिए गए हैं।")

        # 4. VECTOR NORMALIZATION (AI इंजन के लिए 8D वेक्टर को 0-1 के बीच स्केल करना)
        if "vector_8d" in sutra and len(sutra["vector_8d"]) == 8:
            vec = sutra["vector_8d"]
            min_v, max_v = min(vec), max(vec)
            if max_v > min_v:
                # 4 डेसिमल पॉइंट तक नॉर्मलाइज़ करें
                sutra["vector_8d"] = [round((v - min_v) / (max_v - min_v), 4) for v in vec]

    # सुरक्षित रूप से नया डेटा सेव करें
    data["sutras"] = sutras

    # यदि आउटपुट डायरेक्टरी मौजूद नहीं है, तो बनाएँ
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    # 5. रिपोर्ट
    print("\n--- फाइनल रिपोर्ट ---")
    print(f"कुल त्रुटियाँ मिलीं (Found): {total_found}")
    print(f"कुल सुधार किए गए (Corrected): {total_corrected}")
    print(f"अपडेटेड डेटा यहाँ सेव किया गया: {output_path}")

if __name__ == "__main__":
    INPUT_FILE = "data/ashtadhyayi.json"
    OUTPUT_FILE = "data/ashtadhyayi_corrected.json"

    find_and_correct_sutras(INPUT_FILE, OUTPUT_FILE)
