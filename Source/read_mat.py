import mat73
import numpy as np
import pandas as pd

file_path = r'Source\D00_sample_data\real\MIMO_C77_GS_P3_001_15min_20260519_130316_00910000ms\02_SLC_Radar_Data\01_Raw_Radar_Data_00001.mat'
print("Loading complete radar matrix...")
data = mat73.loadmat(file_path)

# Extract every single pixel coordinate relative to the radar sensor origin (0,0)
x_local = data['y_axis'].flatten()  # Cross-Range [meters]
y_local = data['x_axis'].flatten()  # Along-Range [meters]
complex_data = data['complex_data_static']

# Calculate the mean reflection amplitude across all frames for every pixel
print("Calculating mean amplitude map...")
mean_amplitude = np.mean(np.abs(complex_data), axis=1)

# Compile the full 2D slice grid (Setting Z to 0 to create a flat horizontal plane)
full_radar_slice = pd.DataFrame({
    'X_Local': x_local,
    'Y_Local': y_local,
    'Z_Local': np.zeros_like(x_local),
    'Mean_Amplitude': mean_amplitude
})

output_file = 'full_2d_radar_slice.csv'
full_radar_slice.to_csv(output_file, index=False)
print(f"Successfully exported all {len(full_radar_slice)} radar pixels to '{output_file}'!")