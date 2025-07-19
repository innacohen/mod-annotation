from pathlib import Path
import shutil

# Root directory containing nested .mod files
modroot = Path("/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/nmodl")

# Iterate over all .mod files nested under modroot
for mod_file in modroot.rglob("*.mod"):
    if mod_file.parent == modroot:
        continue  # Already at root, skip

    # Build a unique name: subdir1_subdir2__filename.mod
    relative_path = mod_file.relative_to(modroot)
    subdir_parts = relative_path.parts[:-1]  # All but the file name
    subdir_prefix = "_".join(subdir_parts)
    new_name = f"{subdir_prefix}__{mod_file.name}"
    dest = modroot / new_name

    # Move the file
    print(f"Moving: {mod_file} → {dest}")
    shutil.move(str(mod_file), str(dest))

# Remove any empty directories left behind
for subdir in sorted(modroot.rglob("*"), reverse=True):
    if subdir.is_dir() and not any(subdir.iterdir()):
        print(f"Removing empty directory: {subdir}")
        subdir.rmdir()
