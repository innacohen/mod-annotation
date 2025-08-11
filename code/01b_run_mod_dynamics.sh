#!/bin/bash

# Set paths
modroot="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/nmodl"
script_path="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/code/_get_mod_dynamics.py"
logroot="/gpfs/gibbs/project/mcdougal/imc33/mod-extract/logs"

mkdir -p "$logroot"
summary_log="$logroot/run_log.txt"
echo "Log started at $(date)" > "$summary_log"

# Global timer start
global_start=$(date +%s)

# Loop over all .mod files
for modfile in "$modroot"/*.mod; do
    fname=$(basename "$modfile")
    tempdir=$(mktemp -d /tmp/modwork_XXXXXX)
    logfile="$logroot/${fname%.mod}.log"

    echo "==== Processing $fname ====" | tee -a "$summary_log"

    cp "$modfile" "$tempdir/"
    cd "$tempdir" || exit 1

    # Per-file timer
    start_time=$(date +%s)

    # Compile
    nrnivmodl "$fname" > "$logfile" 2>&1
    if [ $? -ne 0 ]; then
        echo "Compilation failed for $fname" | tee -a "$summary_log"
        echo "See $logfile for details"
        cd - >/dev/null
        rm -rf "$tempdir"
        continue
    fi

    # Run simulation
    echo "Compilation succeeded. Running simulation..." >> "$logfile"
    python "$script_path" "$modfile" 10 >> "$logfile" 2>&1
    if [ $? -ne 0 ]; then
        echo "Python simulation failed for $fname" | tee -a "$summary_log"
        echo "See $logfile for details"
    else
        echo "Successfully processed $fname" | tee -a "$summary_log"
    fi

    # Per-file duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "Duration for $fname: ${duration} seconds" | tee -a "$summary_log"

    cd - >/dev/null
    rm -rf "$tempdir"
done

# Global timer end
global_end=$(date +%s)
total_duration=$((global_end - global_start))

echo "Total runtime: ${total_duration} seconds" | tee -a "$summary_log"
echo "Log finished at $(date)" >> "$summary_log"