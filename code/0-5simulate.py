#note: need to activate mod-annotation conda environment, otherwise will not run. 
from _utils import *
from tqdm import tqdm
import subprocess

# === CONFIG ===
root_dir = NMODL_DIR
script_path = CODE_DIR / "_get_mod_dynamics.py"
n_steps = 10

print(f"Root directory: {root_dir}")
print(f"Script path: {script_path}")
print(f"Number of voltage steps: {n_steps}")

if not script_path.exists():
    print(f"ERROR: Script not found at {script_path}")
    sys.exit(1)

# Find all .mod files
mod_files = list(root_dir.glob("*/*.mod"))
print(f"\nFound {len(mod_files)} MOD files to process\n")

# Track results

successful = []
failed = []

# Loop over all MOD files
for modfile in tqdm(mod_files, desc="Running simulations", unit="file"):
    model_dir = modfile.parent
    
    tqdm.write(f"\n{'='*80}")
    tqdm.write(f"Running simulation for: {modfile.name}")
    tqdm.write(f"Model directory: {model_dir}")
    
    try:
        # Run the simulation script from the model directory
        result = subprocess.run(
            ["python", str(script_path), str(modfile), str(n_steps)],
            cwd=model_dir,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout per simulation
        )
        
        if result.returncode == 0:
            tqdm.write(f"✓ SUCCESS: {modfile.name}")
            successful.append(modfile.name)
            # Optionally print the output
            if result.stdout:
                tqdm.write(result.stdout)
        else:
            tqdm.write(f"✗ FAILED: {modfile.name} (return code: {result.returncode})")
            if result.stderr:
                tqdm.write(f"STDERR:\n{result.stderr}")
            failed.append((modfile.name, result.returncode, result.stderr))
            
    except subprocess.TimeoutExpired:
        tqdm.write(f"✗ TIMEOUT: {modfile.name} (exceeded 5 minutes)")
        failed.append((modfile.name, "timeout", "Simulation exceeded 5 minute timeout"))
    except Exception as e:
        tqdm.write(f"✗ ERROR: {modfile.name} - {e}")
        failed.append((modfile.name, "exception", str(e)))

# Save summary log
log_file = LOGS_DIR / f"simulation_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
with open(log_file, 'w') as f:
    f.write("=" * 80 + "\n")
    f.write("MOD FILE SIMULATION LOG\n")
    f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write("=" * 80 + "\n\n")
    
    f.write(f"SUMMARY\n")
    f.write(f"{'='*80}\n")
    f.write(f"Total MOD files processed: {len(mod_files)}\n")
    f.write(f"Successful simulations: {len(successful)}\n")
    f.write(f"Failed simulations: {len(failed)}\n\n")
    
    f.write(f"SUCCESSFUL SIMULATIONS ({len(successful)})\n")
    f.write(f"{'='*80}\n")
    for mod_name in successful:
        f.write(f"  ✓ {mod_name}\n")
    
    f.write(f"\nFAILED SIMULATIONS ({len(failed)})\n")
    f.write(f"{'='*80}\n")
    for mod_name, error_type, error_msg in failed:
        f.write(f"  ✗ {mod_name}\n")
        f.write(f"    Error type: {error_type}\n")
        if error_msg:
            f.write(f"    Error message: {error_msg[:200]}...\n" if len(error_msg) > 200 else f"    Error message: {error_msg}\n")
        f.write("\n")

print(f"\n{'='*80}")
print("Simulation batch complete!")
print(f"Total processed: {len(mod_files)}")
print(f"Successful: {len(successful)}")
print(f"Failed: {len(failed)}")
print(f"\nLog saved to: {log_file}")