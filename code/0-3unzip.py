from _utils import *

JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
raw_json_df = pd.read_json(JSON_FP)
model_ids = raw_json_df["model_id"].tolist()

# Process each model ID
for model_id in model_ids:
    ZIP_FNAME = f"{model_id}.zip"
    ZIP_FP = os.path.join(DROPBOX_DIR, ZIP_FNAME)
    
    if os.path.exists(ZIP_FP):
        try:
            print(f"Extracting {ZIP_FNAME} in place")
            with zipfile.ZipFile(ZIP_FP, 'r') as zip_ref:
                zip_ref.extractall(DROPBOX_DIR)
            print(f"Successfully extracted model {model_id}")
        except Exception as e:
            print(f"Error extracting {ZIP_FNAME}: {e}")
    else:
        print(f"File not found: {ZIP_FNAME}")