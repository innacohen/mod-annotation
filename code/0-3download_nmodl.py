from _utils import *

os.makedirs(NMODL_DATA_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
LOG_FP = os.path.join(LOGS_DIR, f"nmodl_download_log_{TIMESTAMP}.txt")
FAILED_HASHES_FP = os.path.join(LOGS_DIR, f"nmodl_failed_hashes_{TIMESTAMP}.txt")

raw_json_df = pd.read_json(JSON_FP)

total_entries = len(raw_json_df)
failed_download_count = 0
failed_file_hashes = []
successful_count = 0

print(f"Starting download of {total_entries} NMODL files")


with open(LOG_FP, "w", encoding="utf-8") as log_file:
    log_file.write(f"=== NMODL Download Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Total files to download: {total_entries}\n\n")
    
    for _, row in tqdm(raw_json_df.iterrows(), total=total_entries, desc="Downloading MOD files"):
        try:
            url = row["download_url"]
            file_hash = row["file_hash"]
            
            # Skip rows with no download URL
            if not url:
                error_msg = f"Skipping empty URL for file_hash: {file_hash}"
                print(error_msg)
                log_file.write(f"{error_msg}\n")
                failed_download_count += 1
                failed_file_hashes.append(file_hash)
                continue
                
            # Download and save as filehash.mod
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            output_path = os.path.join(NMODL_DATA_DIR, f"{file_hash}.mod")
            with open(output_path, "wb") as f:
                f.write(response.content)
                
            # Log successful download
            log_file.write(f"Successfully downloaded: {file_hash}\n")
            successful_count += 1
                
        except Exception as e:
            error_msg = f"Error downloading {file_hash}: {str(e)}"
            print(error_msg)
            log_file.write(f"{error_msg}\n")
            failed_download_count += 1
            failed_file_hashes.append(file_hash)
    
    summary = f"\n=== DOWNLOAD SUMMARY ===\n"
    summary += f"Total entries: {total_entries}\n"
    summary += f"Successful downloads: {successful_count}\n"
    summary += f"Failed downloads: {failed_download_count}\n"
    
    print(summary)
    log_file.write(summary)
    
    # Write failed hashes to the log file
    if failed_download_count > 0:
        log_file.write(f"\nFailed file hashes ({failed_download_count}):\n")
        for fh in failed_file_hashes:
            log_file.write(f"  {fh}\n")
            
# Write failed hashes to a separate file
with open(FAILED_HASHES_FP, "w") as f:
    for fh in failed_file_hashes:
        f.write(f"{fh}\n")

print(f"Download complete. Log saved to: {LOG_FP}")
if failed_download_count > 0:
    print(f"Failed hashes saved to: {FAILED_HASHES_FP}")