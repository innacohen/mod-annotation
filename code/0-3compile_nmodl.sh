#!/bin/bash
# Script to compile MOD files

# Set paths for Boucher cluster
modroot="/nfs/roberts/project/pi_rm693/imc33/mod-annotation/data/raw/nmodl"
logroot="/nfs/roberts/project/pi_rm693/imc33/mod-annotation/logs"
compiled_dir="/nfs/roberts/project/pi_rm693/imc33/mod-annotation/data/compiled_mod"

# Create directories if they don't exist
mkdir -p "$logroot"
mkdir -p "$compiled_dir"

# Log file
compilation_log="$logroot/compilation_log_$(date +%Y%m%d_%H%M%S).txt"
success_list="$logroot/compiled_success_$(date +%Y%m%d_%H%M%S).txt"
failed_list="$logroot/compiled_failed_$(date +%Y%m%d_%H%M%S).txt"

# Initialize log files
echo "=== MOD Files Compilation Log ===" > "$compilation_log"
echo "Started at: $(date)" >> "$compilation_log"
echo "MOD directory: $modroot" >> "$compilation_log"
echo "Compiled output directory: $compiled_dir" >> "$compilation_log"
echo "" >> "$compilation_log"

# Create success and failure tracking files
touch "$success_list"
touch "$failed_list"

# Global timer start
global_start=$(date +%s)

# Count total files
total_files=$(find "$modroot" -name "*.mod" | wc -l)
echo "Found $total_files MOD files to compile" | tee -a "$compilation_log"

# Counters for tracking
successful=0
failed=0
processed=0

# Process each MOD file
for modfile in "$modroot"/*.mod; do
    # Skip if file doesn't exist (in case the glob doesn't match anything)
    if [ ! -f "$modfile" ]; then
        continue
    fi
    
    fname=$(basename "$modfile")
    file_log="$logroot/${fname%.mod}_compile.log"
    tempdir=$(mktemp -d /tmp/modwork_XXXXXX)
    
    echo "==== Compiling $fname ====" | tee -a "$compilation_log" "$file_log"
    
    # Start timer for this file
    start_time=$(date +%s)
    
    # Copy .mod file to temp dir
    cp "$modfile" "$tempdir/" >> "$file_log" 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to copy $fname to temp directory" | tee -a "$compilation_log" "$file_log" "$failed_list"
        rm -rf "$tempdir"
        failed=$((failed + 1))
        continue
    fi
    
    # Change to temp directory
    cd "$tempdir" || {
        echo "Failed to change to temp directory for $fname" | tee -a "$compilation_log" "$file_log" "$failed_list"
        rm -rf "$tempdir"
        failed=$((failed + 1))
        continue
    }
    
    # Compile MOD file
    echo "Running nrnivmodl..." >> "$file_log"
    nrnivmodl "$fname" >> "$file_log" 2>&1
    
    # Check if compilation succeeded
    if [ $? -ne 0 ]; then
        echo "Compilation failed for $fname" | tee -a "$compilation_log" "$file_log" "$failed_list"
        cd - >/dev/null
        rm -rf "$tempdir"
        failed=$((failed + 1))
        continue
    fi
    
    # If compilation succeeded, copy the compiled files to the output directory
    compiled_subdir="$compiled_dir/${fname%.mod}"
    mkdir -p "$compiled_subdir"
    
    # Copy the original MOD file
    cp "$modfile" "$compiled_subdir/"
    
    # Copy the compiled library
    if [ -d "x86_64" ]; then
        cp -r "x86_64" "$compiled_subdir/"
        echo "Compiled library saved to $compiled_subdir/x86_64" >> "$file_log"
    fi
    
    # Calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Record success
    echo "Successfully compiled $fname (${duration} seconds)" | tee -a "$compilation_log" "$file_log"
    echo "$fname,$compiled_subdir" >> "$success_list"
    successful=$((successful + 1))
    
    # Clean up
    cd - >/dev/null
    rm -rf "$tempdir"
    
    # Update processed count and show progress
    processed=$((processed + 1))
    echo -ne "Progress: $processed/$total_files (${successful} successful, ${failed} failed)\r"
done

echo "" # New line after progress display

# Global timer end
global_end=$(date +%s)
total_duration=$((global_end - global_start))
hours=$((total_duration / 3600))
minutes=$(( (total_duration % 3600) / 60 ))
seconds=$((total_duration % 60))

# Final summary
echo "" >> "$compilation_log"
echo "=== Final Compilation Summary ===" | tee -a "$compilation_log"
echo "Total runtime: ${hours}h ${minutes}m ${seconds}s" | tee -a "$compilation_log"
echo "Total files: $total_files" | tee -a "$compilation_log"
echo "Successfully compiled: $successful" | tee -a "$compilation_log"
echo "Failed to compile: $failed" | tee -a "$compilation_log"
if [ $total_files -gt 0 ]; then
    success_rate=$(awk "BEGIN {printf \"%.2f\", $successful * 100 / $total_files}")
    echo "Success rate: ${success_rate}%" | tee -a "$compilation_log"
fi
echo "Completed at: $(date)" | tee -a "$compilation_log"

# Print final message
echo ""
echo "Compilation completed!"
echo "Successfully compiled: $successful/$total_files files"
echo "Failed: $failed/$total_files files"
echo "See $compilation_log for details"
echo "List of successful compilations saved to $success_list"

if [ "$successful" -gt 0 ]; then
    echo "You can now run the dynamics simulation using:"
    echo "  ./01b_run_mod_dynamics.sh $success_list"
fi