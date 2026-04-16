'''
# Default file and title
python scatter_pie3.py

# Custom file with default title
python scatter_pie3.py mydata.xlsx

# Custom file and custom title
python scatter_pie3.py mydata.xlsx --title "C. GPT mini TPR"

# Default file with custom title
python scatter_pie3.py --title "Custom Title"

# Using short flag
python scatter_pie3.py -t "My Title"
'''
import matplotlib.pyplot as plt
from matplotlib.patches import Wedge
import pandas as pd
import sys
import argparse
from collections import defaultdict


# Model to color mapping
MODEL_COLOR_MAP = {
    'XGB': 'orange',
    'GPT': 'gray',
    'GPT_H': 'red'
}


def load_data_from_file(filename='gpt_sensitivity.xlsx'):
    """
    Load data from Excel or CSV file.
    
    Args:
        filename: Path to the data file
        
    Returns:
        pandas DataFrame with the loaded data
    """
    try:
        # Try loading as Excel first
        df = pd.read_excel(filename)
        print(f"Successfully loaded data from Excel file: {filename}")
    except Exception as e:
        print(f"Failed to load as Excel ({e}), trying CSV...")
        try:
            df = pd.read_csv(filename)
            print(f"Successfully loaded data from CSV file: {filename}")
        except Exception as e2:
            raise ValueError(f"Failed to load file as both Excel and CSV: {e2}")
    
    return df


def transform_tidy_data_to_plot_config(df, title="Sensitivity Plot", 
                                       xlabel="True Positive (%)",
                                       xticks=None, xticklabels=None):
    """
    Transform TIDY format data into my_plot structure.
    
    Args:
        df: DataFrame with columns 'true_subtype', 'sensitivity', 'model'
        title: Plot title
        xlabel: X-axis label
        xticks: X-axis tick positions
        xticklabels: X-axis tick labels
        
    Returns:
        Dictionary in my_plot format
    """
    # Group by true_subtype and model, aggregating sensitivity values
    # For each true_subtype, we want one entry with orange, blue, purple fields
    
    plot_data = []
    
    # Get unique subtypes
    subtypes = df['true_subtype'].unique()
    
    for subtype in subtypes:
        subtype_df = df[df['true_subtype'] == subtype]
        
        # Initialize the data entry for this subtype
        data_entry = {"name": subtype}
        
        # For each model, get the sensitivity value
        for model, color in MODEL_COLOR_MAP.items():
            model_data = subtype_df[subtype_df['model'] == model]
            
            if len(model_data) > 0:
                # If there are multiple entries, take the mean
                sensitivity = model_data['sensitivity'].mean()
                data_entry[color] = sensitivity
            else:
                # If no data for this model, set to 0 or skip
                data_entry[color] = 0
        
        plot_data.append(data_entry)
    
    # Create the plot configuration
    if xticks is None:
        xticks = [0, 0.25, 0.50, 0.75, 1]
    if xticklabels is None:
        xticklabels = ["0%", "25%", "50%", "75%", "100%"]
    
    plot_config = {
        "title": title,
        "xlabel": xlabel,
        "xticks": xticks,
        "xticklabels": xticklabels,
        "data": plot_data
    }
    
    return plot_config


def plot_custom_scatter(data, radius=0.05, title=None, xlabel=None, ylabel=None, 
                        xticks=None, xticklabels=None, yticks=None, yticklabels=None,
                        line_segments=None):
    """
    Plots points as mini-pie charts.
 
    Args:
        data: List of tuples (x, y, [colors])
        radius: The size of the pie chart markers
        title: Plot title
        xlabel: X-axis label
        ylabel: Y-axis label
        xticks: X-axis tick positions
        xticklabels: X-axis tick labels
        yticks: Y-axis tick positions
        yticklabels: Y-axis tick labels
        line_segments: List of tuples (y, x_min, x_max) for drawing horizontal line segments
    """
    fig, ax = plt.subplots(figsize=(8, 8))
    
    # Draw line segments first (so they're behind the pie charts)
    if line_segments:
        for y, x_min, x_max in line_segments:
            ax.plot([x_min, x_max], [y, y], color='darkgray', linewidth=2, zorder=1)
 
    for x, y, colors in data:
        num_colors = len(colors)
        slice_size = 360 / num_colors
        
        # Rotate by 90 degrees if there are 2 colors (to make them vertical)
        rotation_offset = 90 if num_colors == 2 else 0
 
        for i, color in enumerate(colors):
            # Calculate the start and end angle for each wedge
            start_angle = i * slice_size + rotation_offset
            end_angle = (i + 1) * slice_size + rotation_offset
 
            # Create the wedge patch (higher zorder to be on top of lines)
            wedge = Wedge(center=(x, y), r=radius, theta1=start_angle,
                          theta2=end_angle, facecolor=color, edgecolor='white', linewidth=0.5, zorder=2)
            ax.add_patch(wedge)
 
    # Auto-scale the axes based on the data points
    all_x = [p[0] for p in data]
    all_y = [p[1] for p in data]
 
    ax.set_xlim(min(all_x) - 0.1, max(all_x) + 0.1)
    ax.set_ylim(min(all_y) - 0.1, max(all_y) + 0.1)
 
    # Ensure the aspect ratio is equal so circles stay circular
    ax.set_aspect('equal')
    
    # Configure grid (vertical lines only)
    ax.grid(True, linestyle='--', alpha=0.6, axis='x')
    
    # Remove box around plot
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['bottom'].set_visible(False)
    ax.spines['left'].set_visible(False)
    
    # Set custom ticks and labels if provided
    if xticks is not None:
        ax.set_xticks(xticks)
    if xticklabels is not None:
        ax.set_xticklabels(xticklabels)
    if yticks is not None:
        ax.set_yticks(yticks)
    if yticklabels is not None:
        ax.set_yticklabels(yticklabels)
    
    # Set labels and title
    if xlabel:
        plt.xlabel(xlabel, fontsize=16)
    else:
        plt.xlabel("X Axis", fontsize=16)
    
    if ylabel is not None:
        plt.ylabel(ylabel)
    else:
        plt.ylabel("Y Axis")
    
    if title:
        plt.title(title, fontsize=18)
    else:
        plt.title("Scatter Plot with Multi-Color Markers", fontsize=18)
    
    # Adjust layout to prevent y-axis labels from being cut off
    plt.tight_layout()
    
    plt.show()


def transform_plot_data(plot_config):
    """
    Transforms the my_plot data structure into the format needed by plot_custom_scatter.
    
    Args:
        plot_config: Dictionary with title, xlabel, xticks, xticklabels, and data fields
        
    Returns:
        Tuple of (points, yticks, yticklabels, line_segments, other_config)
    """
    data_rows = plot_config["data"]
    num_rows = len(data_rows)
    
    # Space rows between 0 and 1, with first row at the highest y-coordinate
    y_coords = [1 - i / max(1, num_rows - 1) for i in range(num_rows)]
    
    points = []
    line_segments = []
    yticklabels = []
    
    for idx, row in enumerate(data_rows):
        y = y_coords[idx]
        yticklabels.append(row["name"])
        
        # Extract colors and their values (excluding 'name' field)
        color_values = {k: v for k, v in row.items() if k != "name"}
        
        # Group colors by their x-value
        value_to_colors = {}
        for color, value in color_values.items():
            if value not in value_to_colors:
                value_to_colors[value] = []
            value_to_colors[value].append(color)
        
        # Create a point for each unique x-value
        row_x_values = []
        for x_value, colors in value_to_colors.items():
            points.append((x_value, y, colors))
            row_x_values.append(x_value)
        
        # Find min and max x-values for this row to draw the line segment
        if row_x_values:
            x_min = min(row_x_values)
            x_max = max(row_x_values)
            line_segments.append((y, x_min, x_max))
    
    other_config = {
        "title": plot_config.get("title"),
        "xlabel": plot_config.get("xlabel"),
        "xticks": plot_config.get("xticks"),
        "xticklabels": plot_config.get("xticklabels"),
        "yticks": y_coords,
        "yticklabels": yticklabels
    }
    
    return points, line_segments, other_config


# Generate and display the plot
if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Generate sensitivity scatter plot from Excel/CSV data')
    parser.add_argument('filename', nargs='?', default='gpt_sensitivity.xlsx',
                        help='Path to the data file (default: gpt_sensitivity.xlsx)')
    parser.add_argument('--title', '-t', default='A. GPT 5.2 TPR',
                        help='Plot title (default: "A. GPT 5.2 TPR")')
    args = parser.parse_args()
    
    # Load data from file
    df = load_data_from_file(args.filename)
    
    # Check required columns
    required_cols = ['true_subtype', 'sensitivity', 'model']
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        raise ValueError(f"Missing required columns: {missing_cols}. Available columns: {list(df.columns)}")
    
    print(f"Loaded {len(df)} rows of data")
    print(f"Unique subtypes: {df['true_subtype'].nunique()}")
    print(f"Unique models: {df['model'].unique()}")
    
    # Transform TIDY data to plot configuration
    plot_config = transform_tidy_data_to_plot_config(
        df,
        title=args.title,
        xlabel="True Positive (%)",
        xticks=[0, 0.25, 0.50, 0.75, 1],
        xticklabels=["0%", "25%", "50%", "75%", "100%"]
    )
    
    # Transform plot config to scatter data
    points, line_segments, config = transform_plot_data(plot_config)
    
    plot_custom_scatter(
        points,
        radius=0.025,
        title=config["title"],
        xlabel=config["xlabel"],
        ylabel="",  # Empty y-axis label
        xticks=config["xticks"],
        xticklabels=config["xticklabels"],
        yticks=config["yticks"],
        yticklabels=config["yticklabels"],
        line_segments=line_segments
    )


