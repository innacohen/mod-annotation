#note: need to activate mod-annotation conda environment, otherwise will not run. 
from _utils import *
from datetime import datetime
from tqdm import tqdm

# Initialize tracking lists
compiled_models = []
failed_models = []
skipped_models = []

# Create log file path
log_file = LOGS_DIR / f"compilation_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"

# Get all model directories
model_dirs = sorted([d for d in NMODL_DIR.iterdir() if d.is_dir()])

# Iterate through folders with progress bar
for model_dir in tqdm(model_dirs, desc="Compiling models", unit="model"):
    mod_files = list(model_dir.glob("*.mod"))
    
    if mod_files:
        tqdm.write(f"Compiling MOD files for model: {model_dir.name}")
        try:
            subprocess.run(["nrnivmodl"], cwd=model_dir, check=True, 
                         capture_output=True)  # Suppress nrnivmodl output
            tqdm.write(f"✓ Successfully compiled: {model_dir.name}")
            compiled_models.append(model_dir.name)
        except subprocess.CalledProcessError as e:
            tqdm.write(f"✗ Failed to compile {model_dir.name}")
            failed_models.append((model_dir.name, str(e)))
    else:
        tqdm.write(f"- No .mod files found in {model_dir.name}, skipping.")
        skipped_models.append(model_dir.name)

# Write log file
with open(log_file, 'w') as f:
    f.write("=" * 80 + "\n")
    f.write("MOD FILE COMPILATION LOG\n")
    f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write("=" * 80 + "\n\n")
    
    f.write(f"SUMMARY\n")
    f.write(f"{'='*80}\n")
    f.write(f"Total models processed: {len(compiled_models) + len(failed_models) + len(skipped_models)}\n")
    f.write(f"Successfully compiled: {len(compiled_models)}\n")
    f.write(f"Failed compilation: {len(failed_models)}\n")
    f.write(f"Skipped (no .mod files): {len(skipped_models)}\n\n")
    
    f.write(f"SUCCESSFULLY COMPILED ({len(compiled_models)})\n")
    f.write(f"{'='*80}\n")
    for model in compiled_models:
        f.write(f"  ✓ {model}\n")
    
    f.write(f"\nFAILED COMPILATION ({len(failed_models)})\n")
    f.write(f"{'='*80}\n")
    for model, error in failed_models:
        f.write(f"  ✗ {model}\n")
        f.write(f"    Error: {error}\n")
    
    f.write(f"\nSKIPPED - NO MOD FILES ({len(skipped_models)})\n")
    f.write(f"{'='*80}\n")
    for model in skipped_models:
        f.write(f"  - {model}\n")

print(f"\n{'='*80}")
print(f"Compilation complete!")
print(f"Log file saved to: {log_file}")
print(f"Successfully compiled: {len(compiled_models)}")
print(f"Failed: {len(failed_models)}")
print(f"Skipped: {len(skipped_models)}")