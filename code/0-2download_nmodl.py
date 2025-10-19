from _utils import *

# Set up logging
LOG_FILE_FP = os.path.join(LOGS_DIR, f"nmodl_download_errors_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.ERROR,  # Only log errors
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
METADATA_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
ANNOTATIONS_FP = os.path.join(ANNOTATIONS_DIR, "model_db_annotations.xlsx")
NMODL_DIR = os.path.join(RAW_DATA_DIR, "nmodl")
os.makedirs(NMODL_DIR, exist_ok=True)

# Counter for successful and failed downloads
successful_count = 0
failed_count = 0

# Load metadata
print(f"Loading metadata from {METADATA_FP}")
metadata_df = pd.read_json(METADATA_FP)
print(f"Loaded metadata with {len(metadata_df)} entries")

# Load annotated samples from Excel file
print(f"Loading annotations from {ANNOTATIONS_FP}")
annotations_df = pd.read_excel(ANNOTATIONS_FP)
annotated_hashes = annotations_df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(annotated_hashes)} annotated samples")

# Filter metadata to only include annotated samples
filtered_df = metadata_df[metadata_df["file_hash"].isin(annotated_hashes)]
print(f"Processing {len(filtered_df)} annotated MOD files")

# Download the MOD files
for _, row in tqdm(filtered_df.iterrows(), total=len(filtered_df), desc="Downloading MOD files"):
    try:
        url = row["download_url"]
        file_hash = row["file_hash"]
        
        # Download and save as filehash.mod
        response = requests.get(url)
        response.raise_for_status()
        
        output_path = os.path.join(NMODL_DIR, f"{file_hash}.mod")
        with open(output_path, "wb") as f:
            f.write(response.content)
        
        # Increment success counter
        successful_count += 1
        
    except Exception as e:
        error_msg = f"Error downloading {url}: {e}"
        logging.error(f"File hash: {file_hash}, URL: {url} - {error_msg}")
        print(error_msg)
        
        # Increment failure counter
        failed_count += 1

# Log and print completion statistics
stats_message = f"\nTotal files processed: {len(filtered_df)}, " \
               f"Successfully downloaded: {successful_count}, " \
               f"Failed downloads: {failed_count}"
print(stats_message)

if failed_count > 0:
    logging.error(stats_message)
    print(f"Some downloads failed. Check log file: {LOG_FILE_FP}")
else:
    print("All downloads completed successfully")