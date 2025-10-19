#Import functions and set global variables
from _utils import *
OUTPUT_JSON_FP = os.path.join(DATA_DIR, "model_db_metadata.json")
LOG_FILE_FP = os.path.join(LOGS_DIR, f"model_db_download_errors_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Load dataset from Excel
df = pd.read_excel(os.path.join(ANNOTATIONS_DIR, "model_db_annotations.xlsx"))

# Get annotated samples
ANNOTATED_SAMPLES = df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(ANNOTATED_SAMPLES)} annotated samples")


# Failed downloads counter
failed_download_count = 0

# Create data directory if it doesn't exist
if not os.path.exists(DATA_DIR):
    print(f"Creating directory: {DATA_DIR}")
    os.makedirs(DATA_DIR)


# Filter to keep only annotated samples
annotated_df = df[df["file_hash"].isin(ANNOTATED_SAMPLES)].copy()

# Create a list to store all the downloaded data
downloaded_data = []

# Log the start of processing
logging.info(f"Starting download of {len(annotated_df)} annotated ModelDB entries")
print(f"Starting download of {len(annotated_df)} annotated ModelDB entries")

# Process each annotated file
for _, row in tqdm(annotated_df.iterrows(), total=len(annotated_df), desc="Downloading ModelDB files"):
    row_id = row["row_id"]
    file_hash = row["file_hash"]
    url = row["url"]
    
    direct_url, file_path = get_direct_download_url(url)
    
    # Default data for this entry
    entry_data = {
        "row_id": row_id,
        "file_hash": file_hash,
        "raw_sha": row["raw_sha"],
        "count": row["count"],
        "url": url,
        "download_url": direct_url,
        "filename": file_path,
        "content": None,
        "error_code": None,
        "has_include": 0,
        "download_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    if not direct_url:
        error_msg = f"Invalid URL format: {url}"
        print(f"Skipping invalid URL: {url}")
        logging.error(f"Row ID {row_id}: {error_msg}")
        entry_data["error_code"] = "Invalid URL"
        failed_download_count += 1
    else:    
        try:
            response = requests.get(direct_url, timeout=10)
            response.raise_for_status()
            entry_data["content"] = response.text
            
            # Check for includes and update has_include field
            include_statement = get_include(response.text)
            entry_data["has_include"] = 1 if include_statement else 0
            
        except requests.exceptions.HTTPError as http_err:
            error_msg = f"HTTP Error {response.status_code}: {http_err}"
            print(f"Failed to fetch {direct_url} - {error_msg}")
            logging.error(f"Row ID {row_id}, URL: {direct_url} - {error_msg}")
            entry_data["error_code"] = str(response.status_code)
            failed_download_count += 1
        except requests.exceptions.RequestException as e:
            error_msg = f"Request Error: {str(e)}"
            print(f"Failed to fetch {direct_url}: {e}")
            logging.error(f"Row ID {row_id}, URL: {direct_url} - {error_msg}")
            entry_data["error_code"] = "Request Error"
            failed_download_count += 1
    
    # Add this entry to our list
    downloaded_data.append(entry_data)

# Save all downloaded data to JSON
with open(OUTPUT_JSON_FP, "w", encoding="utf-8") as json_file:
    json.dump(downloaded_data, json_file, indent=4)

# Log completion
completion_message = f"\nModelDB metadata saved in {OUTPUT_JSON_FP}"
print(completion_message)
logging.info(completion_message)

total_entries = len(downloaded_data)
successful_downloads = total_entries - failed_download_count

stats_message = f"Total entries: {total_entries}, " \
               f"Successful downloads: {successful_downloads}, " \
               f"Failed downloads: {failed_download_count}"
print(stats_message)
logging.info(stats_message)

if failed_download_count > 0:
    print(f"Some downloads failed. Check log file: {LOG_FILE_FP}")
    logging.info("Download process completed with errors")
else:
    logging.info("Download process completed successfully")
# %%
