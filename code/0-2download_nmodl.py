
NMODL_DIR = RAW_DATA_DIR / "nmodl"

LOG_FILE_FP = os.path.join(LOGS_DIR, f"0-2nmodl_download_errors_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.ERROR,  # Only log errors
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

successful_count = 0
failed_count = 0

raw_json_df = pd.read_json(JSON_FP)

df = pd.read_excel(ANNOTATIONS_FP).query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(df)} annotated samples")

base_dir = NMODL_DIR
os.makedirs(base_dir, exist_ok=True)

for _, row in tqdm(raw_json_df.iterrows(), total=len(raw_json_df), desc="Downloading MOD files"):
    try:
        url = row["download_url"]
        file_hash = row["file_hash"]
        
        # Download and save as filehash.mod
        response = requests.get(url)
        response.raise_for_status()
        
        output_path = os.path.join(base_dir, f"{file_hash}.mod")
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

stats_message = f"\nTotal files processed: {len(raw_json_df)}, " \
               f"Successfully downloaded: {successful_count}, " \
               f"Failed downloads: {failed_count}"
print(stats_message)

if failed_count > 0:
    logging.error(stats_message)
    print(f"Some downloads failed. Check log file: {LOG_FILE_FP}")
else:
    print("All downloads completed successfully")