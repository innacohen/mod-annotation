from _utils import *

# Configure paths and settings
TIMESTAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
LOGS_DIR.mkdir(parents=True, exist_ok=True)
LOG_FP = LOGS_DIR / f"0-3mod_compilation_log_{TIMESTAMP}.txt"
SUMMARY_JSON_FP = LOGS_DIR / f"mod_compilation_summary_{TIMESTAMP}.json"

base_path = Path(DROPBOX_DIR)
output_base = Path(COMPILED_DIR)
output_base.mkdir(parents=True, exist_ok=True)

NRNIVMODL = "/home/imc33/.conda/envs/mod-annotation/bin/nrnivmodl"

# Initialize tracking variables
processed_zips = 0
successful_extractions = 0
failed_extractions = []
successful_compilations = 0
failed_compilations = []
compilation_details = []

# Find zip files
zip_files = list(base_path.glob("*.zip"))
total_zip_files = len(zip_files)
print(f"Found {total_zip_files} total zip files")

# Start logging
with open(LOG_FP, "w", encoding="utf-8") as log_file:
    log_file.write(f"=== MOD File Compilation Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Found {total_zip_files} total zip files\n\n")
    log_file.write("=== EXTRACTION AND COMPILATION DETAILS ===\n")
    
    for zip_file in tqdm(zip_files, desc="Processing ZIP files"):
        processed_zips += 1
        target_folder = output_base / zip_file.stem
        target_folder.mkdir(parents=True, exist_ok=True)
        
        zip_record = {
            "zip_file": str(zip_file),
            "target_folder": str(target_folder),
            "extraction_status": "SUCCESS",
            "extraction_error": None,
            "compilation_attempts": 0,
            "successful_compilations": 0,
            "failed_compilations": 0,
            "compilation_details": []
        }
        
        # Extract the zip file
        try:
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                zip_ref.extractall(target_folder)
            log_file.write(f"EXTRACTION SUCCESS: {zip_file.name} -> {target_folder}\n")
            successful_extractions += 1
        except Exception as e:
            error_msg = f"EXTRACTION FAILED: {zip_file.name} - Error: {str(e)}"
            print(error_msg)
            log_file.write(f"{error_msg}\n")
            zip_record["extraction_status"] = "FAILED"
            zip_record["extraction_error"] = str(e)
            failed_extractions.append(zip_file.name)
            compilation_details.append(zip_record)
            continue
        
        # Recursively compile any .mod files
        mod_dirs_found = 0
        for root, dirs, files in os.walk(target_folder):
            if any(file.endswith(".mod") for file in files):
                mod_dirs_found += 1
                mod_files = [f for f in files if f.endswith(".mod")]
                compilation_record = {
                    "directory": root,
                    "mod_files": mod_files,
                    "status": "SUCCESS",
                    "error": None
                }
                
                zip_record["compilation_attempts"] += 1
                
                try:
                    log_file.write(f"COMPILING: {len(mod_files)} .mod files in {root}\n")
                    subprocess.run([NRNIVMODL], cwd=root, check=True, 
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    log_file.write(f"COMPILATION SUCCESS: {root}\n")
                    successful_compilations += 1
                    zip_record["successful_compilations"] += 1
                except subprocess.CalledProcessError as e:
                    error_msg = f"COMPILATION FAILED: nrnivmodl failed in {root} - Error: {e}"
                    print(error_msg)
                    log_file.write(f"{error_msg}\n")
                    compilation_record["status"] = "FAILED"
                    compilation_record["error"] = f"CalledProcessError: {e}"
                    failed_compilations.append(root)
                    zip_record["failed_compilations"] += 1
                except FileNotFoundError:
                    error_msg = f"COMPILATION FAILED: nrnivmodl not found at {NRNIVMODL}"
                    print(error_msg)
                    log_file.write(f"{error_msg}\n")
                    compilation_record["status"] = "FAILED"
                    compilation_record["error"] = f"FileNotFoundError: nrnivmodl not found at {NRNIVMODL}"
                    failed_compilations.append(root)
                    zip_record["failed_compilations"] += 1
                
                zip_record["compilation_details"].append(compilation_record)
        
        if mod_dirs_found == 0:
            log_file.write(f"NOTE: No .mod files found in {zip_file.name}\n")
        
        compilation_details.append(zip_record)
    
    # Calculate statistics
    no_mod_files = sum(1 for record in compilation_details 
                     if record["extraction_status"] == "SUCCESS" and record["compilation_attempts"] == 0)
    
    # Write summary to log
    summary = f"\n=== COMPILATION SUMMARY ===\n"
    summary += f"Total ZIP files processed: {processed_zips} / {total_zip_files}\n"
    summary += f"Successful extractions: {successful_extractions}\n"
    summary += f"Failed extractions: {len(failed_extractions)}\n"
    summary += f"ZIPs with no .mod files: {no_mod_files}\n"
    summary += f"Total compilation attempts: {successful_compilations + len(failed_compilations)}\n"
    summary += f"Successful compilations: {successful_compilations}\n"
    summary += f"Failed compilations: {len(failed_compilations)}\n"
    
    print(summary)
    log_file.write(summary)
    
    # List all failed extractions in the same log file
    if failed_extractions:
        log_file.write(f"\n=== FAILED EXTRACTIONS ({len(failed_extractions)}) ===\n")
        for fh in failed_extractions:
            log_file.write(f"{fh}\n")
    
    # List all failed compilations in the same log file
    if failed_compilations:
        log_file.write(f"\n=== FAILED COMPILATIONS ({len(failed_compilations)}) ===\n")
        for fh in failed_compilations:
            log_file.write(f"{fh}\n")

# Save the detailed compilation data to JSON
with open(SUMMARY_JSON_FP, "w", encoding="utf-8") as json_file:
    json.dump(compilation_details, json_file, indent=4)

# Print location of log files
print(f"Complete log written to: {LOG_FP}")
print(f"Compilation details saved to: {SUMMARY_JSON_FP}")