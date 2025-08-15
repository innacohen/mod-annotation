

# Metadata categories
metadata_types = [
    "neurons", "currents", "model_type", "model_concept",
    "modeling_application", "receptors", "region"
]

# F1 scores
rule_based = [0.05, 0.27, 0.31, 0.15, 0.28, 0.25, 0.24]
comvar = [0.23, 0.35, 0.39, 0.17, 0.67, 0.52, 0.43]
header = [0.26, 0.32, 0.41, 0.20, 0.73, 0.48, 0.41]

# Bar setup
x = np.arange(len(metadata_types))
width = 0.25

# Plot
fig, ax = plt.subplots(figsize=(14, 8))

bars1 = ax.bar(x - width, rule_based, width, label='rule_based', color='#414C6B')
bars2 = ax.bar(x, comvar, width, label='comvar', color='#25b9e5')
bars3 = ax.bar(x + width, header, width, label='header', color='#18327e')

# Labels and titles with larger fonts
ax.set_ylabel("F1 (micro)", fontsize=24)
ax.set_title("F1 Comparison by Metadata Type", fontsize=28, pad=20)
ax.set_xticks(x)
ax.set_xticklabels(metadata_types, rotation=30, fontsize=20)
ax.tick_params(axis='y', labelsize=20)
ax.legend(fontsize=20)

# Place value labels directly above bars with minimal spacing
for bars in [bars1, bars2, bars3]:
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f"{height:.2f}",
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 2),  # minimal vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=14)

# Tighter Y-axis limit
ax.set_ylim(0, max(header) + 0.05)

plt.tight_layout()
plt.show()