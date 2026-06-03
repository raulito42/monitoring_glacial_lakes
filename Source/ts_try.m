% %% plot_results.m - Boresight-View Coherence ROI Masking & Analysis
% clear; clc; close all;
% 
% % 1. Set your paths
% [file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
% addpath(genpath(fullfile(file_dir)));
% 
% name2proj = 'MIMO_C77_GS_P2_002_15min_20260519_121708_00910000ms';
% path2proj = fullfile(file_dir, 'D00_sample_data', 'real', name2proj, '03_PSI_Interfero');
% 
% fname = '01_SLC_Filt.mat';
% path2mat = fullfile(path2proj, fname);
% 
% if ~isfile(path2mat)
%     error('File not found! Run the full script once to generate 01_SLC_Filt.mat');
% end
% 
% % 2. Load the raw time-series matrices
% fprintf('Loading master radar cube file: %s...\n', fname);
% load(path2mat, 'cplx', 'y_axis', 'x_axis', 'timestamp_abs');
% 
% % Radar Math Parameters
% c0 = physconst('LightSpeed');
% centerFreq = 77e9;                     % 77 GHz system
% lambda = c0 / centerFreq;              % Carrier wavelength
% scale_rad2mm = lambda / (4*pi) * 1000; % Radian to mm conversion factor
% 
% [N_pixels, N_time] = size(cplx);
% window_duration = seconds(15);         % 15-second block window configuration
% 
% % Setup spatial display boundaries matching your dashboard
% ylimits = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.05;
% xlimits = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.05;
% 
% %% STEP 1: Compute and Plot Initial Short-Term Coherence for Selection
% fprintf('Calculating initial coherence block for interactive masking...\n');
% first_window_idx = (timestamp_abs >= timestamp_abs(1)) & (timestamp_abs <= (timestamp_abs(1) + window_duration));
% 
% cplx_first_slice = cplx(:, first_window_idx);
% cplx_ref = cplx_first_slice(:, 1);
% interf_phase_first = angle(cplx_first_slice .* conj(cplx_ref));
% initial_coherence = abs(mean(exp(1i * interf_phase_first), 2));
% 
% % Render selection window using your custom boresight polar engine
% fig_select = figure('Name', 'Draw Shoreline Polygon (Boresight Coherence View)', ...
%                     'units', 'normalized', 'outerposition', [0.15 0.1 0.7 0.8]);
% 
% % Call your custom plotting function
% plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, initial_coherence, ylimits, xlimits, 'scatter');
% hcb = colorbar; hcb.Label.String = 'Coherence [0...1]';
% clim([0.2, 0.8]); 
% colormap(gca, parula);
% axis equal; box on;
% 
% title({'1. Click points to draw your area.', ...
%        '2. Double-click the last point to close the shape.', ...
%        '3. Click the "CONFIRM AREA" button on the top-left to continue.'});
% 
% %% STEP 2: Interactive Polygon ROI Generation with UIOVERLAY Button
% % Create a dedicated UI button to resume execution cleanly
% btn = uicontrol(fig_select, 'Style', 'pushbutton', 'String', 'CONFIRM AREA', ...
%     'Units', 'normalized', 'Position', [0.02, 0.90, 0.15, 0.05], ...
%     'BackgroundColor', [0.2 0.6 0.2], 'ForegroundColor', 'w', ...
%     'FontWeight', 'bold', 'FontSize', 11, ...
%     'Callback', @(src, event) uiresume(fig_select));
% 
% fprintf('Waiting for polygon creation... draw your shape, then click "CONFIRM AREA".\n');
% %% STEP 2: Interactive Polygon ROI Generation (With Automatic Shoreline Extraction)
% fprintf('Waiting for polygon creation... draw a tight box around the shore boundary, then click "CONFIRM AREA".\n');
% 
% % Create the interactive polygon tool
% roi = drawpolygon(gca, 'Color', 'r', 'LineWidth', 2);
% 
% % Block the script execution safely here until the user clicks the button
% uiwait(fig_select); 
% 
% if isvalid(roi)
%     roi_vertices = roi.Position; 
%     x_poly = roi_vertices(:, 1);
%     y_poly = roi_vertices(:, 2);
% else
%     error('Selection was closed or corrupted before clicking confirm.');
% end
% 
% % 1. Find all points inside your drawn shape
% in_polygon_mask = inpolygon(x_axis, y_axis, x_poly, y_poly);
% 
% % 2. CRITICAL CRITERIA: Keep ONLY the pixels that behave like a changing shoreline
% % We filter for intermediate coherence (eliminates deep water and solid static rock)
% shoreline_mask = in_polygon_mask & (initial_coherence >= 0.35 & initial_coherence <= 0.60);
% 
% % Fallback if your drawn box is already very tight
% if sum(shoreline_mask) < 3
%     fprintf('Warning: Coherence filter too strict inside this small box. Using raw polygon points.\n');
%     shoreline_mask = in_polygon_mask;
% end
% 
% if ishandle(fig_select)
%     close(fig_select); 
% end
% 
% fprintf('Success! Found %d highly sensitive shoreline boundary pixels to track.\n', sum(shoreline_mask));
% %% STEP 3: Time-Series Analysis Loop Across All Frames
% shoreline_displ = zeros(N_time, 1);
% cplx_shore = cplx(shoreline_mask, :);
% 
% % Compute base reference state from the average of the first block window
% phase_base = angle(mean(cplx_shore(:, first_window_idx), 2));
% 
% for t = 1:N_time
%     phase_current = angle(cplx_shore(:, t));
%     phase_diff = atan2(sin(phase_current - phase_base), cos(phase_current - phase_base));
%     displ_pixels = phase_diff * scale_rad2mm;
%     shoreline_displ(t) = mean(displ_pixels, 'omitnan');
% end
% 
% % Zero-center baseline shift calibration
% shoreline_displ = shoreline_displ - mean(shoreline_displ(first_window_idx));
% 
% %% STEP 4: Final Time-Series Plot Generation
% figure('Color', 'w', 'Units', 'centimeters', 'Position', [10, 10, 24, 12]);
% 
% plot(timestamp_abs, shoreline_displ, 'LineWidth', 2.5, 'Color', [0.85, 0.33, 0.1]);
% grid on; box on;
% xlabel('Time of Day (HH:MM:SS)');
% ylabel('Shoreline Matrix Shift [mm]');
% title('Dynamic Shoreline Coherence Time-Series (Custom Interactive Boresight AOI)');
% 
% y_min = min(shoreline_displ);
% y_max = max(shoreline_displ);
% if y_min == y_max
%     ylim([y_min - 1, y_max + 1]);
% else
%     ylim([y_min - 0.5, y_max + 0.5]);
% end
%% plot_results_concat_relative.m - Connected Multi-File Shoreline Tracking
clear; clc; close all;

% 1. Setup Base Directories
[file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(file_dir)));

% Chronological data stack
project_folders = { ...
    'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms', ...
    'MIMO_C77_GS_P2_002_15min_20260519_121708_00910000ms'  ...
};

% Global data collectors (FIXED INITIALIZATION NAME)
combined_time = [];
combined_raw_distance = [];

% Area-Of-Interest cache variables
x_poly = [];
y_poly = [];

ylimits_zoom = [40, 90]; 
xlimits_zoom = [0, 60];

%% 2. Processing Loop Across Data Blocks
for f = 1:length(project_folders)
    current_proj = project_folders{f};
    path2mat = fullfile(file_dir, 'D00_sample_data', 'real', current_proj, '03_PSI_Interfero', '01_SLC_Filt.mat');
    
    if ~isfile(path2mat)
        warning('Skipping missing block: %s', current_proj);
        continue;
    end
    
    fprintf('Processing Data Block [%d/%d]: %s...\n', f, length(project_folders), current_proj);
    load(path2mat, 'cplx', 'y_axis', 'x_axis', 'timestamp_abs');
    amp_cube = abs(cplx);
    [~, N_time] = size(cplx);
    
    %% STEP 2.1: Run Interactive Input ONLY on the first file pass
    if f == 1
        mean_amp = mean(amp_cube, 2);
        ampl_clean = log10(mean_amp);
        cutoff = prctile(ampl_clean, 15);
        ampl_clean(ampl_clean < cutoff) = cutoff;
        
        fig_select = figure('Name', 'Target Shoreline Anchor Setup', 'units', 'normalized', 'outerposition', [0.15 0.1 0.7 0.8]);
        plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, ampl_clean, ylimits_zoom, xlimits_zoom, 'scatter');
        colorbar; clim([prctile(ampl_clean, 5), prctile(ampl_clean, 95)]);
        axis equal; box on;
        title('Draw your tracking window boundary over the bank, then click CONFIRM AREA');
        
        btn = uicontrol(fig_select, 'Style', 'pushbutton', 'String', 'CONFIRM AREA', ...
            'Units', 'normalized', 'Position', [0.02, 0.90, 0.15, 0.05], ...
            'BackgroundColor', [0.2 0.6 0.2], 'ForegroundColor', 'w', ...
            'FontWeight', 'bold', 'FontSize', 11, ...
            'Callback', @(src, event) uiresume(fig_select));
        
        roi = drawpolygon(gca, 'Color', 'r', 'LineWidth', 2);
        uiwait(fig_select);
        
        if isvalid(roi)
            roi_vertices = roi.Position;
            x_poly = roi_vertices(:, 1);
            y_poly = roi_vertices(:, 2);
        else
            error('Setup aborted by closing window.');
        end
        if ishandle(fig_select), close(fig_select); end
    end
    
    %% STEP 2.2: Apply the identical mask geometry to this dataset block
    spatial_mask = inpolygon(x_axis, y_axis, x_poly, y_poly);
    y_channel = y_axis(spatial_mask);
    amp_channel = amp_cube(spatial_mask, :);
    
    [y_sorted, sort_idx] = sort(y_channel);
    amp_profile_series = amp_channel(sort_idx, :);
    amp_profile_series = movmean(amp_profile_series, 5, 1);
    
    %% STEP 2.3: Core Boundary Tracking Calculation
    edge_block_meters = zeros(N_time, 1);
    median_profile = median(amp_profile_series, 2);
    target_threshold = min(median_profile) + 0.35 * (max(median_profile) - min(median_profile));
    
    for t = 1:N_time
        current_profile = amp_profile_series(:, t);
        cross_idx = find(current_profile < target_threshold, 1, 'first');
        if isempty(cross_idx), [~, cross_idx] = min(current_profile); end
        
        if cross_idx > 1 && cross_idx < length(y_sorted)
            p1 = current_profile(cross_idx-1); p2 = current_profile(cross_idx);
            y1 = y_sorted(cross_idx-1);       y2 = y_sorted(cross_idx);
            edge_block_meters(t) = y1 + (target_threshold - p1) * (y2 - y1) / (p2 - p1);
        else
            edge_block_meters(t) = y_sorted(cross_idx);
        end
    end
    
    % Append results to the global array stack (FIXED MATCHING NAMES)
    combined_time = [combined_time, timestamp_abs];
    combined_raw_distance = [combined_raw_distance; edge_block_meters];
end

%% 3. Post-Processing & Connected Normalization
if isempty(combined_raw_distance)
    error('No data fields successfully executed.');
end

% Apply timeline noise dampening
absolute_distance_smooth = movmean(combined_raw_distance, 15);

% Normalize relative displacement to zero based strictly on the start of file P2_001
relative_shift_meters = absolute_distance_smooth - absolute_distance_smooth(1);

%% 4. Generate Connected Master Trend Plot
figure('Color', 'w', 'Units', 'centimeters', 'Position', [8, 8, 26, 13]);
plot(combined_time, relative_shift_meters, 'LineWidth', 2.5, 'Color', [0.49, 0.18, 0.56]);
grid on; box on;
xlabel('Continuous Observation Time (HH:MM:SS)');
ylabel('Relative Shoreline Shift [meters]');
title('Extended Multi-File Shoreline Displacement Timeline (Identical Position Tracking)');

% Framing limits focused around the shift area
ylim([-5, 5]);