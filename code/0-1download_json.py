from _utils import *

OUTPUT_JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
LOG_FP = os.path.join(LOGS_DIR, f"modeldb_download_log_{TIMESTAMP}.txt")
FAILED_HASHES_FP = os.path.join(LOGS_DIR, f"failed_file_hashes_{TIMESTAMP}.txt")

if not os.path.exists(RAW_DATA_DIR):
    print(f"Creating directory: {RAW_DATA_DIR}")
    os.makedirs(RAW_DATA_DIR)

if not os.path.exists(LOGS_DIR):
    print(f"Creating directory: {LOGS_DIR}")
    os.makedirs(LOGS_DIR)

df = pd.read_excel(os.path.join(ANNOTATIONS_DIR, "model_db_annotations.xlsx"))
ANNOTATED_SAMPLES = df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(ANNOTATED_SAMPLES)} annotated samples")

failed_download_count = 0
failed_file_hashes = []

annotated_df = df[df["file_hash"].isin(ANNOTATED_SAMPLES)].copy()
downloaded_data = []

print(f"Starting download of {len(annotated_df)} annotated ModelDB entries")

with open(LOG_FP, "w", encoding="utf-8") as log_file:
    log_file.write(f"=== ModelDB Download Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Found {len(ANNOTATED_SAMPLES)} annotated samples\n")
    log_file.write(f"Starting download of {len(annotated_df)} annotated ModelDB entries\n\n")
    
    for _, row in tqdm(annotated_df.iterrows(), total=len(annotated_df), desc="Downloading ModelDB files"):
        row_id = row["row_id"]
        file_hash = row["file_hash"]
        url = row["url"]
        
        model_id = extract_model_id(url)
        created_date = get_model_creation_date(model_id) if model_id else None
        direct_url, file_path = get_direct_download_url(url)
        
        entry_data = {
            "row_id": row_id,
            "file_hash": file_hash,
            "raw_sha": row["raw_sha"],
            "count": row["count"],
            "url": url,
            "model_id": model_id, 
            "created_date": created_date, 
            "download_url": direct_url,
            "filename": file_path,
            "content": None,
            "error_code": None,
            "has_include": 0,
            "download_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        if not direct_url:
            error_msg = f"Skipping invalid URL: {url} (file_hash: {file_hash})"
            print(error_msg)
            log_file.write(f"{error_msg}\n")
            entry_data["error_code"] = "Invalid URL"
            failed_download_count += 1
            failed_file_hashes.append(file_hash)
        else:    
            try:
                response = requests.get(direct_url, timeout=10)
                response.raise_for_status()
                entry_data["content"] = response.text
                
                include_files = get_includes(response.text)
                entry_data["has_include"] = 1 if include_files and len(include_files) > 0 else 0
                log_file.write(f"Successfully downloaded: {file_hash}\n")
                
            except requests.exceptions.HTTPError as http_err:
                error_msg = f"HTTP Error {response.status_code} for {file_hash}: {http_err}"
                print(error_msg)
                log_file.write(f"{error_msg}\n")
                entry_data["error_code"] = str(response.status_code)
                failed_download_count += 1
                failed_file_hashes.append(file_hash)
            except requests.exceptions.RequestException as e:
                error_msg = f"Request Error for {file_hash}: {str(e)}"
                print(error_msg)
                log_file.write(f"{error_msg}\n")
                entry_data["error_code"] = "Request Error"
                failed_download_count += 1
                failed_file_hashes.append(file_hash)
        
        downloaded_data.append(entry_data)

    with open(OUTPUT_JSON_FP, "w", encoding="utf-8") as json_file:
        json.dump(downloaded_data, json_file, indent=4)

    total_entries = len(downloaded_data)
    successful_downloads = total_entries - failed_download_count

    summary = f"\n=== DOWNLOAD SUMMARY ===\n"
    summary += f"Total entries: {total_entries}\n"
    summary += f"Successful downloads: {successful_downloads}\n"
    summary += f"Failed downloads: {failed_download_count}\n"
    
    print(summary)
    log_file.write(summary)
    
    if failed_download_count > 0:
        log_file.write(f"\nFailed file hashes ({failed_download_count}):\n")
        for fh in failed_file_hashes:
            log_file.write(f"  {fh}\n")
            
with open(FAILED_HASHES_FP, "w") as f:
    for fh in failed_file_hashes:
        f.write(f"{fh}\n")