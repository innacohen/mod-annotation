#!/bin/bash

# Set paths
modroot="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/nmodl"
script_path="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/code/_get_mod_dynamics.py"

# Loop over all .mod files
for modfile in "$modroot"/*.mod; do
    fname=$(basename "$modfile")
    tempdir=$(mktemp -d /tmp/modwork_XXXXXX)

    echo "==== Processing $fname ===="
    echo "Working in $tempdir"

    # Copy .mod file to temp dir and compile it
    cp "$modfile" "$tempdir/"
    cd "$tempdir" || exit 1
    nrnivmodl "$fname"

    # If compilation fails, skip to next
    if [ $? -ne 0 ]; then
        echo "Compilation failed for $fname. Skipping."
        cd - >/dev/null
        rm -rf "$tempdir"
        continue
    fi

    # Run the Python dynamics extraction script
    echo "Running Python simulation for $fname"
    python "$script_path" "$modfile" 10

    # Go back and clean up
    cd - >/dev/null
    rm -rf "$tempdir"
done
