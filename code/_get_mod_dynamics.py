import os
import sys
import re

def get_baseline_temperature(mod_file_path):
    """Extract baseline temperature from mod file by looking for celsius +/- constant expressions"""
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

#accomodates THREAD SUFFIX  
def get_suffix_name(mod_file_path):
    with open(mod_file_path) as f:
        mod_text = f.read()
    # Match SUFFIX (with or without THREADSAFE before it)
    match = re.search(r'\bSUFFIX\s+([A-Za-z0-9_]+)', mod_text)
    if match:
        return match.group(1)
    return None

plot_dir = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/sim_plots"
os.makedirs(plot_dir, exist_ok=True)


def run_sim(mod_file_path, v, doplot=False):
    from neuron import h
    h.load_file("stdrun.hoc")
    soma = h.Section("soma")
    soma.L = soma.diam = 10  # µm

    # Get suffix and abort if not found
    suffix = get_suffix_name(mod_file_path)
    if suffix is None:
        raise ValueError(f"SUFFIX not found in {mod_file_path}")
    try:
        # Try inserting as a distributed mechanism
        soma.insert(suffix)
        mech_type = "density"
    except Exception as e:
        print(f"Could not insert {suffix} as a distributed mechanism: {e}")
        try:
            # Try as a point process
            chan = getattr(h, suffix)(soma(0.5))
            mech_type = "point"
        except Exception as e2:
            raise RuntimeError(f"Failed to instantiate {suffix} as point process too: {e2}")
    # Set temperature based on mod file baseline or default to 6.3
    baseline_temp = get_baseline_temperature(mod_file_path)
    h.celsius = baseline_temp if baseline_temp is not None else 6.3
    print(f"temperature = {h.celsius}, mechanism type = {mech_type}")
    print(f"temperature = {h.celsius}")
    seclamp = h.SEClamp(soma(0.5))
    seclamp.amp1 = -65  # mV
    seclamp.dur1 = 1000  # ms
    seclamp.amp2 = v  # mV
    seclamp.dur2 = 1000  # ms
    seclamp.amp3 = -65  # mV
    seclamp.dur3 = 0  # ms -- i.e., let it free
    t = h.Vector().record(h._ref_t)
    vecs = {}
    for var in ["v", "ik", "ina", "ica"]:
        if hasattr(soma(0.5), var):
            vecs[var] = h.Vector().record(getattr(soma(0.5), f"_ref_{var}"))
    h.finitialize(-65)  # mV
    h.continuerun(3000)  # ms
    results = {}
    t_arr = t.as_numpy()
    # we're going to find the extrema during the voltage clamp and after
    interval1_start = seclamp.dur1
    interval1_end = seclamp.dur1 + seclamp.dur2
    interval2_start = interval1_end
    interval2_end = t_arr[-1]

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

    for var in ["v", "ik", "ina", "ica"]:
        if var in vecs:
            arr = vecs[var].as_numpy()
            
            # Get initial value (at start of interval 1)
            initial_idx = (t_arr >= interval1_start).argmax()
            initial_val = arr[initial_idx] if initial_idx < len(arr) else None
            
            # Interval 1 analysis
            mask1 = (t_arr >= interval1_start) & (t_arr < interval1_end)
            if mask1.any():
                arr1 = arr[mask1]
                t1 = t_arr[mask1]
                
                # Find extrema
                min_idx1 = arr1.argmin()
                max_idx1 = arr1.argmax()
                min_val1 = arr1[min_idx1]
                max_val1 = arr1[max_idx1]
                
                # Calculate 90% times between extrema (more meaningful for dynamics)
                # From initial to max
                time_to_90_max = find_90_percent_time(arr1, t1, initial_val, max_val1, t1[0])
                # From initial to min
                time_to_90_min = find_90_percent_time(arr1, t1, initial_val, min_val1, t1[0])
                # Between extrema: 90% from min to max
                time_min_to_90_max = find_90_percent_time(arr1, t1, min_val1, max_val1, t1[min_idx1])
                # Between extrema: 90% from max to min
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
    
    if doplot:
        import pprint
        pprint.pprint(results)

        # plot everything we have in two subfigures: one for voltage and one for currents
        import matplotlib.pyplot as plt
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
        #plt.show() replaced 238 with 239 and 240
        plt.tight_layout()
        plot_path = os.path.join(plot_dir, f"sim_plot__{suffix}.png")
        plt.savefig(plot_path, dpi=300)
        print(f"Saved plot to: {plot_path}")
    return results
    

#if __name__ == "__main__":
    # make sure all mod files in directory have been compiled
    # this may need to be changed depending on how this is used
    # e.g., include the folder path at the end
#    os.system('nrnivmodl')


import pandas as pd

if __name__ == "__main__":
    mod_file_path = sys.argv[1]
    voltages = [-120, -90, -70, -50, -30, 0, 20]  # Extend or modify as needed
    suffix = get_suffix_name(mod_file_path)

    all_rows = []

    for v in voltages:
        print(f"\nRunning simulation for voltage: {v} mV")
        results = run_sim(mod_file_path, v, doplot=False)

        flat_features = {
            "mod_file": os.path.basename(mod_file_path),
            "suffix": suffix,
            "voltage": v,
        }

        for var in results:
            for interval in results[var]:
                for key, value in results[var][interval].items():
                    feat_name = f"{var}_{interval}_{key}_v{v}"
                    flat_features[feat_name] = value

        all_rows.append(flat_features)

    # Save to CSV in target directory
    output_dir = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/raw/sim_csvs"
    os.makedirs(output_dir, exist_ok=True)

    basename = os.path.splitext(os.path.basename(mod_file_path))[0]
    output_csv = os.path.join(output_dir, f"sim_features__{basename}.csv")

    df = pd.DataFrame(all_rows)
    df.to_csv(output_csv, index=False)
    print(f"\nSaved all voltage features to: {output_csv}")
