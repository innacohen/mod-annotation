from _utils import *

# === SETUP LOGGING ===
LOG_FILE_FP = os.path.join(LOGS_DIR, f"0-2nmodl_download_errors_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

successful_count = 0
failed_count = 0
h_file_count = 0
inc_file_count = 0

# === LOAD DATA ===
raw_json_df = pd.read_json(JSON_FP)
annotated_hashes = pd.read_excel(ANNOTATIONS_FP).query("annotated=='y'")["file_hash"].tolist()
raw_json_df = raw_json_df[raw_json_df["file_hash"].isin(annotated_hashes)]

print(f"Found {len(raw_json_df)} annotated ModelDB entries to download.")

# === OUTPUT STRUCTURE ===
base_dir = NMODL_DIR
os.makedirs(base_dir, exist_ok=True)

# === MAIN LOOP ===
for _, row in tqdm(raw_json_df.iterrows(), total=len(raw_json_df), desc="Downloading NMODL, INC & H files"):
    try:
        file_hash = row["file_hash"]
        url = row.get("download_url")
        model_id = str(row.get("model_id", "unknown"))

        # Skip if no URL or model ID
        if not url or model_id == "None":
            logging.error(f"Skipping {file_hash}: missing model_id or download URL")
            failed_count += 1
            continue

        # Create per-model directory
        model_dir = os.path.join(base_dir, model_id)
        os.makedirs(model_dir, exist_ok=True)

        # === Download .mod file ===
        mod_path = os.path.join(model_dir, f"{file_hash}.mod")
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        with open(mod_path, "wb") as f:
            f.write(response.content)

        # === Download .inc files (if any) ===
        inc_urls = row.get("download_inc_url", [])
        if isinstance(inc_urls, list) and len(inc_urls) > 0:
            for inc_url in inc_urls:
                try:
                    inc_name = inc_url.split("/")[-1]
                    inc_path = os.path.join(model_dir, inc_name)
                    inc_resp = requests.get(inc_url, timeout=10)
                    inc_resp.raise_for_status()
                    with open(inc_path, "wb") as f:
                        f.write(inc_resp.content)
                    inc_file_count += 1
                except Exception as inc_err:
                    logging.error(f"Error downloading INC file for {file_hash}: {inc_url} - {inc_err}")

        # === Download .h files (if any) ===
        h_urls = row.get("download_h_url", [])
        if isinstance(h_urls, list) and len(h_urls) > 0:
            for h_url in h_urls:
                try:
                    h_name = h_url.split("/")[-1]
                    h_path = os.path.join(model_dir, h_name)
                    h_resp = requests.get(h_url, timeout=10)
                    h_resp.raise_for_status()
                    with open(h_path, "wb") as f:
                        f.write(h_resp.content)
                    h_file_count += 1
                except Exception as h_err:
                    logging.error(f"Error downloading H file for {file_hash}: {h_url} - {h_err}")

        successful_count += 1

    except Exception as e:
        error_msg = f"Error downloading {url} (model_id={model_id}): {e}"
        logging.error(f"File hash: {file_hash}, URL: {url} - {error_msg}")
        print(error_msg)
        failed_count += 1

# === SUMMARY ===
stats_message = (
    f"\nTotal files processed: {len(raw_json_df)}\n"
    f"Successfully downloaded: {successful_count}\n"
    f"Failed downloads: {failed_count}\n"
    f"INC files downloaded: {inc_file_count}\n"
    f"H files downloaded: {h_file_count}"
)
print(stats_message)

if failed_count > 0:
    logging.error(stats_message)
    print(f"Some downloads failed. Check log file: {LOG_FILE_FP}")
else:
    print("All downloads completed successfully.")

# === Optional: Create detailed summary ===
print("\n=== Detailed Summary ===")
models_with_inc = raw_json_df[raw_json_df["has_include"] == 1]["model_id"].nunique()
models_with_h = raw_json_df[raw_json_df["has_h_url"] == 1]["model_id"].nunique()
print(f"Models with .inc files: {models_with_inc}")
print(f"Models with .h files: {models_with_h}")