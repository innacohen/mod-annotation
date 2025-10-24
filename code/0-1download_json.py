from _utils import *

JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
LOG_FP = os.path.join(LOGS_DIR, f"model_extract_log_{TIMESTAMP}.txt")
FAILED_MODELS_FP = os.path.join(LOGS_DIR, f"failed_extractions_{TIMESTAMP}.txt")

os.makedirs(LOGS_DIR, exist_ok=True)
os.makedirs(DROPBOX_DIR, exist_ok=True)

raw_json_df = pd.read_json(JSON_FP)
model_ids = raw_json_df["model_id"].tolist()

successful_count = 0
failed_count = 0
missing_count = 0
failed_models = []

with open(LOG_FP, "w") as log_file:
    log_file.write(f"=== ModelDB Extraction Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Starting extraction of {len(model_ids)} ModelDB models\n\n")
    
    for model_id in tqdm(model_ids, desc="Unzipping ModelDB files"):
        ZIP_FNAME = f"{model_id}.zip"
        ZIP_FP = os.path.join(DROPBOX_DIR, ZIP_FNAME)
        
        if os.path.exists(ZIP_FP):
            try:
                with zipfile.ZipFile(ZIP_FP, 'r') as zip_ref:
                    zip_ref.extractall(DROPBOX_DIR)
                log_file.write(f"Successfully unzipping: {ZIP_FNAME}\n")
                successful_count += 1
            except Exception as e:
                error_msg = f"Error unzipping {ZIP_FNAME}: {e}"
                log_file.write(f"{error_msg}\n")
                failed_count += 1
                failed_models.append((model_id, error_msg))
        else:
            missing_msg = f"File not found: {ZIP_FNAME}"
            log_file.write(f"{missing_msg}\n")
            missing_count += 1
            failed_models.append((model_id, missing_msg))
    
    summary = f"\n=== EXTRACTION SUMMARY ===\n"
    summary += f"Total models: {len(model_ids)}\n"
    summary += f"Successfully unzipped: {successful_count}\n"
    summary += f"Failed unzips: {failed_count}\n"
    summary += f"Missing files: {missing_count}\n"
    
    print(summary)
    log_file.write(summary)

if failed_count > 0 or missing_count > 0:
    with open(FAILED_MODELS_FP, "w") as f:
        for model_id, reason in failed_models:
            f.write(f"{model_id}: {reason}\n")
    print(f"Failed models written to: {FAILED_MODELS_FP}")