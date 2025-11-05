#note: need to activate mod-annotation conda environment, otherwise will not run. 
from _utils import *
from datetime import datetime
from tqdm import tqdm
import sys

class TeeOutput:
    """Write to both file and original stdout/stderr"""
    def __init__(self, file_obj, original):
        self.file = file_obj
        self.original = original
    
    def write(self, data):
        self.file.write(data)
        self.file.flush()
        self.original.write(data)
    
    def flush(self):
        self.file.flush()
        self.original.flush()

# Find the most recent compilation log
log_files = sorted(LOGS_DIR.glob("compilation_log_*.txt"))
if not log_files:
    print("No compilation log found. Please run the compilation script first.")
    exit()

latest_log = log_files[-1]
print(f"Reading failed models from: {latest_log}")

# Parse the log file to extract failed model names
failed_models = []
with open(latest_log, 'r') as f:
    in_failed_section = False
    for line in f:
        if "FAILED COMPILATION" in line:
            in_failed_section = True
            continue
        if "SKIPPED - NO MOD FILES" in line:
            in_failed_section = False
            break
        if in_failed_section and line.strip().startswith("✗"):
            # Extract model name (between ✗ and newline)
            model_name = line.strip().split("✗")[1].strip()
            failed_models.append(model_name)

if not failed_models:
    print("No failed models found in the log!")
    exit()

# Create output log file
output_log_file = LOGS_DIR / f"recompile_output_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
output_log = open(output_log_file, 'w', buffering=1)

# Redirect stdout and stderr to both file and console
original_stdout = sys.stdout
original_stderr = sys.stderr
sys.stdout = TeeOutput(output_log, original_stdout)
sys.stderr = TeeOutput(output_log, original_stderr)

print(f"\nFound {len(failed_models)} failed models. Re-running with detailed errors...")
print(f"Output being saved to: {output_log_file}\n")
print("=" * 80)

still_failed = []
now_compiled = []

# Re-run ONLY the failed compilations with full error output
for model_name in tqdm(failed_models, desc="Re-compiling failed models", unit="model"):
    model_dir = NMODL_DIR / model_name
    
    if not model_dir.exists():
        tqdm.write(f"\n⚠ Directory not found: {model_name}")
        continue
    
    # Remove any existing compilation artifacts to force re-compilation
    x86_64_dir = model_dir / "x86_64"
    if x86_64_dir.exists():
        import shutil
        shutil.rmtree(x86_64_dir)
    
    tqdm.write(f"\n{'='*80}")
    tqdm.write(f"MODEL: {model_name}")
    tqdm.write(f"{'='*80}")
    
    mod_files = list(model_dir.glob("*.mod"))
    tqdm.write(f"MOD files found: {len(mod_files)}")
    for mod_file in mod_files:
        tqdm.write(f"  - {mod_file.name}")
    
    tqdm.write("\nRunning nrnivmodl...\n")
    
    try:
        result = subprocess.run(
            ["nrnivmodl"], 
            cwd=model_dir, 
            capture_output=True, 
            text=True,
            check=True
        )
        tqdm.write(f"✓ SUCCESS (compiled this time)")
        now_compiled.append(model_name)
    except subprocess.CalledProcessError as e:
        tqdm.write(f"✗ FAILED with return code {e.returncode}")
        if e.stdout:
            tqdm.write("\nSTDOUT:")
            tqdm.write(e.stdout)
        if e.stderr:
            tqdm.write("\nSTDERR:")
            tqdm.write(e.stderr)
        still_failed.append(model_name)
    
    tqdm.write("")  # Empty line for spacing

# Restore original stdout/stderr
sys.stdout = original_stdout
sys.stderr = original_stderr
output_log.close()

print(f"\n{'='*80}")
print("Re-compilation complete!")
print(f"Total failed models processed: {len(failed_models)}")
print(f"Still failing: {len(still_failed)}")
print(f"Now compiling successfully: {len(now_compiled)}")
print(f"\nFull output saved to: {output_log_file}")