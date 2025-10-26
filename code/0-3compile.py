from _utils import *


# === CONFIG ===
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_FILE_FP = os.path.join(LOGS_DIR, f"0-3nmodl_compile_log_{TIMESTAMP}.log")

logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

base_path = Path(NMODL_DIR)
output_base = Path(NMODL_DIR)
NRNIVMODL = "/home/imc33/.conda/envs/mod-annotation/bin/nrnivmodl"

print(f"Starting compilation in: {base_path}")
model_dirs = [p for p in base_path.iterdir() if p.is_dir()]
print(f"Found {len(model_dirs)} model directories to compile")

successful_count = 0
failed_count = 0

# === MAIN LOOP ===
for model_dir in tqdm(model_dirs, desc="Compiling model directories"):
    try:
        subprocess.run(
            [NRNIVMODL],
            cwd=model_dir,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        msg = f"SUCCESS: Compiled model_id {model_dir.name}"
        print(msg)
        logging.info(msg)
        successful_count += 1

    except subprocess.CalledProcessError as e:
        msg = f"FAILED: nrnivmodl failed in {model_dir} - {e}"
        print(msg)
        logging.error(msg)
        failed_count += 1

    except FileNotFoundError:
        msg = f"ERROR: nrnivmodl not found at {NRNIVMODL}. Please check NEURON installation."
        print(msg)
        logging.error(msg)
        failed_count += 1
        break

# === SUMMARY ===
summary = (
    f"\n=== COMPILE SUMMARY ===\n"
    f"Total model directories: {len(model_dirs)}\n"
    f"Successfully compiled: {successful_count}\n"
    f"Failed compilations: {failed_count}\n"
    f"Log file written to: {LOG_FILE_FP}\n"
)

print(summary)
logging.info(summary)
