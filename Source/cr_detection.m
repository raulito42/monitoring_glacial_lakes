% 1. Load both processed datasets
data_with = load('D:\MIMO-SAR\Source\D00_sample_data\real\MIMO_C77_Pond_lowSlope_21min_20260513_115401\03_PSI_Interfero\02_PSI.mat');
data_ohne = load('D:\MIMO-SAR\Source\D00_sample_data\real\MIMO_C77_Pond_lowSlope_21min_ohneCR_20260513_121908\03_PSI_Interfero\02_PSI.mat');

% 2. Extract coordinates and mean log-amplitudes
x_with = data_with.data.x_axis;
y_with = data_with.data.y_axis;
ampl_with = log10(mean(data_with.data.ampl, 2));

x_ohne = data_ohne.data.x_axis;
y_ohne = data_ohne.data.y_axis;
ampl_ohne = log10(mean(data_ohne.data.ampl, 2));

% 3. Automated Coordinate-Based Matching
% Because array sizes differ, we loop through the 'with' points and find 
% their closest physical counterpart in the 'ohne' dataset.
ampl_diff = zeros(size(ampl_with));

for i = 1:length(ampl_with)
    % Calculate physical distance to all points in the baseline dataset
    dist = sqrt((x_ohne - x_with(i)).^2 + (y_ohne - y_with(i)).^2);
    [min_dist, closest_idx] = min(dist);
    
    % Only match if the closest pixel is within a reasonable grid tolerance (e.g., 20cm)
    if min_dist < 0.2
        ampl_diff(i) = ampl_with(i) - ampl_ohne(closest_idx);
    else
        ampl_diff(i) = 0; % No matching physical pixel found in the background data
    end
end

% 4. Find the coordinates of the 5 sharpest peaks automatically
[sorted_values, sorted_indices] = sort(ampl_diff, 'descend');

fprintf('\n--- AUTOMATED CORNER REFLECTOR LOCATIONS ---\n');
num_targets_to_find = 5; 

for i = 1:num_targets_to_find
    idx = sorted_indices(i);
    
    x_coord = x_with(idx);
    y_coord = y_with(idx);
    peak_intensity = sorted_values(i);
    
    fprintf('Target %d: X = %.2f m, Y = %.2f m (Change: %.2f dB)\n', ...
            i, x_coord, y_coord, peak_intensity);
end

% 5. Plot ONLY the changes
ylimits = [min(y_with), max(y_with)];
xlimits = [min(x_with), max(x_with)];

figure('Name', 'Automated Corner Reflector Difference Map');
plot_polar_range_azimuth_2D_AB_preAX(y_with, ...
                                     x_with, ...
                                     ampl_diff, ...
                                     ylimits, xlimits, 'scatter');
title('Automated Corner Reflector Difference Map');
hcb = colorbar;
hcb.Label.String = 'Delta Amplitude [log10(A)]';
clim([0.3, max(ampl_diff)]); % Focus strictly on positive spikes where targets appeared