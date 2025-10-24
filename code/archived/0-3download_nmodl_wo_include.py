from _utils import *

os.makedirs(NMODL_DATA_DIR, exist_ok=True)
JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")

raw_json_df = pd.read_json(JSON_FP)

for _, row in tqdm(raw_json_df.iterrows(), total=len(raw_json_df), desc="Downloading MOD files"):
    try:
        url = row["download_url"]
        file_hash = row["file_hash"]

        # Download and save as filehash.mod
        response = requests.get(url)
        response.raise_for_status()

        output_path = os.path.join(NMODL_DATA_DIR, f"{file_hash}.mod")
        with open(output_path, "wb") as f:
            f.write(response.content)

    except Exception as e:
        print(f"Error downloading {url}: {e}")