import csv
import json
import os

# Paths
FILE1 = "Sources/ANKI-HUB-iOS/Resources/OriginalData/古文単語リスト - Table 1.csv"
FILE2 = "Sources/ANKI-HUB-iOS/Resources/OriginalData/重要古語・プラスアルファ古文単語一覧 - Table 1.csv"
OUTPUT_JSON = "Sources/ANKI-HUB-iOS/Resources/kobun.json"
PDF_JSON = "Sources/ANKI-HUB-iOS/Resources/kobun_pdf.json"

def normalize_word(raw):
    if raw is None:
        return ""
    return str(raw).strip().replace(" ", "").replace("\u3000", "")

def clean_hint(raw_hint, word):
    if not raw_hint: return None
    if raw_hint == "Not in source": return None
    if raw_hint == word: return None
    if "／" in raw_hint:
        parts = raw_hint.split("／")
        candidate = parts[0]
        if candidate != word and candidate != "Not in source":
            return candidate
    return raw_hint

def format_hint(raw_kanji):
    if not raw_kanji: return None
    clean = raw_kanji.replace("（", "").replace("）", "")
    return f"（{clean}）"

def main():
    # 1. Load File 1
    # Store full items to append later if not in File 2
    items_file1 = {}
    
    # Corrections Map for File 1
    # Key: Original, Value: Corrected (or None to skip)
    WORD_CORRECTIONS = {
        "いtoほし": "いとほし",
        "かかかる〜": "かかる〜",
        "さいてもありぬべし": "さてもありぬべし",
        "さ はる": "さはる",
        "わざわざ": None, # Exclude modern word/error
        "ひたぶるなり": "ひたぶるなり", # Just in case
    }

    if os.path.exists(FILE1):
        with open(FILE1, mode='r', encoding='utf-8') as f1:
            reader = csv.DictReader(f1)
            for row in reader:
                w = row.get('古文単語', '').strip()
                k = row.get('漢字表記', '').strip()
                m = row.get('意味', '').strip()
                
                # Apply corrections
                if w in WORD_CORRECTIONS:
                    w = WORD_CORRECTIONS[w]
                    if w is None: continue

                w = normalize_word(w)
                
                if w:
                    # If multiple entries resolve to same word, first one wins? 
                    # Or maybe we accumulate. For now, overwrite is fine as duplicates in File 1 are rare.
                    items_file1[w] = {
                        "word": w,
                        "meaning": m,
                        "hint": k
                    }
    
    # 2. Process File 2 (Master List)
    processed_words = set()
    data = []
    
    index = 1
    
    if os.path.exists(FILE2):
        with open(FILE2, mode='r', encoding='utf-8') as f2:
            reader = csv.DictReader(f2)
            
            for row in reader:
                word = row.get('単語', '').strip()
                meaning = row.get('意味', '').strip()
                col2 = row.get('読み/補足', '').strip()
                
                if not word: continue

                # Fix typos in File 2
                if word == "ひとりやりならず":
                    word = "ひとやりならず"

                word = normalize_word(word)
                if not word:
                    continue
                
                processed_words.add(word)
                
                item = {
                    "id": index,
                    "word": word,
                    "meaning": meaning
                }
                
                # Determine Hint (Kanji)
                kanji_candidate = None
                
                # Priority 1: File 1 Match
                if word in items_file1 and items_file1[word]["hint"] != "Not in source":
                    kanji_candidate = items_file1[word]["hint"]
                # Priority 2: File 2 Column 2 (Parse)
                else:
                    processed = clean_hint(col2, word)
                    if processed:
                        kanji_candidate = processed
                
                if kanji_candidate:
                    item["hint"] = format_hint(kanji_candidate)

                # Fix hint data errors based on PDF reference
                # かる: Source says （離る） but PDF says （離る／下二）
                if word == "かる" and item.get("hint") == "（離る）":
                    item["hint"] = "（離る／下二）"
                
                data.append(item)
                index += 1
    
    # 3. Append Unique items from File 1
    for w, info in items_file1.items():
        if w not in processed_words:
            
            # Since w is already corrected in Step 1, simple check is enough
            item = {
                "id": index,
                "word": w,
                "meaning": info["meaning"]
            }
            if info["hint"] and info["hint"] != "Not in source":
                item["hint"] = format_hint(info["hint"])
            
            data.append(item)
            index += 1
            print(f"Added unique from File 1: {w}")

    # 4. Supplement missing words from kobun_pdf.json (CSV priority)
    if os.path.exists(PDF_JSON):
        try:
            with open(PDF_JSON, mode="r", encoding="utf-8") as f:
                pdf_items = json.load(f)

            pdf_by_word = {}
            for p in pdf_items:
                k = normalize_word(p.get("word"))
                if k and k not in pdf_by_word:
                    pdf_by_word[k] = p

            # 4-1. Fill missing hint from PDF when CSV has the word but hint is missing
            for item in data:
                wkey = normalize_word(item.get("word"))
                if not wkey:
                    continue
                if item.get("hint"):
                    continue
                p = pdf_by_word.get(wkey)
                if p and p.get("hint"):
                    item["hint"] = p.get("hint")

            existing = set()
            for item in data:
                k = normalize_word(item.get("word"))
                if k:
                    existing.add(k)

            missing = []
            for p in pdf_items:
                k = normalize_word(p.get("word"))
                if not k:
                    continue
                if k in existing:
                    continue
                missing.append((k, p))
            missing.sort(key=lambda x: x[0])

            for _, p in missing:
                item = {
                    "id": index,
                    "word": p.get("word", ""),
                    "meaning": p.get("meaning", "")
                }
                if p.get("hint"):
                    item["hint"] = p.get("hint")
                if p.get("example"):
                    item["example"] = p.get("example")
                data.append(item)
                index += 1
        except Exception as e:
            print(f"Warning: failed to supplement from PDF: {e}")

    # Write JSON
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as jsonfile:
        json.dump(data, jsonfile, ensure_ascii=False, indent=2)
    
    print(f"Successfully converted {len(data)} items (Merged) to {OUTPUT_JSON}")

if __name__ == "__main__":
    main()
