#!/usr/bin/env python3
"""
MOD File Dynamics Analysis
Analyzes NEURON mechanism dynamics through voltage clamp simulations
"""

# Import utils and set global variables
from _utils import *
import sys
import re
import pandas as pd
import logging
from datetime import datetime
from pathlib import Path

# Set global path variables 
PLOT_DIR = os.path.join(RAW_DATA_DIR, "sim_plots")
CSV_DIR = os.path.join(RAW_DATA_DIR, "sim_csvs")
LOG_FILE_FP = os.path.join(LOGS_DIR, f"mod_dynamics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Create required directories
os.makedirs(PLOT_DIR, exist_ok=True)
os.makedirs(CSV_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

# Setup logging
logging.basicConfig(
    filename=LOG_FILE_FP,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - MOD_FILE: %(mod_file)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Create a custom logger that can accept extra parameters
logger = logging.getLogger('mod_dynamics')
logger.handlers = logging.getLogger().handlers


def get_baseline_temperature(mod_file_path):
    """Extract baseline temperature from mod file by looking for celsius +/- constant expressions"""
    try:
        with open(mod_file_path) as f:
            mod_text = f.read()
        
        # Look for patterns like "celsius - 20.5", "20.5 - celsius", "celsius + 20.5", etc.
        # This captures expressions where celsius is offset by a constant
        patterns = [
            r'celsius\s*(-)\s*([0-9]+\.?[0-9]*)',  # celsius - 20.5 -> baseline = +20.5
            r'celsius\s*(\+)\s*([0-9]+\.?[0-9]*)',  # celsius + 20.5 -> baseline = -20.5
            r'([0-9]+\.?[0-9]*)\s*(-)\s*celsius',  # 20.5 - celsius -> baseline = +20.5
            r'([0-9]+\.?[0-9]*)\s*(\+)\s*celsius',  # 20.5 + celsius -> baseline = -20.5
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, mod_text, re.IGNORECASE)
            if matches:
                for match in matches:
                    if len(match) == 2:  # celsius +/- number format
                        sign, number = match
                        baseline = float(number) if sign == '-' else -float(number)
                    else:  # number +/- celsius format
                        number, sign = match
                        baseline = float(number) if sign == '-' else -float(number)
                    return baseline
        
        # If no baseline temperature found, return None
        return None
    except Exception as e:
        logger.error(f"Error extracting baseline temperature: {e}", extra={'mod_file': os.path.basename(mod_file_path)})
        return None


def get_suffix_name(mod_file_path):
    """Extract SUFFIX from MOD file"""
    try:
        with open(mod_file_path) as f:
            mod_text = f.read()
        # Match SUFFIX (with or without THREADSAFE before it)
        match = re.search(r'\bSUFFIX\s+([A-Za-z0-9_]+)', mod_text)
        if match:
            return match.group(1)
        return None
    except Exception as e:
        logger.error(f"Error extracting suffix name: {e}", extra={'mod_file': os.path.basename(mod_file_path)})
        return None


def find_90_percent_time(arr, t_arr, start_val, end_val, start_time):
    """Find time to reach 90% of the way from start_val to end_val"""
    if start_val is None or end_val is None:
        return None
    
    target_val = start_val + 0.9 * (end_val - start_val)
    
    # Find times after start_time
    after_start_mask = t_arr >= start_time
    if not after_start_mask.any():
        return None
        
    arr_after = arr[after_start_mask]
    t_after = t_arr[after_start_mask]
    
    # Find the point where we cross the 90% threshold
    if end_val > start_val:  # increasing
        mask = arr_after >= target_val
    else:  # decreasing
        mask = arr_after <= target_val
    
    if mask.any():
        first_crossing_idx = mask.argmax()  # first True value
        crossing_time = t_after[first_crossing_idx]
        return float(crossing_time - start_time)
    return None


def run_sim(mod_file_path, v, doplot=False):
    """Run simulation for a MOD file using NEURON"""
    mod_file_name = os.path.basename(mod_file_path)
    
    try:
        from neuron import h
        h.load_file("stdrun.hoc")
        logger.info(f"Successfully loaded NEURON", extra={'mod_file': mod_file_name})
    except ImportError as e:
        error_msg = f"Failed to import NEURON: {e}"
        logger.error(error_msg, extra={'mod_file': mod_file_name})
        print(error_msg)
        return None
        
    try:
        # Setup NEURON section
        soma = h.Section("soma")
        soma.L = soma.diam = 10  # µm

        # Get suffix and abort if not found
        suffix = get_suffix_name(mod_file_path)
        if suffix is None:
            error_msg = f"SUFFIX not found in {mod_file_path}"
            logger.error(error_msg, extra={'mod_file': mod_file_name})
            raise ValueError(error_msg)
            
        try:
            # Try inserting as a distributed mechanism
            soma.insert(suffix)
            mech_type = "density"
        except Exception as e:
            logger.warning(f"Could not insert {suffix} as a distributed mechanism: {e}", 
                          extra={'mod_file': mod_file_name})
            try:
                # Try as a point process
                chan = getattr(h, suffix)(soma(0.5))
                mech_type = "point"
            except Exception as e2:
                error_msg = f"Failed to instantiate {suffix} as point process too: {e2}"
                logger.error(error_msg, extra={'mod_file': mod_file_name})
                raise RuntimeError(error_msg)
                
        # Set temperature based on mod file baseline or default to 6.3
        baseline_temp = get_baseline_temperature(mod_file_path)
        h.celsius = baseline_temp if baseline_temp is not None else 6.3
        logger.info(f"Temperature = {h.celsius}, mechanism type = {mech_type}", 
                   extra={'mod_file': mod_file_name})
        
        # Setup voltage clamp
        seclamp = h.SEClamp(soma(0.5))
        seclamp.amp1 = -65  # mV
        seclamp.dur1 = 1000  # ms
        seclamp.amp2 = v  # mV
        seclamp.dur2 = 1000  # ms
        seclamp.amp3 = -65  # mV
        seclamp.dur3 = 0  # ms -- i.e., let it free
        
        # Record variables
        t = h.Vector().record(h._ref_t)
        vecs = {}
        for var in ["v", "ik", "ina", "ica"]:
            if hasattr(soma(0.5), var):
                vecs[var] = h.Vector().record(getattr(soma(0.5), f"_ref_{var}"))
                
        # Run simulation
        h.finitialize(-65)  # mV
        h.continuerun(3000)  # ms
        
        # Process results
        results = process_simulation_results(t, vecs, seclamp)
        
        # Create plots if requested
        if doplot:
            create_plots(t, vecs, suffix)
            
        logger.info(f"Simulation completed successfully", extra={'mod_file': mod_file_name})
        return results
        
    except Exception as e:
        error_msg = f"Simulation error: {e}"
        logger.error(error_msg, extra={'mod_file': mod_file_name})
        print(error_msg)
        return None


def process_simulation_results(t, vecs, seclamp):
    """Process and analyze simulation results"""
    results = {}
    t_arr = t.as_numpy()
    
    # Define analysis intervals
    interval1_start = seclamp.dur1
    interval1_end = seclamp.dur1 + seclamp.dur2
    interval2_start = interval1_end
    interval2_end = t_arr[-1]
    
    for var in ["v", "ik", "ina", "ica"]:
        if var in vecs:
            arr = vecs[var].as_numpy()
            
            # Get initial value (at start of interval 1)
            initial_idx = (t_arr >= interval1_start).argmax()
            initial_val = arr[initial_idx] if initial_idx < len(arr) else None
            
            # Interval 1 analysis (during voltage clamp)
            mask1 = (t_arr >= interval1_start) & (t_arr < interval1_end)
            if mask1.any():
                arr1 = arr[mask1]
                t1 = t_arr[mask1]
                
                # Find extrema
                min_idx1 = arr1.argmin()
                max_idx1 = arr1.argmax()
                min_val1 = arr1[min_idx1]
                max_val1 = arr1[max_idx1]
                
                # Calculate 90% times between extrema
                time_to_90_max = find_90_percent_time(arr1, t1, initial_val, max_val1, t1[0])
                time_to_90_min = find_90_percent_time(arr1, t1, initial_val, min_val1, t1[0])
                time_min_to_90_max = find_90_percent_time(arr1, t1, min_val1, max_val1, t1[min_idx1])
                time_max_to_90_min = find_90_percent_time(arr1, t1, max_val1, min_val1, t1[max_idx1])
                
                interval1_results = {
                    "time_to_90_max": time_to_90_max,
                    "time_to_90_min": time_to_90_min,
                    "time_min_to_90_max": time_min_to_90_max,
                    "time_max_to_90_min": time_max_to_90_min,
                    "initial_val": float(initial_val) if initial_val is not None else None,
                    "max_val": float(max_val1),
                    "min_val": float(min_val1)
                }
            else:
                interval1_results = {
                    "time_to_90_max": None,
                    "time_to_90_min": None,
                    "time_min_to_90_max": None,
                    "time_max_to_90_min": None,
                    "initial_val": None,
                    "max_val": None,
                    "min_val": None
                }
            
            # Interval 2 analysis (recovery)
            mask2 = (t_arr >= interval2_start) & (t_arr <= interval2_end)
            if mask2.any():
                arr2 = arr[mask2]
                t2 = t_arr[mask2]
                
                # Get value at start of interval 2 (end of clamp)
                recovery_start_val = arr2[0] if len(arr2) > 0 else None
                
                # Find extrema in recovery period
                min_idx2 = arr2.argmin()
                max_idx2 = arr2.argmax()
                min_val2 = arr2[min_idx2]
                max_val2 = arr2[max_idx2]
                
                # For recovery, we're interested in getting back to resting state
                # Assume resting is closer to initial_val
                if initial_val is not None and recovery_start_val is not None:
                    time_to_90_recovery = find_90_percent_time(arr2, t2, recovery_start_val, initial_val, interval2_start)
                else:
                    time_to_90_recovery = None
                
                interval2_results = {
                    "time_to_90_recovery": time_to_90_recovery,
                    "recovery_start_val": float(recovery_start_val) if recovery_start_val is not None else None,
                    "final_val": float(arr2[-1]) if len(arr2) > 0 else None,
                    "max_val": float(max_val2),
                    "min_val": float(min_val2)
                }
            else:
                interval2_results = {
                    "time_to_90_recovery": None,
                    "recovery_start_val": None,
                    "final_val": None,
                    "max_val": None,
                    "min_val": None
                }
            
            results[var] = {
                "interval1": interval1_results,
                "interval2": interval2_results
            }
        else:
            results[var] = {
                "interval1": {
                    "time_to_90_max": None,
                    "time_to_90_min": None,
                    "time_min_to_90_max": None,
                    "time_max_to_90_min": None,
                    "initial_val": None,
                    "max_val": None,
                    "min_val": None
                },
                "interval2": {
                    "time_to_90_recovery": None,
                    "recovery_start_val": None,
                    "final_val": None,
                    "max_val": None,
                    "min_val": None
                }
            }
    
    return results


def create_plots(t, vecs, suffix):
    """Create and save plots of simulation results"""
    try:
        import matplotlib.pyplot as plt
        t_arr = t.as_numpy()
        
        # Create plot
        fig, axs = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
        axs[0].plot(t_arr, vecs["v"].as_numpy(), label='Voltage (v)', color='blue')
        axs[0].set_ylabel('Voltage (mV)')
        axs[0].set_title('Voltage Clamp Response')
        axs[0].legend()
        
        for var in ["ik", "ina", "ica"]:
            if var in vecs:
                axs[1].plot(t_arr, vecs[var].as_numpy(), label=f'Current ({var})')
        
        axs[1].set_ylabel('Current (mA/um2)')
        axs[1].set_xlabel('Time (ms)')
        axs[1].legend()
        plt.tight_layout()
        
        # Save plot
        plot_path = os.path.join(PLOT_DIR, f"sim_plot__{suffix}.png")
        plt.savefig(plot_path, dpi=300)
        plt.close(fig)
        
        logger.info(f"Plot saved to: {plot_path}", extra={'mod_file': f"{suffix}.mod"})
        print(f"Plot saved to: {plot_path}")
        
    except Exception as e:
        error_msg = f"Error creating plot: {e}"
        logger.error(error_msg, extra={'mod_file': f"{suffix}.mod"})
        print(error_msg)


def save_results_to_csv(results, mod_file_path, voltage):
    """Save analysis results to CSV file"""
    mod_file_name = os.path.basename(mod_file_path)
    suffix = get_suffix_name(mod_file_path)
    
    try:
        # Flatten and extract key features
        flat_features = {
            "mod_file": mod_file_name,
            "suffix": suffix,
            "voltage": voltage,
        }

        for var in results:
            for interval in results[var]:
                for key, value in results[var][interval].items():
                    flat_features[f"{var}_{interval}_{key}"] = value

        # Save to CSV
        BASENAME = os.path.splitext(mod_file_name)[0]
        OUTPUT_CSV_FP = os.path.join(CSV_DIR, f"sim_features__{BASENAME}.csv")

        df = pd.DataFrame([flat_features])
        df.to_csv(OUTPUT_CSV_FP, index=False)
        
        logger.info(f"CSV saved to: {OUTPUT_CSV_FP}", extra={'mod_file': mod_file_name})
        print(f"CSV saved to: {OUTPUT_CSV_FP}")
        return OUTPUT_CSV_FP
        
    except Exception as e:
        error_msg = f"Error saving CSV: {e}"
        logger.error(error_msg, extra={'mod_file': mod_file_name})
        print(error_msg)
        return None


def main():
    """Main entry point for the script"""
    # Start time tracking
    start_time = datetime.now()
    
    # Parse command-line arguments
    if len(sys.argv) < 2:
        print("Usage: python 1-1get_mod_dynamics.py <mod_file_path> [voltage=10]")
        return 1
        
    mod_file_path = sys.argv[1]
    voltage = float(sys.argv[2]) if len(sys.argv) > 2 else 10
    
    # Get mod file name
    mod_file_name = os.path.basename(mod_file_path)
    
    # Log script start
    logger.info(f"Starting analysis with voltage: {voltage}", 
               extra={'mod_file': mod_file_name})
    print(f"Starting analysis of {mod_file_name} with voltage: {voltage}")
    
    try:
        # Check if mod file exists
        if not os.path.exists(mod_file_path):
            error_msg = f"MOD file does not exist: {mod_file_path}"
            logger.error(error_msg, extra={'mod_file': mod_file_name})
            print(error_msg)
            return 1
            
        # Get suffix
        suffix = get_suffix_name(mod_file_path)
        if not suffix:
            error_msg = f"Could not find SUFFIX in {mod_file_path}"
            logger.error(error_msg, extra={'mod_file': mod_file_name})
            print(error_msg)
            return 1
            
        # Run simulation
        results = run_sim(mod_file_path, voltage, doplot=True)
        
        if results:
            # Save results to CSV
            csv_path = save_results_to_csv(results, mod_file_path, voltage)
            if not csv_path:
                return 1
        else:
            error_msg = "Simulation failed to produce results"
            logger.error(error_msg, extra={'mod_file': mod_file_name})
            print(error_msg)
            return 1
            
        # End time and duration
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        # Log completion
        logger.info(f"Analysis completed in {duration:.2f} seconds", 
                   extra={'mod_file': mod_file_name})
        print(f"Analysis completed in {duration:.2f} seconds")
        return 0
        
    except Exception as e:
        # Log any unhandled exceptions
        error_msg = f"Unexpected error: {e}"
        logger.exception(error_msg, extra={'mod_file': mod_file_name})
        print(error_msg)
        return 1


if __name__ == "__main__":
    sys.exit(main())