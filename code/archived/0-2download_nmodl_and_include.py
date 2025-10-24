from _utils import *  

JSON_FP = os.path.join(RAW_DATA_DIR, "model_db_metadata.json")
ANNOTATIONS_FP = os.path.join(ANNOTATIONS_DIR, "model_db_annotations.xlsx")
NMODL_DIR = os.path.join(RAW_DATA_DIR, "nmodl")
INCLUDE_DIR = os.path.join(NMODL_DIR, "includes")  
os.makedirs(NMODL_DIR, exist_ok=True)
os.makedirs(INCLUDE_DIR, exist_ok=True)

successful_mod_count = 0
failed_mod_count = 0
include_files_found = 0
successful_include_count = 0
failed_include_count = 0
already_downloaded_includes = set()  
failed_file_hashes = [] 

print(f"Loading metadata from {JSON_FP}")
json_df = pd.read_json(JSON_FP)
print(f"Loaded metadata with {len(json_df)} entries")

print(f"Loading annotations from {ANNOTATIONS_FP}")
annotations_df = pd.read_excel(ANNOTATIONS_FP)
annotated_hashes = annotations_df.query("annotated=='y'")["file_hash"].tolist()
print(f"Found {len(annotated_hashes)} annotated samples")

filtered_df = json_df[json_df["file_hash"].isin(annotated_hashes)]
print(f"Processing {len(filtered_df)} annotated MOD files")

for _, row in tqdm(filtered_df.iterrows(), total=len(filtered_df), desc="Downloading MOD files"):
    try:
        url = row["download_url"]
        file_hash = row["file_hash"]
        
        output_path = os.path.join(NMODL_DIR, f"{file_hash}.mod")
        success, content = download_file(url, output_path, file_hash)
        
        if success:
            successful_mod_count += 1
            
            if content:
                try:
                    content_text = content.decode('utf-8', errors='ignore')
                    include_files = get_includes(content_text)
                    
                    if include_files:
                        include_files_found += len(include_files)
                        
                        # Download each include file
                        for include_file in include_files:
                            # Skip if we've already downloaded this include file
                            if include_file in already_downloaded_includes:
                                continue
                            
                            include_url = create_include_download_url(url, include_file)
                            
                            if include_url:
                                # Download the include file
                                include_path = os.path.join(INCLUDE_DIR, include_file)
                                include_success, _ = download_file(include_url, include_path, file_hash)
                                
                                if include_success:
                                    successful_include_count += 1
                                    already_downloaded_includes.add(include_file)
                                    print(f"Downloaded include file: {include_file}")
                                else:
                                    failed_include_count += 1
                                    print(f"Failed to download include file: {include_file} from URL: {include_url} (file_hash: {file_hash})")
                            else:
                                failed_include_count += 1
                                print(f"Could not generate URL for include file: {include_file} from MOD URL: {url} (file_hash: {file_hash})")
                except Exception as e:
                    print(f"Error processing content for includes: {e} (file_hash: {file_hash})")
        else:
            failed_mod_count += 1
            failed_file_hashes.append(file_hash)
            
    except Exception as e:
        error_msg = f"Error processing {url}: {e}"
        print(f"Error processing {url}: {e} (file_hash: {file_hash})")
        
        failed_mod_count += 1
        failed_file_hashes.append(file_hash)

stats_message = (
    f"\nTotal MOD files processed: {len(filtered_df)}, "
    f"Successfully downloaded: {successful_mod_count}, "
    f"Failed downloads: {failed_mod_count}\n"
    f"Total include files found: {include_files_found}, "
    f"Successfully downloaded: {successful_include_count}, "
    f"Failed downloads: {failed_include_count}, "
    f"Unique include files: {len(already_downloaded_includes)}"
)
print(stats_message)

if failed_mod_count > 0:
    print(f"\nFailed file hashes ({len(failed_file_hashes)}):")
    for fh in failed_file_hashes:
        print(f"  {fh}")
else:
    print("All downloads completed successfully")

if failed_file_hashes:
    failed_hashes_fp = os.path.join(LOGS_DIR, f"failed_file_hashes_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    with open(failed_hashes_fp, "w") as f:
        for fh in failed_file_hashes:
            f.write(f"{fh}\n")
    print(f"Failed file hashes written to: {failed_hashes_fp}")