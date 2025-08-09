# Set base directory and subfolders
base_dir = Path("/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw")
folders = ["sim_csvs_10", "sim_csvs_-80"]

# Storage for separate dataframes
raw_sim_df_10 = []
raw_sim_df_80 = []

# Loop through both folders
for folder_name in folders:
    folder_path = base_dir / folder_name
    for file in folder_path.glob("*.csv"):
        df = pd.read_csv(file)
        df["source_file"] = file.name
        df["source_folder"] = folder_name
        # Extract mod_file from filename
        df["mod_file"] = file.name.replace(".csv", "").split("__")[-1]

        if folder_name == "sim_csvs_10":
            raw_sim_df_10.append(df)
        elif folder_name == "sim_csvs_-80":
            raw_sim_df_80.append(df)

# Concatenate and deduplicate
if raw_sim_df_10:
    raw_sim_df_10 = pd.concat(raw_sim_df_10, ignore_index=True).drop_duplicates()
    raw_sim_df_10.to_csv(base_dir / "sim_features_10_combined.csv", index=False)
    print("Saved 10 mV sim features to sim_features_10_combined.csv")
else:
    print("No files found in sim_csvs_10")

if raw_sim_df_80:
    raw_sim_df_80 = pd.concat(raw_sim_df_80, ignore_index=True).drop_duplicates()
    raw_sim_df_80.to_csv(base_dir / "sim_features_80_combined.csv", index=False)
    print("Saved -80 mV sim features to sim_features_80_combined.csv")
else:
    print("No files found in sim_csvs_-80")

raw_sim_df_10.shape

raw_sim_df_80.shape

# Ensure we're not modifying original DataFrames
df_10 = raw_sim_df_10.copy()
df_80 = raw_sim_df_80.copy()

# Drop columns that don't need suffixing
cols_to_exclude = ["mod_file", "source_file", "source_folder"]

# Rename columns with suffixes
df_10 = df_10.rename(columns={col: f"{col}_10" for col in df_10.columns if col not in cols_to_exclude})
df_80 = df_80.rename(columns={col: f"{col}_-80" for col in df_80.columns if col not in cols_to_exclude})

# Keep mod_file for merging
df_10["mod_file"] = raw_sim_df_10["mod_file"]
df_80["mod_file"] = raw_sim_df_80["mod_file"]

# Drop duplicate rows just in case
df_10 = df_10.drop_duplicates(subset=["mod_file"])
df_80 = df_80.drop_duplicates(subset=["mod_file"])

# Merge side-by-side
combined_df = pd.merge(df_10, df_80, on="mod_file", how="outer")

# Save to file
combined_df.to_csv("/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/sim_features_wide.csv", index=False)
print("Merged wide-format DataFrame saved to sim_features_wide.csv")

import pandas as pd

# Copy originals to avoid modifying upstream variables
df_10 = raw_sim_df_10.copy()
df_80 = raw_sim_df_80.copy()

# Columns that should NOT be suffixed
id_col = "mod_file"
exclude_cols = ["source_file", "source_folder"]

# Suffix all non-ID, non-excluded columns
df_10 = df_10.rename(columns={col: f"{col}_10" for col in df_10.columns if col not in exclude_cols + [id_col]})
df_80 = df_80.rename(columns={col: f"{col}_-80" for col in df_80.columns if col not in exclude_cols + [id_col]})

# Keep mod_file column for merge
df_10["mod_file"] = raw_sim_df_10["mod_file"]
df_80["mod_file"] = raw_sim_df_80["mod_file"]

# Optional: deduplicate in case of multiple rows per mod_file
df_10 = df_10.drop_duplicates(subset="mod_file")
df_80 = df_80.drop_duplicates(subset="mod_file")

# Merge on mod_file
combined_df = pd.merge(df_10, df_80, on="mod_file", how="outer")

# Drop any leftover source_* columns
combined_df = combined_df.drop(columns=[
    col for col in combined_df.columns if col.startswith("source_file") or col.startswith("source_folder")
])

# Save result
combined_df.to_csv("/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/sim_features_wide.csv", index=False)
print("Final wide-format DataFrame saved (source_* columns removed)")
