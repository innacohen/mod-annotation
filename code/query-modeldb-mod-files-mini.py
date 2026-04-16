import zipfile
import hashlib
import sqlite3
from pathlib import Path
import re
import tqdm
from openai import OpenAI
import json
import re
import sys

# this assumes there is an environment variable with an
# OPENAI API key
client = OpenAI()

def extract_last_balanced_braces(s):
    count = 0
    end = None
    # Scan backwards to find the last closing brace
    for i in range(len(s) - 1, -1, -1):
        if s[i] == '}':
            if end is None:
                end = i
            count += 1
        elif s[i] == '{':
            if count > 0:
                count -= 1
                if count == 0:
                    return s[i:end+1]
    return None


def call_openai_api(file_contents):
    try:
        messages = [
            {
                "role": "system",
                "content": "You are an expert in computational neuroscience.",
            },
            {
                "role": "user",
                "content": """The following is a MOD file from a NEURON computational neuroscience model. 

```
"""
                + file_contents
                + """
```

Briefly discuss the biology that the above code appears to be modeling. End by generating JSON of the form {"mechanisms": ["term1", "term2"], "type of model": "free text", "notes": "any notes of unusual things in the model"} where the terms (typically 0 or 1 but could be more represent the mechanism(s) (currents, pumps, and receptors) that are modeled in the file, chosen verbatim from the list below. When interpreting this list, HVA is high voltage activated, LT is low threshold, Rare should be interpreted as any other type of that channel that isn't covered by a more specific channel, "I Other (Rare)" is a current (e.g., Cl) that is not a Ca, K, or Na current, a prefix of R indicates a receptor (e.g., "R Other (Rare)" is a synaptic receptor that is not GABA, AMPA, or NMDA), and "Z Neither" is something that is neither a receptor nor a current (this could be a pump or it could be a utility file with many VERBATIM blocks that has no direct biological interpretation). Provide no additional explanation after the JSON.

"I Ca (HVA)", "I Ca (Rare)", "I Ca (T-type LT)", "I H", "I K (A-type)", "I K (Ca-activated)", "I K (Delayed Rectifier)", "I K (M-type)", "I K (Rare)", "I Na (Persistent)", "I Na (Rare)", "I Na (Slow inactivation)", "I Na (Transient)", "I Other (Rare)", "R GABA", "R Glutamate (AMPA)", "R Glutamate (NMDA)", "R Other (Rare)", "Z Neither"
""",
            },
        ]

        response = client.chat.completions.create(model="gpt-5-mini-2025-08-07", messages=messages)
        # import pdb
        # pdb.set_trace()
        # Extract the assistant's message
        content = response.choices[0].message.content
        print(content)

        # Extract the last JSON object enclosed in curly braces
        json_str = extract_last_balanced_braces(content)
        if json_str:
            print(f"{json_str = }")
            result = json.loads(json_str)
            return result
        else:
            raise ValueError("No valid JSON found in the API response.")

    except Exception as e:
        print(f"Error calling OpenAI API: {e}")
        raise


ZIPFOLDER = "/Users/ramcdougal/Dropbox/notebook/2021/20211001/zips"

if len(sys.argv) > 1:
    DB_FILENAME = sys.argv[1]
else:
    DB_FILENAME = "mod_files_mini.db"


def preprocess(contents):
    # Step 1: Remove text after colons
    lines = contents.split("\n")
    lines_without_comments = [line.split(":")[0] for line in lines]

    # Step 2: Remove lines between COMMENT and ENDCOMMENT markers
    processed_lines = []
    skip = False
    for line in lines_without_comments:
        stripped_line = line.strip()
        if stripped_line == "COMMENT":
            skip = True
        elif stripped_line == "ENDCOMMENT":
            skip = False
        elif not skip:
            processed_lines.append(stripped_line)

    # Step 3: Remove all whitespace
    processed_contents = "".join(processed_lines)
    processed_contents = re.sub(r"\s+", "", processed_contents)

    return processed_contents


def process_zipfile(zip_path):
    try:
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            for file_info in zip_ref.infolist():
                # Skip any files or directories inside a __MACOSX folder
                if "__MACOSX/" in file_info.filename:
                    continue

                if file_info.filename.lower().endswith(".mod"):
                    with zip_ref.open(file_info) as file:
                        try:
                            raw_contents = file.read().decode("utf-8")
                        except UnicodeDecodeError:
                            print(
                                f"UTF-8 decoding failed for file {file_info.filename}. Falling back to Latin1."
                            )
                            raw_contents = file.read().decode("latin1")

                        preprocessed_contents = preprocess(raw_contents)

                        file_hash = hashlib.sha256(
                            preprocessed_contents.encode("utf-8")
                        ).hexdigest()

                        if not is_in_db(file_hash):
                            data = call_openai_api(raw_contents)
                            print(zip_path.name, file_info.filename, data)
                            store_in_db(file_hash, data)
    except zipfile.BadZipFile:
        print("Unable to read zip file", zip_path)


def is_in_db(file_hash):
    with sqlite3.connect(DB_FILENAME) as conn:
        c = conn.cursor()

        # Create table if it does not exist
        # a little strange to do it at the checking stage, but would
        # fail if it didn't exist (and we check the db before we add
        # anything to it)
        c.execute(
            """
        CREATE TABLE IF NOT EXISTS mod_files (
            hash TEXT PRIMARY KEY,
            mechanisms TEXT,
            notes TEXT
        )
        """
        )

        # Check if the hash is already in the database
        c.execute("SELECT 1 FROM mod_files WHERE hash = ?", (file_hash,))
        result = c.fetchone()

    return result is not None


def store_in_db(file_hash, data):
    with sqlite3.connect(DB_FILENAME) as conn:
        c = conn.cursor()

        c.execute(
            """
        INSERT INTO mod_files (hash, mechanisms, notes)
        VALUES (?, ?, ?)
        """,
            (file_hash, json.dumps(data["mechanisms"]), data["notes"]),
        )

        conn.commit()


def main():
    zip_folder_path = Path(ZIPFOLDER)
    for zip_file in tqdm.tqdm(zip_folder_path.glob("*.zip")):
        process_zipfile(zip_file)


if __name__ == "__main__":
    main()
