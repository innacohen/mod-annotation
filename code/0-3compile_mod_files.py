from _utils import *


raw_json_df["model_id"].tolist()


# base path
base_path = DROPBOX_DIR
working_dir = Path.cwd()

zip_files = [item for item in base_path.iterdir() if item.suffix == '.zip']

# for each zip file, unzip it into a folder with the same name (without .zip)
for zip_file in tqdm.tqdm(zip_files):
    # create target folder with the zip file name (without .zip extension)
    target_folder = working_dir / "modeldb" / zip_file.stem
    target_folder.mkdir(exist_ok=True)
    
    with zipfile.ZipFile(zip_file, 'r') as zip_ref:
        zip_ref.extractall(target_folder)
    
    # recursively descend into target folder, check for mod file presence, run os.system("nrnivmodl") in folders with mod files
    for root, dirs, files in os.walk(target_folder):
        if any(file.endswith('.mod') for file in files):
            try:
                subprocess.run(["nrnivmodl"], cwd=root, check=True)
            except subprocess.CalledProcessError as e:
                print(f"nrnivmodl failed in {root}: {e}")

