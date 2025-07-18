#!/bin/bash

# Root directory containing all mod repositories
ROOT_DIR="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/nmodl"
SCRIPT_PATH="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/code/_get_mod_dynamics.py"

# Temporary working directory
WORK_DIR="/tmp/modwork"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit

# Find all .mod files nested within ROOT_DIR
find "$ROOT_DIR" -type f -name "*.mod" > all_mods.txt

# Copy mod files into the working directory
while IFS= read -r modfile; do
    cp "$modfile" .
done < all_mods.txt

# Compile all mod files together
nrnivmodl *.mod

# Run simulation on each mod file
for modfile in *.mod; do
    echo "Running simulation for $modfile"
    python "$SCRIPT_PATH" "$modfile" 10
done
