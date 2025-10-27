#!/bin/bash
# Activate your environment
source ~/.bashrc
conda activate mod-annotation

# === CONFIG ===
root_dir="/nfs/roberts/project/pi_rm693/imc33/mod-annotation/data/raw/dropbox_compiled"
script_path="/nfs/roberts/project/pi_rm693/imc33/mod-annotation/code/_get_mod_dynamics.py"
n_steps=10   # or however many you want

# === LOOP OVER ALL MODEL FOLDERS ===
find "$root_dir" -mindepth 2 -maxdepth 2 -type f -name "*.mod" | while read -r modfile; do
    echo "=== Running simulation for $modfile ==="
    python "$script_path" "$modfile" "$n_steps"
done
