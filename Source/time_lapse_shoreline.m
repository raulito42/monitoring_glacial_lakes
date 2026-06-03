%% plot_results.m - Memory-Optimized Mask Router & Viewer (Optimized for Parameter Tuning)
clear; clc; close all;

% 1. Set paths
[file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(file_dir)));

name2proj = 'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms';
path2proj = fullfile(file_dir, 'D00_sample_data', 'real', name2proj);
fname = '01_SLC_Filt.mat';
path2mat = fullfile(path2proj, '03_PSI_Interfero', fname);

if ~isfile(path2mat)
    error('File not found! Verify your sample paths.');
end

% Cache files
path_kmeans_cluster = fullfile(path2proj, 'kmeans_cluster.mat');
path_adjusted_cluster = fullfile(path2proj, 'adj_cluster.mat');

% Define processing window spatial boundaries (for unified cropping)
min_range = 10;   max_range = 60;
min_angle = -50;  max_angle = 50; 

load_slc = false;

% %% 2. TIER 1: LOAD OR COMPUTE BASE K-MEANS FEATURES (Heavy I/O Guarded)
% if isfile(path_kmeans_cluster)
%     fprintf('=== [ROUTE A] Loading K-Means base features from cache... ===\n');
%     load(path_kmeans_cluster, 'raw_sparse_land_mask', 'x_axis', 'y_axis', 'timestamp_abs');
%     load_slc = true;
% else
%     fprintf('=== [ROUTE B] No feature cache found. Initiating heavy computation... ===\n');
%     fprintf('Loading SLC file...\n');
%     load(path2mat, 'y_axis', 'x_axis', 'timestamp_abs', 'cplx');
% 
%     % Apply structural spatial domain cropping bounds
%     pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
%     pixel_angles = atan2d(y_axis, x_axis); 
%     keep_mask = (pixel_ranges >= min_range) & (pixel_ranges <= max_range) & ...
%                 (pixel_angles >= min_angle) & (pixel_angles <= max_angle);
% 
%     x_axis = x_axis(keep_mask);
%     y_axis = y_axis(keep_mask);
% 
%     cplx = cplx(keep_mask, :);
% 
%     % Reference time window configuration (5-second phase calibration baseline)
%     ref_window_duration = seconds(15);
%     ref_start_time = timestamp_abs(1);
%     ref_end_time = ref_start_time + ref_window_duration;
%     ref_frame_idx = (timestamp_abs >= ref_start_time) & (timestamp_abs <= ref_end_time);
% 
%     global_ref_vector = mean(cplx(:, ref_frame_idx), 2);
%     global_mean_amp = mean(abs(cplx), 2);
%     global_amp_norm = global_mean_amp / (max(global_mean_amp) + eps);
%     global_amp_gamma = global_amp_norm.^0.45;
% 
%     global_interf_phase = angle(cplx .* conj(global_ref_vector));
%     global_phase_var = var(global_interf_phase, [], 2);
%     global_coherence = abs(mean(exp(1i * global_interf_phase), 2));
% 
%     % Execute initial K-Means segmentation
%     fprintf('Running K-Means statistical clustering...\n');
%     global_features_scaled = zscore([global_amp_gamma, global_phase_var, global_coherence]);
%     global_clusters = kmeans(global_features_scaled, 2, 'Replicates', 10);
% 
%     if mean(global_coherence(global_clusters == 1)) > mean(global_coherence(global_clusters == 2))
%         global_clusters = 3 - global_clusters;
%     end
%     raw_sparse_land_mask = (global_clusters == 2);
%     raw_sparse_land_mask(global_coherence < 0.35) = false; 
% 
%     % Instantly save K-Means features to avoid repeating this heavy step
%     fprintf('Saving base K-Means features to: %s\n', path_kmeans_cluster);
%     save(path_kmeans_cluster, 'raw_sparse_land_mask', 'x_axis', 'y_axis', 'timestamp_abs', '-v7.3');
%     clear cplx; % Flush memory immediately before moving to tuning
% end
% 
% % Clean data coordinates for DBSCAN input
% sparse_land_x = x_axis(raw_sparse_land_mask);
% sparse_land_y = y_axis(raw_sparse_land_mask);
% 
% if isempty(sparse_land_x)
%     error('No land points detected. Check your K-Means clustering initialization settings.');
% end
% 
% % =========================================================================
% % ADAPTIVE GEOMETRY ENGINE: Replaces static manual tuning parameters
% % =========================================================================
% 
% % Calculate the physical range of every sparse land pixel candidate
% sparse_ranges = sqrt(sparse_land_x.^2 + sparse_land_y.^2);
% mean_sparse_range = median(sparse_ranges);
% 
% % Dynamically scale Epsilon based on physical distance (Point Dilution Guard)
% % Base factor (0.09) expands search radius proportionally to range
% dbscan_epsilon = max(1.8, mean_sparse_range * 0.09); 
% 
% % Dynamically scale MinPts to compensate for density drops at a distance
% if mean_sparse_range > 40
%     dbscan_min_pts = 6;   % Let sparse, far-away arcs form a cluster easily
% else
%     dbscan_min_pts = 12;  % Force tight, dense groupings for messy near-field clutter
% end
% 
% % Tighten or relax alpha radius alongside epsilon to ensure smooth fills
% alpha_radius = dbscan_epsilon * 0.4;
% 
% fprintf('--> Dynamic Calibration Complete at Mean Range: %.1fm\n', mean_sparse_range);
% fprintf('--> Auto-Applied Parameters -> [Eps: %.2f, MinPts: %d, Alpha: %.2f]\n', ...
%         dbscan_epsilon, dbscan_min_pts, alpha_radius);
% 
% % Execute isolation loop
% spatial_clusters = dbscan([sparse_land_x, sparse_land_y], dbscan_epsilon, dbscan_min_pts);
% valid_cluster_idx = (spatial_clusters > 0);
% 
% if ~any(valid_cluster_idx)
%     warning('DBSCAN dropped all land elements. Falling back to default backup parameters.');
%     % Hardcoded absolute fallback if spatial domain is completely empty
%     spatial_clusters = dbscan([sparse_land_x, sparse_land_y], 3.5, 10);
%     valid_cluster_idx = (spatial_clusters > 0);
% end
% 
% if ~any(valid_cluster_idx)
%     clean_land_x = sparse_land_x; 
%     clean_land_y = sparse_land_y;
% else
%     unique_clusters = unique(spatial_clusters(valid_cluster_idx));
%     cluster_sizes = histcounts(spatial_clusters(valid_cluster_idx), [unique_clusters; max(unique_clusters)+1]);
%     [~, largest_idx] = max(cluster_sizes);
%     land_density_mask = (spatial_clusters == unique_clusters(largest_idx));
% 
%     clean_land_x = sparse_land_x(land_density_mask);
%     clean_land_y = sparse_land_y(land_density_mask);
% end
% 
% % Envelope infill via matching adaptive alpha shape
% fprintf('Solid-filling ground mask using alpha-envelopes...\n');
% shp = alphaShape(clean_land_x, clean_land_y, alpha_radius);
% binary_land_mask = inShape(shp, x_axis, y_axis);
% 
% % Export finalized mask metrics to final cache
% fprintf('Exporting finalized mask metrics to cache: %s\n', path_adjusted_cluster);
% save(path_adjusted_cluster, 'binary_land_mask', 'raw_sparse_land_mask', 'x_axis', 'y_axis', 'timestamp_abs');
% 
% %% 4.5 COMPARISON PLOT DISPLAY & INTERACTIVE ROI SELECTION
% fprintf('Generating comparison plots...\n');
% comp_fig = figure('Name', 'Spatial Processing Comparison & ROI Selection', ...
%                   'units', 'normalized', 'outerposition', [0.1 0.3 0.8 0.5]);
% comp_ylim = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
% comp_xlim = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
% 
% % Subplot 1: Raw Unfilled Data Structure
% ax_comp(1) = subplot(1, 2, 1);
% plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(raw_sparse_land_mask), comp_ylim, comp_xlim, 'scatter');
% title('1. Raw K-Means Unstructured Mask', 'FontSize', 12);
% h_cb1 = colorbar; h_cb1.Ticks = [0, 1]; h_cb1.TickLabels = {'Water Area', 'Sparse Land Points'};
% colormap(ax_comp(1), [0.15 0.35 0.65; 0.85 0.35 0.25]); clim([0, 1]); axis equal; box on; grid on;
% 
% % Subplot 2: Solid Infilled Mask Layout (Used for Interactive Drawing)
% ax_comp(2) = subplot(1, 2, 2);
% plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(binary_land_mask), comp_ylim, comp_xlim, 'scatter');
% title('2. Click to Draw Tracking ROI (Double-click to finalize)', 'FontSize', 12);
% h_cb2 = colorbar; h_cb2.Ticks = [0, 1]; h_cb2.TickLabels = {'Open Water Body', 'Solid Filled Ground'};
% colormap(ax_comp(2), [0.15 0.35 0.65; 0.25 0.75 0.25]); clim([0, 1]); axis equal; box on; grid on;
% 
% linkproperties = linkprop(ax_comp, {'XLim', 'YLim'});
% setappdata(comp_fig, 'ComparisonLink', linkproperties);
% sgtitle('Morphological Mask Optimization & Region of Interest Selection', 'FontSize', 14, 'FontWeight', 'bold');
% drawnow;
% 
% % --- INTERACTIVE ROI DRAWING STEP ---
% fprintf('\n[ACTION REQUIRED]: Go to Plot Figure. Click vertices on Subplot 2 to draw a polygon covering your target shoreline area.\n');
% fprintf('Double-click the last vertex or press ENTER to close the loop.\n');
% 
% % Initialize dynamic interactive ROI tool on Subplot 2
% roi_tool = drawpolygon(ax_comp(2), 'Color', 'r', 'LineWidth', 1.5);
% 
% % Extract drawn boundary coordinates
% roi_vertices = roi_tool.Position; 
% if isempty(roi_vertices)
%     warning('No ROI drawn. Defaulting to whole sector scene view.');
%     roi_spatial_mask = true(size(x_axis));
% else
%     % Map polygon interior space back into sparse scatter elements (Inverted axis to match plot function structure)
%     roi_spatial_mask = inpolygon(y_axis, x_axis, roi_vertices(:,1), roi_vertices(:,2));
% end
% 
% user_input = input('Review mask validation & ROI complete. Press [ENTER] to execute processing calculations: ', 's');
% close(comp_fig);

% Clean data coordinates for DBSCAN input
% --- MODIFIED FOR 3-CLASS TRAFFIC ROUTING ---
% Load the transition mask if we are routing via cache, otherwise extract from Route B
if isfile(path_kmeans_cluster)
    fprintf('=== [ROUTE A] Loading 3-Class K-Means features from cache... ===\n');
    load(path_kmeans_cluster, 'raw_sparse_land_mask', 'raw_transition_mask', 'x_axis', 'y_axis', 'timestamp_abs');
    load_slc = true;
else
    fprintf('=== [ROUTE B] No feature cache found. Initiating heavy 3-Class computation... ===\n');
    fprintf('Loading SLC file...\n');
    load(path2mat, 'y_axis', 'x_axis', 'timestamp_abs', 'cplx');
    
    % Apply structural spatial domain cropping bounds
    pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
    pixel_angles = atan2d(y_axis, x_axis); 
    keep_mask = (pixel_ranges >= min_range) & (pixel_ranges <= max_range) & ...
                (pixel_angles >= min_angle) & (pixel_angles <= max_angle);
            
    x_axis = x_axis(keep_mask);
    y_axis = y_axis(keep_mask);
    cplx = cplx(keep_mask, :);
    
    % Reference time window configuration (5-second phase calibration baseline)
    ref_window_duration = seconds(5);
    ref_start_time = timestamp_abs(1);
    ref_end_time = ref_start_time + ref_window_duration;
    ref_frame_idx = (timestamp_abs >= ref_start_time) & (timestamp_abs <= ref_end_time);
    
    global_ref_vector = mean(cplx(:, ref_frame_idx), 2);
    global_mean_amp = mean(abs(cplx), 2);
    global_amp_norm = global_mean_amp / (max(global_mean_amp) + eps);
    global_amp_gamma = global_amp_norm.^0.45;
    
    global_interf_phase = angle(cplx .* conj(global_ref_vector));
    global_phase_var = var(global_interf_phase, [], 2);
    global_coherence = abs(mean(exp(1i * global_interf_phase), 2));
    
    % Execute 3-Class K-Means segmentation
    fprintf('Running 3-Class K-Means statistical clustering...\n');
    global_features_scaled = zscore([global_amp_gamma, global_phase_var, global_coherence]);
    feature_weights = [1.5, 0.6, 1.2];
    global_features_scaled = global_features_scaled .* feature_weights;
    global_clusters = kmeans(global_features_scaled, 3, 'Replicates', 10);
    
    % Sort clusters mathematically by their mean coherence values
    mean_coherence_per_cluster = zeros(3,1);
    for k = 1:3
        mean_coherence_per_cluster(k) = mean(global_coherence(global_clusters == k));
    end
    [~, sorted_idx] = sort(mean_coherence_per_cluster);
    
    water_cluster_ID      = sorted_idx(1); % Lowest coherence
    transition_cluster_ID = sorted_idx(2); % Mid coherence (Shore boundary, wet area)
    land_cluster_ID       = sorted_idx(3); % Highest coherence (Solid rock/dry ground)
    
    raw_sparse_land_mask = (global_clusters == land_cluster_ID);
    raw_transition_mask  = (global_clusters == transition_cluster_ID);
    
    % Instantly save updated 3-Class features to avoid repeating heavy steps
    fprintf('Saving 3-Class K-Means features to: %s\n', path_kmeans_cluster);
    save(path_kmeans_cluster, 'raw_sparse_land_mask', 'raw_transition_mask', 'x_axis', 'y_axis', 'timestamp_abs', '-v7.3');
    clear cplx; % Flush memory immediately before moving to tuning
end

% Isolate pure high-stability land coordinates for DBSCAN masking skeleton
sparse_land_x = x_axis(raw_sparse_land_mask);
sparse_land_y = y_axis(raw_sparse_land_mask);

if isempty(sparse_land_x)
    error('No stable land points detected. Check your K-Means clustering initialization settings.');
end

% =========================================================================
% ADAPTIVE GEOMETRY ENGINE: Profiles structural core land components
% =========================================================================
% Calculate the physical range of every sparse land pixel candidate
sparse_ranges = sqrt(sparse_land_x.^2 + sparse_land_y.^2);
mean_sparse_range = median(sparse_ranges);

% Dynamically scale Epsilon based on physical distance (Point Dilution Guard)
dbscan_epsilon = max(1.8, mean_sparse_range * 0.09); 

% Dynamically scale MinPts to compensate for density drops at a distance
if mean_sparse_range > 40
    dbscan_min_pts = 6;   
else
    dbscan_min_pts = 12;  
end

% Tighten or relax alpha radius alongside epsilon to ensure smooth fills
alpha_radius = dbscan_epsilon * 0.4;
fprintf('--> Dynamic Calibration Complete at Mean Range: %.1fm\n', mean_sparse_range);
fprintf('--> Auto-Applied Parameters -> [Eps: %.2f, MinPts: %d, Alpha: %.2f]\n', ...
        dbscan_epsilon, dbscan_min_pts, alpha_radius);

% Execute isolation loop
spatial_clusters = dbscan([sparse_land_x, sparse_land_y], dbscan_epsilon, dbscan_min_pts);
valid_cluster_idx = (spatial_clusters > 0);

if ~any(valid_cluster_idx)
    warning('DBSCAN dropped all land elements. Falling back to default backup parameters.');
    spatial_clusters = dbscan([sparse_land_x, sparse_land_y], 3.5, 10);
    valid_cluster_idx = (spatial_clusters > 0);
end

if ~any(valid_cluster_idx)
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

% Envelope infill via matching adaptive alpha shape (solidifies the stable mainland core)
fprintf('Solid-filling ground mask using alpha-envelopes...\n');
shp = alphaShape(clean_land_x, clean_land_y, alpha_radius);
binary_land_mask = inShape(shp, x_axis, y_axis);

% Export finalized mask metrics to final cache
fprintf('Exporting finalized mask metrics to cache: %s\n', path_adjusted_cluster);
save(path_adjusted_cluster, 'binary_land_mask', 'raw_sparse_land_mask', 'raw_transition_mask', 'x_axis', 'y_axis', 'timestamp_abs');

%% 4.5 COMPARISON PLOT DISPLAY & INTERACTIVE ROI SELECTION
fprintf('Generating comparison plots...\n');
comp_fig = figure('Name', 'Spatial Processing Comparison & ROI Selection', ...
                  'units', 'normalized', 'outerposition', [0.1 0.3 0.8 0.5]);
comp_ylim = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
comp_xlim = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;

% Subplot 1: 3-Class Categorical Map Visualizer
ax_comp(1) = subplot(1, 2, 1);
% Create a categorical array visualization mapping (0 = Water, 1 = Transition Zone, 2 = Core Land)
categorical_map = zeros(size(raw_sparse_land_mask));
categorical_map(raw_transition_mask) = 1;
categorical_map(raw_sparse_land_mask) = 2;

plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, categorical_map, comp_ylim, comp_xlim, 'scatter');
title('1. 3-Class Unstructured Mask (K-Means Core)', 'FontSize', 12);
h_cb1 = colorbar; h_cb1.Ticks = [0, 1, 2]; h_cb1.TickLabels = {'Open Water', 'Transition Zone', 'Stable Land'};
% Custom colormap layout: Clear Deep Blue (Water), High-Visibility Orange (Transition), Crimson (Land)
colormap(ax_comp(1), [0.15 0.35 0.65; 0.95 0.60 0.10; 0.75 0.15 0.15]); clim([0, 2]); axis equal; box on; grid on;

% Subplot 2: Solid Infilled Mask Layout (Updated to show 3-Classes for precise ROI drawing)
ax_comp(2) = subplot(1, 2, 2);

% NEW COMBINATION LOGIC: Build a 3-class map that includes the alpha-shape filled ground core
infilled_3class_map = zeros(size(binary_land_mask));   % 0 = Open Water Area
infilled_3class_map(raw_transition_mask) = 1;         % 1 = Dynamic Transition Zone
infilled_3class_map(binary_land_mask) = 2;            % 2 = Solid Ground Core

plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, infilled_3class_map, comp_ylim, comp_xlim, 'scatter');
title('2. Click to Draw Tracking ROI (Double-click to finalize)', 'FontSize', 12);
h_cb2 = colorbar; h_cb2.Ticks = [0, 1, 2]; h_cb2.TickLabels = {'Open Water', 'Transition Zone', 'Solid Ground Core'};

% Apply the matching 3-color map so you can see exactly where to draw your ROI box!
colormap(ax_comp(2), [0.15 0.35 0.65; 0.95 0.60 0.10; 0.75 0.15 0.15]); clim([0, 2]); axis equal; box on; grid on;
linkproperties = linkprop(ax_comp, {'XLim', 'YLim'});
setappdata(comp_fig, 'ComparisonLink', linkproperties);
sgtitle('3-Class Morphological Optimization & Region of Interest Selection', 'FontSize', 14, 'FontWeight', 'bold');
drawnow;

% --- INTERACTIVE ROI DRAWING STEP ---
fprintf('\n[ACTION REQUIRED]: Go to Plot Figure. Click vertices on Subplot 2 to draw a polygon covering your target shoreline area.\n');
fprintf('Double-click the last vertex or press ENTER to close the loop.\n');

% Initialize dynamic interactive ROI tool on Subplot 2
roi_tool = drawpolygon(ax_comp(2), 'Color', 'r', 'LineWidth', 1.5);

% Extract drawn boundary coordinates
roi_vertices = roi_tool.Position; 
if isempty(roi_vertices)
    warning('No ROI drawn. Defaulting to whole sector scene view.');
    roi_spatial_mask = true(size(x_axis));
else
    % Map polygon interior space back into sparse scatter elements
    roi_spatial_mask = inpolygon(y_axis, x_axis, roi_vertices(:,1), roi_vertices(:,2));
end
user_input = input('Review mask validation & ROI complete. Press [ENTER] to execute processing calculations: ', 's');
close(comp_fig);

%% 4. TIER 3: SELECTIVE DYNAMIC LOADING TRIGGER FOR PLOTS
if ~exist('cplx', 'var')
    fprintf('Loading SLC complex matrix...\n');
    meta = load(path2mat, 'cplx', 'x_axis', 'y_axis');
    pixel_ranges_meta = sqrt(meta.x_axis.^2 + meta.y_axis.^2);
    pixel_angles_meta = atan2d(meta.y_axis, meta.x_axis); 
    keep_mask_meta = (pixel_ranges_meta >= min_range) & (pixel_ranges_meta <= max_range) & ...
                     (pixel_angles_meta >= min_angle) & (pixel_angles_meta <= max_angle);
    cplx = meta.cplx(keep_mask_meta, :);
    clear meta; 
end

%% 5. CHRONOLOGICAL WINDOW TIMELINE CONFIGURATION (Graphics Initialization)
window_duration = seconds(10); 
step_duration = seconds(10);   
start_time = timestamp_abs(1);
end_time = timestamp_abs(end);

ylimits = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
xlimits = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;

current_start = start_time;
loop_count = 1;
max_estimated_loops = floor(seconds(end_time - start_time) / seconds(step_duration)) + 2;

% Tracking arrays
tracked_shoreline_range = NaN(max_estimated_loops, 1);
relative_waterframe_shift = NaN(max_estimated_loops, 1);
time_axis = NaT(max_estimated_loops, 1);
coherence_water_threshold = 0.40; 

baseline_range = [];

% Build Fast-Update Interface Layout
fig = figure('Name', 'Interactive ROI Shoreline Tracking Dashboard', 'units', 'normalized', 'outerposition', [0 0.1 1 0.7]);

% ax1 = subplot(1,2,1);
% h_trend = plot(ax1, NaT, NaN, '-o', 'LineWidth', 2.5, 'Color', [0.0 0.45 0.74], 'MarkerSize', 5, 'MarkerFaceColor', [0 0.2 0.5]);
% title(ax1, 'Calculated Waterfront Distance Trend (Within ROI)', 'FontSize', 12);
% xlabel(ax1, 'Timeline [HH:MM:SS]'); ylabel(ax1, 'Shoreline Range Edge [meters]');
% grid(ax1, 'on'); box(ax1, 'on');
% xlim(ax1, [datetime(start_time) datetime(end_time)]); ylim(ax1, [min_range max_range]);

% NEW: Plotting relative change array instead of absolute range
ax1 = subplot(1,2,1);
h_trend = plot(ax1, NaT, NaN, '-o', 'LineWidth', 2.5, 'Color', [0.85 0.33 0.1], 'MarkerSize', 5, 'MarkerFaceColor', [0.5 0.1 0]);
title(ax1, 'Relative Waterline Displacement (\Delta Level)', 'FontSize', 12);
xlabel(ax1, 'Timeline [HH:MM:SS]'); 
ylabel(ax1, 'Water Displacement [Meters] (+=Encroachment, -=Recession)');
grid(ax1, 'on'); box(ax1, 'on');
xlim(ax1, [datetime(start_time) datetime(end_time)]); 
ylim(ax1, [-5 5]); % NEW: Centered around zero (tracks +/- 5 meters of shoreline shift)
yline(ax1, 0, 'k--', 'LineWidth', 1.5); % Reference zero line

ax2 = subplot(1,2,2);
plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, zeros(size(x_axis)), ylimits, xlimits, 'scatter');
hold(ax2, 'on');
h_radar_scatter = findobj(ax2, 'Type', 'Scatter');
h_shoreline_scatter = scatter(ax2, NaN, NaN, 14, 'r', 'filled');

% Draw the boundary of your user-selected ROI area as a reference ring
if exist('roi_vertices', 'var') && ~isempty(roi_vertices)
    plot(ax2, roi_vertices(:,1), roi_vertices(:,2), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Bound ROI');
end

% colorbar(ax2); clim(ax2, [0.2, 0.8]); colormap(ax2, parula);
% title(ax2, 'Live Tracking View (Red Points = Active Water Interface)', 'FontSize', 12);
% axis(ax2, 'equal'); box(ax2, 'on');
% h_sgtitle = sgtitle(fig, 'Initializing Fast Timeline Track Loop...', 'FontWeight', 'bold', 'FontSize', 14);

colorbar(ax2); clim(ax2, [0.2, 0.8]); colormap(ax2, parula);
title(ax2, 'Live Tracking View (Red Points = Active Water Interface)', 'FontSize', 12);
axis(ax2, 'equal'); box(ax2, 'on');
h_sgtitle = sgtitle(fig, 'Initializing Relative Tracking Engine...', 'FontWeight', 'bold', 'FontSize', 14);
% 
% %% 6. CHRONOLOGICAL PROCESSING LOOP & INTERACTIVE TRACKING
% while (current_start + window_duration) <= end_time
%     current_end = current_start + window_duration;
%     frame_idx = (timestamp_abs >= current_start) & (timestamp_abs <= current_end);
% 
%     if sum(frame_idx) < 2
%         current_start = current_start + step_duration;
%         continue;
%     end
% 
%     % Compute short-term window metrics
%     cplx_slice = cplx(:, frame_idx);
%     cplx_ref = cplx_slice(:, 1);
%     slice_interf_phase = angle(cplx_slice .* conj(cplx_ref));
%     slice_coherence = abs(mean(exp(1i * slice_interf_phase), 2));
% 
%     pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
% 
%     % --- SHORELINE ENGINE WITH COMBINED MASK & ROI ---
%     % Combined mask rules out global noise by isolating points that are BOTH inside land AND inside your ROI
% 
%     active_tracking_mask = binary_land_mask & roi_spatial_mask;
%     water_encroachment_idx = active_tracking_mask & (slice_coherence < coherence_water_threshold);
% 
%     if any(water_encroachment_idx)
%         % Switch from min() to mean() to track sub-bin boundary shifts!
%         tracked_shoreline_range(loop_count) = mean(pixel_ranges(water_encroachment_idx));
%     else
%         tracked_shoreline_range(loop_count) = max(pixel_ranges(active_tracking_mask));
%     end
% 
%     time_axis(loop_count) = current_start;
% 
%     % --- RAPID RE-RENDERING UPDATES ---
%     if ~ishandle(fig), break; end
% 
%     set(h_trend, 'XData', time_axis(1:loop_count), 'YData', tracked_shoreline_range(1:loop_count));
%     set(h_radar_scatter, 'CData', slice_coherence);
% 
%     if any(water_encroachment_idx)
%         set(h_shoreline_scatter, 'XData', y_axis(water_encroachment_idx), 'YData', x_axis(water_encroachment_idx));
%     else
%         set(h_shoreline_scatter, 'XData', NaN, 'YData', NaN);
%     end
% 
%     set(h_sgtitle, 'String', sprintf('Shoreline Processing Window: %s to %s', datestr(current_start, 'HH:MM:SS'), datestr(current_end, 'HH:MM:SS')));
% 
%     drawnow limitrate;
%     pause(0.05); % Fast update loop pacing
% 
%     loop_count = loop_count + 1;
%     current_start = current_start + step_duration;
% end
%% 6. CHRONOLOGICAL PROCESSING LOOP & INTERACTIVE TRACKING
while (current_start + window_duration) <= end_time
    current_end = current_start + window_duration;
    frame_idx = (timestamp_abs >= current_start) & (timestamp_abs <= current_end);
    
    if sum(frame_idx) < 2
        current_start = current_start + step_duration;
        continue;
    end
    
    % Compute short-term window metrics
    cplx_slice = cplx(:, frame_idx);
    cplx_ref = cplx_slice(:, 1);
    slice_interf_phase = angle(cplx_slice .* conj(cplx_ref));
    slice_coherence = abs(mean(exp(1i * slice_interf_phase), 2));
    
    pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
    
    active_tracking_mask = binary_land_mask & roi_spatial_mask;
    water_encroachment_idx = active_tracking_mask & (slice_coherence < coherence_water_threshold);
    
    if any(water_encroachment_idx)
        tracked_shoreline_range(loop_count) = mean(pixel_ranges(water_encroachment_idx));
    else
        tracked_shoreline_range(loop_count) = max(pixel_ranges(active_tracking_mask));
    end
    
    % --- NEW: RELATIVE DISPLACEMENT CALCULATION ENGINE ---
    if isempty(baseline_range) && ~isnan(tracked_shoreline_range(loop_count))
        % Establish the baseline range using the first valid calculated frame
        baseline_range = tracked_shoreline_range(loop_count);
        fprintf('--> Baseline Shoreline Range Established at: %.2f meters\n', baseline_range);
    end
    
    if ~isempty(baseline_range)
        % Calculate relative displacement (+ means water advanced closer, - means retreated)
        relative_waterframe_shift(loop_count) = baseline_range - tracked_shoreline_range(loop_count);
    else
        relative_waterframe_shift(loop_count) = 0;
    end
    
    time_axis(loop_count) = current_start;
    
    % --- RAPID RE-RENDERING UPDATES ---
    if ~ishandle(fig), break; end
    
    % Update trend line using the relative data array
    set(h_trend, 'XData', time_axis(1:loop_count), 'YData', relative_waterframe_shift(1:loop_count));
    set(h_radar_scatter, 'CData', slice_coherence);
    
    if any(water_encroachment_idx)
        set(h_shoreline_scatter, 'XData', y_axis(water_encroachment_idx), 'YData', x_axis(water_encroachment_idx));
    else
        set(h_shoreline_scatter, 'XData', NaN, 'YData', NaN);
    end
    
    % Dynamic title showing real-time displacement status
    set(h_sgtitle, 'String', sprintf('Processing Window: %s | Relative Shift: %+.2fm', ...
        datestr(current_start, 'HH:MM:SS'), relative_waterframe_shift(loop_count)));
    
    drawnow limitrate;
    pause(0.05); 
    
    loop_count = loop_count + 1;
    current_start = current_start + step_duration;
end