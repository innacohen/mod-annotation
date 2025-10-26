from _utils import *


base_path = Path(DROPBOX_DIR)         
output_base = Path(DROPBOX_DIR2)      
output_base.mkdir(parents=True, exist_ok=True)

NRNIVMODL = "/home/imc33/.conda/envs/mod-annotation/bin/nrnivmodl"

# === find zip files ===
zip_files = list(base_path.glob("*.zip"))
print(f"Found {len(zip_files)} total zip files")

for zip_file in tqdm(zip_files, desc="Extracting all ZIPs"):
    target_folder = output_base / zip_file.stem
    target_folder.mkdir(parents=True, exist_ok=True)

    try:
        with zipfile.ZipFile(zip_file, 'r') as zip_ref:
            zip_ref.extractall(target_folder)
    except Exception as e:
        print(f"Failed to unzip {zip_file.name}: {e}")
        continue

    # recursively compile any .mod files
    for root, dirs, files in os.walk(target_folder):
        if any(file.endswith(".mod") for file in files):
            try:
                subprocess.run([NRNIVMODL], cwd=root, check=True)
            except subprocess.CalledProcessError as e:
                print(f"nrnivmodl failed in {root}: {e}")
            except FileNotFoundError:
                print(f"nrnivmodl not found at {NRNIVMODL}")
