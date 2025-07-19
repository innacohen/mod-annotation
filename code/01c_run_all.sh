#!/bin/bash

# Absolute paths
moddir="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/nmodl"
codedir="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/code"
workdir="/tmp/mod_compile_temp"

# Loop over each .mod file
for modfile in "$moddir"/*.mod; do
    filename=$(basename "$modfile")
    echo "Processing $filename"

    # Prepare clean compile dir
    rm -rf "$workdir"
    mkdir -p "$workdir"

    # Copy .mod file to temp dir and compile
    cp "$modfile" "$workdir"
    (cd "$workdir" && nrnivmodl)

    # Run dynamics script if compilation succeeded
    if [ -f "$workdir/x86_64/special" ]; then
        echo "Compiled $filename successfully"
        python "$codedir/_get_mod_dynamics.py" "$modfile" 10
    else
        echo "Compilation failed for $filename"
    fi
done
