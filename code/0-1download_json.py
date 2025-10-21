#Import functions and set global variables
from _utils import *
import re
import json
import requests
from datetime import datetime
from tqdm import tqdm

OUTPUT_JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")


# Load dataset from Excel
df = pd.read_excel(os.path.join(ANNOTATIONS_DIR, "model_db_annotations.xlsx"))

# Get annotated samples
ANNOTATED_SAMPLES = df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(ANNOTATED_SAMPLES)} annotated samples")

# Failed downloads counter
failed_download_count = 0
failed_file_hashes = []  # Track failed hashes

# Create data directory if it doesn't exist
if not os.path.exists(RAW_DATA_DIR):
    print(f"Creating directory: {RAW_DATA_DIR}")
    os.makedirs(RAW_DATA_DIR)

# Filter to keep only annotated samples
annotated_df = df[df["file_hash"].isin(ANNOTATED_SAMPLES)].copy()

# Create a list to store all the downloaded data
downloaded_data = []

# Process start message only printed to console, not logged
print(f"Starting download of {len(annotated_df)} annotated ModelDB entries")

# Process each annotated file
for _, row in tqdm(annotated_df.iterrows(), total=len(annotated_df), desc="Downloading ModelDB files"):
    row_id = row["row_id"]
    file_hash = row["file_hash"]
    url = row["url"]
    
    # Extract model_id from the URL
    model_id = extract_model_id(url)
    
    # Get model creation date from the API
    created_date = get_model_creation_date(model_id) if model_id else None
    
    direct_url, file_path = get_direct_download_url(url)
    
    # Default data for this entry
    entry_data = {
        "row_id": row_id,
        "file_hash": file_hash,
        "raw_sha": row["raw_sha"],
        "count": row["count"],
        "url": url,
        "model_id": model_id,  # Add the model_id to the entry data
        "created_date": created_date,  # Add the creation date to the entry data
        "download_url": direct_url,
        "filename": file_path,
        "content": None,
        "error_code": None,
        "has_include": 0,
        "download_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    if not direct_url:
        error_msg = f"Invalid URL format: {url}"
        print(f"Skipping invalid URL: {url} (file_hash: {file_hash})")
        entry_data["error_code"] = "Invalid URL"
        failed_download_count += 1
        failed_file_hashes.append(file_hash)
    else:    
        try:
            response = requests.get(direct_url, timeout=10)
            response.raise_for_status()
            entry_data["content"] = response.text
            
            # Check for includes and update has_include field
            include_files = get_includes(response.text)
            entry_data["has_include"] = 1 if include_files and len(include_files) > 0 else 0
            
            # No logging for successful downloads
            
        except requests.exceptions.HTTPError as http_err:
            error_msg = f"HTTP Error {response.status_code}: {http_err}"
            print(f"Failed to fetch {direct_url} - {error_msg} (file_hash: {file_hash})")
            entry_data["error_code"] = str(response.status_code)
            failed_download_count += 1
            failed_file_hashes.append(file_hash)
        except requests.exceptions.RequestException as e:
            error_msg = f"Request Error: {str(e)}"
            print(f"Failed to fetch {direct_url}: {e} (file_hash: {file_hash})")
            entry_data["error_code"] = "Request Error"
            failed_download_count += 1
            failed_file_hashes.append(file_hash)
    
    # Add this entry to our list
    downloaded_data.append(entry_data)

# Save all downloaded data to JSON
with open(OUTPUT_JSON_FP, "w", encoding="utf-8") as json_file:
    json.dump(downloaded_data, json_file, indent=4)

# Completion message only printed to console
completion_message = f"\nModelDB metadata saved in {OUTPUT_JSON_FP}"
print(completion_message)

total_entries = len(downloaded_data)
successful_downloads = total_entries - failed_download_count

stats_message = f"Total entries: {total_entries}, " \
               f"Successful downloads: {successful_downloads}, " \
               f"Failed downloads: {failed_download_count}"
print(stats_message)

# Print and log the failed file hashes
if failed_download_count > 0:
    print(f"\nFailed file hashes ({len(failed_file_hashes)}):")
    for fh in failed_file_hashes:
        print(f"  {fh}")
    
    # Write failed hashes to a separate file
    failed_hashes_fp = os.path.join(LOGS_DIR, f"failed_file_hashes_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    with open(failed_hashes_fp, "w") as f:
        for fh in failed_file_hashes:
            f.write(f"{fh}\n")
    
