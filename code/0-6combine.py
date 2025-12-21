from _utils import *
folder_path = SIM_CSV_DIR

# Read & combine all CSVs
dfs = []
for file in folder_path.glob("*.csv"):
    df = pd.read_csv(file)
    df["source_file"] = file.name
    df["source_folder"] = folder_path.name
    df["mod_file"] = file.stem.split("__")[-1]
    dfs.append(df)

if not dfs:
    raise FileNotFoundError(f"No CSV files found in {folder_path}")

# Concatenate and drop duplicates
combined_df = pd.concat(dfs, ignore_index=True).drop_duplicates()

# Save combined file
out_path = PIPELINE_DATA_DIR / "sim_features_combined.csv"

combined_df.to_csv(out_path, index=False)
print(f"Saved combined sim features to {out_path}")
