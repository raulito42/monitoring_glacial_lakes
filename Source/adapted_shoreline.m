%% plot_results.m - Physics-Engine Mask Router & Viewer
clear; clc; close all;

%% 1. SET PATHS & IDENTIFIERS
[file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(file_dir)));

% Updated project name target
name2proj = 'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms';
path2proj = fullfile(file_dir, 'D00_sample_data', 'real', name2proj);
fname = '01_SLC_Filt.mat';
path2mat = fullfile(path2proj, '03_PSI_Interfero', fname);

if ~isfile(path2mat)
    error('File not found! Verify your sample paths: %s', path2mat);
end

% Multi-tier caching infrastructure
path2_physics_cache = fullfile(path2proj, 'physics_feature_cache.mat');
path2mask = fullfile(path2proj, 'shoreline_mask.mat');

% Define processing window spatial boundaries (Unified cropping)
min_range = 20;   max_range = 60;
min_angle = -50;  max_angle = 50; 

%% 2. TIER 1: COHERENCE & PHASE VARIANCE ENGINE (Heavy I/O Guarded)
if isfile(path2_physics_cache)
    fprintf('=== [ROUTE A] Loading physics features from cache... ===\n');
    load(path2_physics_cache, 'global_coherence', 'global_phase_var', 'x_axis', 'y_axis', 'timestamp_abs');
else
    fprintf('=== [ROUTE B] No cache found. Extracting physical vectors from heavy SLC data... ===\n');
    load(path2mat, 'y_axis', 'x_axis', 'timestamp_abs');
    
    % Apply spatial grid cropping
    pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
    pixel_angles = atan2d(y_axis, x_axis); 
    keep_mask = (pixel_ranges >= min_range) & (pixel_ranges <= max_range) & ...
                (pixel_angles >= min_angle) & (pixel_angles <= max_angle);
            
    x_axis = x_axis(keep_mask);
    y_axis = y_axis(keep_mask);
    
    fprintf('Reading heavy complex matrix for temporal analysis...\n');
    load(path2mat, 'cplx');
    cplx = cplx(keep_mask, :);
    
    % Reference calibration baseline (First 5 seconds)
    ref_window_duration = seconds(5);
    ref_start_time = timestamp_abs(1);
    ref_end_time = ref_start_time + ref_window_duration;
    ref_frame_idx = (timestamp_abs >= ref_start_time) & (timestamp_abs <= ref_end_time);
    
    global_ref_vector = mean(cplx(:, ref_frame_idx), 2);
    global_interf_phase = angle(cplx .* conj(global_ref_vector));
    
    % Compute our physical indicators
    fprintf('Calculating temporal stability metrics...\n');
    global_phase_var = var(global_interf_phase, [], 2);
    global_coherence = abs(mean(exp(1i * global_interf_phase), 2));
    
    % Save data features to prevent reloading the huge mat file next run
    fprintf('Saving physics features to cache...\n');
    save(path2_physics_cache, 'global_coherence', 'global_phase_var', 'x_axis', 'y_axis', 'timestamp_abs', '-v7.3');
    clear cplx; % Instant RAM wipe
end

%% 3. TIER 2: ADAPTIVE HISTOGRAM & MORPHOLOGICAL TUNING
% =========================================================================
% DEBUG CORNER: Fine-tune spatial morphology here
% =========================================================================
dbscan_epsilon = 3.2;    % Search radius between points (meters)
dbscan_min_pts = 10;     % Higher value cleans up more water noise artifacts
alpha_radius = 4.0;      % Controls tightness of solid ground fill envelope

fprintf('Executing automated bi-modal histogram thresholding...\n');
[counts, edges] = histcounts(global_coherence, 256);
bin_centers = (edges(1:end-1) + edges(2:end)) / 2;
norm_counts = counts / sum(counts);

% Find optimal dividing point between water and land
otsu_level = otsuthresh(norm_counts); 
adaptive_coherence_thresh = min(global_coherence) + otsu_level * (max(global_coherence) - min(global_coherence));
adaptive_coherence_thresh = max(0.28, min(adaptive_coherence_thresh, 0.45)); % Bounds check

%% DETERMINISTIC LOGIC SEEDING (The Smart Guesses)
% Rule 1: Water phase variance theoretically approaches ~3.29 (Uniform distribution noise)
% Rule 2: Land must have high coherence AND low phase variance
raw_sparse_land_mask = (global_coherence >= adaptive_coherence_thresh) & (global_phase_var < 2.5);

% Isolate points for spatial grouping
sparse_land_x = x_axis(raw_sparse_land_mask);
sparse_land_y = y_axis(raw_sparse_land_mask);

if isempty(sparse_land_x)
    error('No seed points survived deterministic filtering. Loosen parameters.');
end

% Cluster extraction via DBSCAN
fprintf('Applying DBSCAN spatial isolation [Eps: %.1f, MinPts: %d]...\n', dbscan_epsilon, dbscan_min_pts);
spatial_clusters = dbscan([sparse_land_x, sparse_land_y], dbscan_epsilon, dbscan_min_pts);
valid_cluster_idx = (spatial_clusters > 0);

if ~any(valid_cluster_idx)
    warning('DBSCAN isolated all inputs. Preserving raw inputs.');
    clean_land_x = sparse_land_x; 
    clean_land_y = sparse_land_y;
else
    unique_clusters = unique(spatial_clusters(valid_cluster_idx));
    cluster_sizes = histcounts(spatial_clusters(valid_cluster_idx), [unique_clusters; max(unique_clusters)+1]);
    [~, largest_idx] = max(cluster_sizes);
    land_density_mask = (spatial_clusters == unique_clusters(largest_idx));
    
    clean_land_x = sparse_land_x(land_density_mask);
    clean_land_y = sparse_land_y(land_density_mask);
end

% Solid-filling ground mask via Alpha Shapes
fprintf('Generating continuous alpha-shape envelope...\n');
shp = alphaShape(clean_land_x, clean_land_y, alpha_radius);
binary_land_mask = inShape(shp, x_axis, y_axis);

% Save finalized mask for tracking loop execution
save(path2mask, 'binary_land_mask', 'raw_sparse_land_mask', 'x_axis', 'y_axis', 'timestamp_abs');

%% 4. TIER 3: CHRONOLOGICAL LOADING & DISPLAY DASHBOARD
fprintf('Loading complex records for tracking visualization...\n');
load(path2mat, 'cplx');
pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
pixel_angles = atan2d(y_axis, x_axis); 
keep_mask = (pixel_ranges >= min_range) & (pixel_ranges <= max_range) & ...
            (pixel_angles >= min_angle) & (pixel_angles <= max_angle);
cplx = cplx(keep_mask, :);

% Setup comparison figure window
comp_fig = figure('Name', 'Physics-Driven Mask Optimization Summary', ...
                  'units', 'normalized', 'outerposition', [0.1 0.3 0.8 0.5]);
comp_ylim = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
comp_xlim = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;

% Subplot 1: Adaptive Coherence Thresholding View
ax_comp(1) = subplot(1, 2, 1);
plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, global_coherence, comp_ylim, comp_xlim, 'scatter');
title(sprintf('1. Coherence Matrix (Cutoff: %.2f)', adaptive_coherence_thresh), 'FontSize', 12);
colorbar; colormap(ax_comp(1), parula); clim([0.2 0.8]); axis equal; box on; grid on;

% Subplot 2: Solid Filled Resulting Mask Layout
ax_comp(2) = subplot(1, 2, 2);
plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(binary_land_mask), comp_ylim, comp_xlim, 'scatter');
title('2. Final Physics-Engine Ground Mask', 'FontSize', 12);
h_cb2 = colorbar; h_cb2.Ticks = [0, 1]; h_cb2.TickLabels = {'Water Body', 'Solid Ground'};
colormap(ax_comp(2), [0.15 0.35 0.65; 0.25 0.75 0.25]); clim([0, 1]); axis equal; box on; grid on;

linkprop(ax_comp, {'XLim', 'YLim'});
sgtitle(sprintf('Dynamic Site Adaptation Summary\\nProject: %s', name2proj), 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
drawnow;

user_input = input('Review mask validation complete. Press [ENTER] to execute processing loop: ', 's');

%% 5. CHRONOLOGICAL TIMELINE TRACKING LOOP
window_duration = seconds(5); step_duration = seconds(5);   
start_time = timestamp_abs(1); end_time = timestamp_abs(end);
ylimits = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
xlimits = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;

current_start = start_time; loop_count = 1;
max_estimated_loops = floor(seconds(end_time - start_time) / seconds(step_duration)) + 2;
water_level_proxy = zeros(max_estimated_loops, 1);
time_axis = zeros(max_estimated_loops, 1);

fig = figure('Name', 'Real-Time Coherence Tracking Dashboard', 'units', 'normalized', 'outerposition', [0 0.2 1 0.6]);

while (current_start + window_duration) <= end_time
    current_end = current_start + window_duration;
    frame_idx = (timestamp_abs >= current_start) & (timestamp_abs <= current_end);
    
    if sum(frame_idx) < 2
        current_start = current_start + step_duration;
        continue;
    end
    
    cplx_slice = cplx(:, frame_idx);
    cplx_ref = cplx_slice(:, 1);
    slice_interf_phase = angle(cplx_slice .* conj(cplx_ref));
    slice_coherence = abs(mean(exp(1i * slice_interf_phase), 2));
    
    water_level_proxy(loop_count) = mean(slice_coherence(binary_land_mask));
    time_axis(loop_count) = datenum(current_start);
    
    if ~ishandle(fig), break; end
    set(0, 'CurrentFigure', fig);
    
    % Plot 1: Water Level Time-Series Trend
    subplot(1,3,1);
    plot(datetime(time_axis(1:loop_count), 'ConvertFrom', 'datenum'), water_level_proxy(1:loop_count), '-o', ...
         'LineWidth', 2.5, 'Color', [0.85 0.15 0.15], 'MarkerFaceColor', [0.5 0 0]);
    title('Global Filled Mask Coherence Trend'); xlabel('Timeline [HH:MM:SS]'); ylabel('Mean Coherence');
    grid on; xlim([datetime(start_time) datetime(end_time)]); ylim([0.15 0.85]); 
    
    % Plot 2: Frame Short-term Coherence Maps
    subplot(1,3,2);
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, slice_coherence, ylimits, xlimits, 'scatter');
    colorbar; clim([0.2, 0.8]); colormap(gca, parula); title('Current Short-Term Coherence'); axis equal; box on;
    
    % Plot 3: Static Reference Mask
    subplot(1,3,3);
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(binary_land_mask), ylimits, xlimits, 'scatter');
    hcb3 = colorbar; hcb3.Ticks = [0, 1]; hcb3.TickLabels = {'Water Body', 'Solid Filled Ground'};
    colormap(gca, [0.15 0.35 0.65; 0.25 0.75 0.25]); clim([0, 1]); title('Solid Alpha-Shape Reference'); axis equal; box on;
    
    sgtitle(sprintf('Processing Window: %s to %s', datestr(current_start, 'HH:MM:SS'), datestr(current_end, 'HH:MM:SS')));
    drawnow; pause(0.04); 
    
    loop_count = loop_count + 1;
    current_start = current_start + step_duration;
end