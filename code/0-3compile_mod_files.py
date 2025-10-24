from _utils import *
import pandas as pd
import subprocess
import zipfile
import tqdm
from pathlib import Path

raw_json_df = pd.read_json(JSON_FP)
MODEL_IDS = set(map(str, raw_json_df["model_id"].tolist()))  # use set for fast lookup
print(f"Loaded {len(MODEL_IDS)} model IDs")

base_path = Path(DROPBOX_DIR)
working_dir = Path.cwd()

zip_files = [
    item for item in base_path.iterdir()
    if item.suffix == ".zip" and item.stem in MODEL_IDS
]
print(f"Found {len(zip_files)} matching zip files out of {len(list(base_path.glob('*.zip')))} total")

for zip_file in tqdm.tqdm(zip_files, desc="Extracting matching ZIPs"):
    target_folder = working_dir / "modeldb" / zip_file.stem
    target_folder.mkdir(parents=True, exist_ok=True)

    try:
        with zipfile.ZipFile(zip_file, 'r') as zip_ref:
            zip_ref.extractall(target_folder)
    except Exception as e:
        print(f"Failed to unzip {zip_file.name}: {e}")
        continue

    for root, dirs, files in os.walk(target_folder):
        if any(file.endswith('.mod') for file in files):
            try:
                subprocess.run(["nrnivmodl"], cwd=root, check=True)
            except subprocess.CalledProcessError as e:
                print(f"nrnivmodl failed in {root}: {e}")
