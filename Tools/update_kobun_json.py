import csv
import json
import os
import re

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
    if not raw_hint:
        return None
    if raw_hint == "Not in source":
        return None
    if raw_hint == word:
        return None
    # If hint contains specific format like "（こころうし）", keep it clean
    return raw_hint

def format_hint(raw_kanji):
    if not raw_kanji:
        return None
    # Remove existing parens to avoid double (( ))
    clean = raw_kanji.replace("（", "").replace("）", "")
    if not clean:
        return None
    return f"（{clean}）"

def has_kanji(text):
    if not text:
        return False
    return bool(re.search(r'[一-龠]', text))

def is_hiragana_only(text):
    if not text:
        return False
    return bool(re.fullmatch(r'[ぁ-んー]+', text))

def main():
    # 1. Load File 1
    items_file1 = {}
    
    WORD_CORRECTIONS = {
        "いtoほし": "いとほし",
        "かかかる〜": "かかる〜",
        "さいてもありぬべし": "さてもありぬべし",
        "さ はる": "さはる",
        "わざわざ": None, 
        "ひたぶるなり": "ひたぶるなり",
    }

    if os.path.exists(FILE1):
        with open(FILE1, mode='r', encoding='utf-8') as f1:
            reader = csv.DictReader(f1)
            for row in reader:
                w = row.get('古文単語', '').strip()
                k = row.get('漢字表記', '').strip()
                m = row.get('意味', '').strip()
                
                if w in WORD_CORRECTIONS:
                    w = WORD_CORRECTIONS[w]
                    if w is None: continue

                w = normalize_word(w)
                if w:
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
                word_raw = row.get('単語', '').strip()
                meaning = row.get('意味', '').strip()
                col2 = row.get('読み/補足', '').strip()
                
                if not word_raw: continue

                if word_raw == "ひとりやりならず":
                    word_raw = "ひとやりならず"

                # Logic: Swap if word is Kanji and col2 is Hiragana reading
                # e.g. word="心憂し", col2="こころうし" -> final_word="こころうし", hint="（心憂し）"
                final_word = word_raw
                kanji_hint = None
                
                # Check if we should swap
                # Condition: Word has Kanji AND Col2 is Hiragana (and not just some note)
                # Simple check: Col2 is hiragana only (maybe with symbols?)
                # Actually col2 might contain "（...）" or "＝..." so clean it first
                clean_col2 = col2.split('＝')[0].split('（')[0].strip() # Take first part
                
                if has_kanji(word_raw) and is_hiragana_only(clean_col2):
                    final_word = clean_col2
                    kanji_hint = word_raw
                else:
                    # Keep original structure
                    # Try to use File 1 hint if available
                    pass

                final_word_norm = normalize_word(final_word)
                if not final_word_norm: continue
                
                processed_words.add(final_word_norm)
                
                item = {
                    "id": index,
                    "word": final_word,
                    "meaning": meaning
                }
                
                # Determine Hint
                # Priority:
                # 1. Swapped Kanji (from above)
                # 2. File 1 Match (Kanji column)
                # 3. Col2 (if not swapped)
                
                final_hint_str = None
                
                if kanji_hint:
                    final_hint_str = kanji_hint
                elif final_word_norm in items_file1 and items_file1[final_word_norm]["hint"] != "Not in source":
                    final_hint_str = items_file1[final_word_norm]["hint"]
                else:
                    # If we didn't swap, maybe col2 has useful info
                    if col2 and col2 != final_word:
                         final_hint_str = col2

                if final_hint_str:
                    item["hint"] = format_hint(final_hint_str)

                # Specific fix
                if final_word == "かる" and item.get("hint") == "（離る）":
                    item["hint"] = "（離る／下二）"
                
                data.append(item)
                index += 1
    
    # 3. Append Unique items from File 1
    for w, info in items_file1.items():
        if w not in processed_words:
            item = {
                "id": index,
                "word": w,
                "meaning": info["meaning"]
            }
            if info["hint"] and info["hint"] != "Not in source":
                item["hint"] = format_hint(info["hint"])
            
            data.append(item)
            index += 1
            processed_words.add(w)

    # 4. Supplement from PDF (and Merge)
    if os.path.exists(PDF_JSON):
        try:
            with open(PDF_JSON, mode="r", encoding="utf-8") as f:
                pdf_items = json.load(f)

            pdf_by_word = {}
            for p in pdf_items:
                k = normalize_word(p.get("word"))
                if k:
                    pdf_by_word[k] = p

            # 4-1. Merge info into existing items
            for item in data:
                wkey = normalize_word(item.get("word"))
                if not wkey: continue
                
                p = pdf_by_word.get(wkey)
                if p:
                    # Merge Hint if missing
                    if not item.get("hint") and p.get("hint"):
                        item["hint"] = p.get("hint")
                    # Merge Example if missing
                    if not item.get("example") and p.get("example"):
                        item["example"] = p.get("example")

            # 4-2. Add missing words from PDF
            missing = []
            for p in pdf_items:
                k = normalize_word(p.get("word"))
                if k and k not in processed_words:
                    missing.append(p)
            
            # Sort missing by word for consistency
            missing.sort(key=lambda x: x.get("word", ""))

            for p in missing:
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

    # 5. Post-process: Deduplicate and Kanji/Hiragana normalization
    def normalize_key(s):
        return normalize_word(s)

    def score_item(it):
        meaning_len = len((it.get("meaning") or "").strip())
        has_example = 1 if it.get("example") else 0
        has_hint = 1 if it.get("hint") else 0
        return (meaning_len, has_example, has_hint)

    # 5-1. Exact word duplicates: keep best-scored entry
    by_word = {}
    for it in data:
        k = normalize_key(it.get("word"))
        if not k:
            continue
        if k not in by_word:
            by_word[k] = it
            continue
        cur = by_word[k]
        if score_item(it) > score_item(cur):
            by_word[k] = it

    data = list(by_word.values())

    # 5-2. If same meaning has both hiragana-only and kanji forms, prefer hiragana word.
    # Move kanji form into hint when possible.
    def canon_meaning(m):
        if not m:
            return ""
        t = re.sub(r"\s+", "", str(m))
        t = t.replace("／", "/").replace("・", "").replace("、", "")
        t = t.replace("①", "").replace("②", "").replace("③", "").replace("④", "")
        return t

    by_meaning = {}
    for it in data:
        mk = canon_meaning(it.get("meaning"))
        if not mk:
            continue
        by_meaning.setdefault(mk, []).append(it)

    # For each meaning group, if there is at least one hiragana word,
    # convert kanji-word entries into the hiragana entry's hint and drop the kanji-word entries.
    keep_ids = set()
    drop_ids = set()
    for mk, items in by_meaning.items():
        hira_items = [it for it in items if is_hiragana_only(normalize_key(it.get("word")))]
        kanji_items = [it for it in items if has_kanji(it.get("word")) and not is_hiragana_only(normalize_key(it.get("word")))]
        if not hira_items or not kanji_items:
            continue

        # Choose a representative hiragana entry
        hira_items_sorted = sorted(hira_items, key=score_item, reverse=True)
        rep = hira_items_sorted[0]
        keep_ids.add(rep.get("id"))

        # Move kanji forms into hint
        kanji_forms = []
        for it in kanji_items:
            w = (it.get("word") or "").strip()
            if w:
                kanji_forms.append(w)
            drop_ids.add(it.get("id"))

        if kanji_forms:
            existing_hint = rep.get("hint")
            merged = " / ".join(sorted(set(kanji_forms)))
            merged_hint = format_hint(merged)
            if existing_hint:
                # keep existing hint, append if different
                if merged_hint and merged_hint not in existing_hint:
                    rep["hint"] = existing_hint + " " + merged_hint
            else:
                if merged_hint:
                    rep["hint"] = merged_hint

    if drop_ids:
        data = [it for it in data if it.get("id") not in drop_ids]

    # Reassign IDs sequentially for stability
    data.sort(key=lambda x: normalize_key(x.get("word")))
    for idx, it in enumerate(data, start=1):
        it["id"] = idx

    # Write JSON
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as jsonfile:
        json.dump(data, jsonfile, ensure_ascii=False, indent=2)
    
    print(f"Successfully converted {len(data)} items (Merged) to {OUTPUT_JSON}")

if __name__ == "__main__":
    main()
