from _utils import *

# === Output directories ===

# Ensure both directories exist
os.makedirs(SIM_PLOT_DIR, exist_ok=True)
os.makedirs(SIM_CSV_DIR, exist_ok=True)


def get_baseline_temperature(mod_file_path):
    """Extract baseline temperature from mod file by looking for celsius +/- constant expressions"""
    with open(mod_file_path) as f:
        mod_text = f.read()

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
    return None


def get_suffix_name(mod_file_path):
    """Extract SUFFIX name from MOD file"""
    with open(mod_file_path) as f:
        mod_text = f.read()
    match = re.search(r'\bSUFFIX\s+([A-Za-z0-9_]+)', mod_text)
    if match:
        return match.group(1)
    return None


def run_sim(mod_file_path, v, doplot=False):
    """Run NEURON simulation and optionally save plots"""
    from neuron import h

    h.load_file("stdrun.hoc")
    soma = h.Section("soma")
    soma.L = soma.diam = 10  # µm

    suffix = get_suffix_name(mod_file_path)
    if suffix is None:
        raise ValueError(f"SUFFIX not found in {mod_file_path}")

    try:
        print(f"suffix: {suffix}")
        soma.insert(suffix)
        mech_type = "density"
    except Exception as e:
        print(f"Could not insert {suffix} as a distributed mechanism: {e}")
        try:
            getattr(h, suffix)(soma(0.5))
            mech_type = "point"
        except Exception as e2:
            raise RuntimeError(f"Failed to instantiate {suffix}: {e2}")

    baseline_temp = get_baseline_temperature(mod_file_path)
    h.celsius = baseline_temp if baseline_temp is not None else 6.3
    print(f"temperature = {h.celsius}, mechanism type = {mech_type}")

    seclamp = h.SEClamp(soma(0.5))
    seclamp.amp1 = -65
    seclamp.dur1 = 1000
    seclamp.amp2 = v
    seclamp.dur2 = 1000
    seclamp.amp3 = -65
    seclamp.dur3 = 0

    t = h.Vector().record(h._ref_t)
    vecs = {}
    for var in ["v", "ik", "ina", "ica"]:
        if hasattr(soma(0.5), var):
            vecs[var] = h.Vector().record(getattr(soma(0.5), f"_ref_{var}"))

    h.finitialize(-65)
    h.continuerun(3000)
    t_arr = t.as_numpy()

    results = {}
    interval1_start = seclamp.dur1
    interval1_end = seclamp.dur1 + seclamp.dur2
    interval2_start = interval1_end
    interval2_end = t_arr[-1]

    def find_90_percent_time(arr, t_arr, start_val, end_val, start_time):
        if start_val is None or end_val is None:
            return None
        target_val = start_val + 0.9 * (end_val - start_val)
        after_start_mask = t_arr >= start_time
        if not after_start_mask.any():
            return None
        arr_after = arr[after_start_mask]
        t_after = t_arr[after_start_mask]
        mask = arr_after >= target_val if end_val > start_val else arr_after <= target_val
        if mask.any():
            return float(t_after[mask.argmax()] - start_time)
        return None

    for var in ["v", "ik", "ina", "ica"]:
        if var in vecs:
            arr = vecs[var].as_numpy()
            initial_idx = (t_arr >= interval1_start).argmax()
            initial_val = arr[initial_idx] if initial_idx < len(arr) else None

            # Interval 1
            mask1 = (t_arr >= interval1_start) & (t_arr < interval1_end)
            if mask1.any():
                arr1 = arr[mask1]
                t1 = t_arr[mask1]
                min_val1 = arr1.min()
                max_val1 = arr1.max()
                interval1_results = {
                    "time_to_90_max": find_90_percent_time(arr1, t1, initial_val, max_val1, t1[0]),
                    "time_to_90_min": find_90_percent_time(arr1, t1, initial_val, min_val1, t1[0]),
                    "initial_val": float(initial_val) if initial_val is not None else None,
                    "max_val": float(max_val1),
                    "min_val": float(min_val1)
                }
            else:
                interval1_results = {k: None for k in ["time_to_90_max", "time_to_90_min", "initial_val", "max_val", "min_val"]}

            # Interval 2
            mask2 = (t_arr >= interval2_start) & (t_arr <= interval2_end)
            if mask2.any():
                arr2 = arr[mask2]
                t2 = t_arr[mask2]
                recovery_start_val = arr2[0]
                min_val2 = arr2.min()
                max_val2 = arr2.max()
                time_to_90_recovery = find_90_percent_time(arr2, t2, recovery_start_val, initial_val, interval2_start)
                interval2_results = {
                    "time_to_90_recovery": time_to_90_recovery,
                    "recovery_start_val": float(recovery_start_val),
                    "final_val": float(arr2[-1]),
                    "max_val": float(max_val2),
                    "min_val": float(min_val2)
                }
            else:
                interval2_results = {k: None for k in ["time_to_90_recovery", "recovery_start_val", "final_val", "max_val", "min_val"]}

            results[var] = {"interval1": interval1_results, "interval2": interval2_results}

    if doplot:
        import matplotlib.pyplot as plt
        fig, axs = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
        axs[0].plot(t_arr, vecs["v"].as_numpy(), label='Voltage (v)', color='blue')
        axs[0].set_ylabel('Voltage (mV)')
        axs[0].set_title('Voltage Clamp Response')
        axs[0].legend()

        for var in ["ik", "ina", "ica"]:
            if var in vecs:
                axs[1].plot(t_arr, vecs[var].as_numpy(), label=f'{var}')
        axs[1].set_ylabel('Current (mA/µm²)')
        axs[1].set_xlabel('Time (ms)')
        axs[1].legend()
        plt.tight_layout()

        plot_path = os.path.join(SIM_PLOT_DIR, f"sim_plot__{suffix}.png")
        plt.savefig(plot_path, dpi=300)
        print(f"Saved plot to: {plot_path}")

    return results



def simulate_and_save(mod_file_path, voltage=20, doplot=False):
    """Run simulation and save results + CSV (and optionally plot)."""
    suffix = get_suffix_name(mod_file_path)
    results = run_sim(mod_file_path, voltage, doplot=doplot)

    flat_features = {
        "mod_file": os.path.basename(mod_file_path),
        "suffix": suffix,
        "voltage": voltage,
    }

    for var in results:
        for interval in results[var]:
            for key, value in results[var][interval].items():
                flat_features[f"{var}_{interval}_{key}"] = value

    basename = os.path.splitext(os.path.basename(mod_file_path))[0]
    output_csv = os.path.join(SIM_CSV_DIR, f"sim_features__{basename}.csv")
    pd.DataFrame([flat_features]).to_csv(output_csv, index=False)
    print(f"Saved features to: {output_csv}")

    return output_csv
