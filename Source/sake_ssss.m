clear; clc; close all;

% =========================================================================
% 1. PATH CONFIGURATION & SPACE BOUNDARIES
% =========================================================================
[file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(file_dir)));

name2proj = 'MIMO_C77_Pond_1_100m_mitCR_20260507_155546_00048000ms';
path2proj = fullfile(file_dir, 'D00_sample_data', 'real', name2proj);
export_dir = fullfile(path2proj, 'export_xxx'); 
path_tuned_features = fullfile(export_dir, 'tuned_features.mat');

if ~isfile(path_tuned_features)
    error('Tuned feature package not found at: %s.', path_tuned_features);
end
fprintf('Loading feature pack...\n');
load(path_tuned_features); 

% =========================================================================
% 2. INITIALIZATION: GENERATE BASELINE TEMPLATE MAP
% =========================================================================
fprintf('Extracting baseline template map for geometric initialization...\n');
baseline_feature = mean(exported_coherence(:, 1:min(5, size(exported_coherence,2))), 2);

grid_base = griddata(x_axis, y_axis, double(baseline_feature), XQ, YQ, 'linear');
grid_base(isnan(grid_base)) = min(baseline_feature);

grid_base_smooth = medfilt2(grid_base, [9,9]);
grid_base_filtered = anisodiff(grid_base_smooth, 5, 0.10, 15);

% =========================================================================
% 3. INTERACTIVE ROI SELECTION VIA RE-PROJECTED SPATIAL GRID
% =========================================================================
comp_ylim = [min(y_axis), max(y_axis)]; 
comp_xlim = [min(x_axis), max(x_axis)]; 

comp_fig = figure('Name', 'Conditioned Coherence Map & Target ROI Selection', ...
                  'Units', 'normalized', 'OuterPosition', [0.1 0.1 0.8 0.8], 'Color', 'w');

ax_comp(1) = subplot(1, 2, 1);
scatter(ax_comp(1), y_axis, x_axis, 8, baseline_feature, 'filled');
title('1. Conditioned Baseline Feature Array'); axis equal; grid on; colormap(ax_comp(1), jet);

ax_comp(2) = subplot(1, 2, 2);
h_surf = pcolor(ax_comp(2), YQ, XQ, grid_base_filtered);
shading(ax_comp(2), 'interp');
title('2. Filtered Spatial Grid (Select Shoreline Target Area)'); axis equal; grid on; colormap(ax_comp(2), jet); colorbar;
linkprop(ax_comp, {'XLim', 'YLim'});

fprintf('\n[ACTION REQUIRED]: Draw a polygon enclosing the shoreline corridor on Subplot 2...\n');
roi_tool = drawpolygon(ax_comp(2), 'Color', 'r', 'LineWidth', 1.5);
roi_vertices = roi_tool.Position; 

if isempty(roi_vertices)
    roi_grid_mask = true(size(XQ));
else
    roi_grid_mask = inpolygon(YQ, XQ, roi_vertices(:,1), roi_vertices(:,2));
end
close(comp_fig);

% =========================================================================
% 4. DYNAMIC ENDPOINT SNAP ENGINE (ELIMINATES HORIZONTAL TAILS)
% =========================================================================
fprintf('Optimizing track endpoints to snap directly onto the gradient edge...\n');
[mask_rows, mask_cols] = find(roi_grid_mask);
if isempty(mask_rows)
    error('No ROI area selected. Please run again and draw a closed polygon.');
end

% Extract baseline gradient profile to find the ideal entry/exit points
[~, dY_base] = gradient(grid_base_filtered);
dY_base(dY_base < 0) = 0; 
dY_base(~roi_grid_mask) = 0;

% Snap Start Node: Look at the topmost rows of the ROI and pick the max gradient peak
top_row_limit = min(mask_rows) + 5;
[max_val_top, max_idx_top] = max(dY_base(min(mask_rows):top_row_limit, :), [], 'all', 'linear');
[start_row_offset, start_col] = ind2sub(size(dY_base(min(mask_rows):top_row_limit, :)), max_idx_top);
start_row = min(mask_rows) + start_row_offset - 1;

% Snap End Node: Look at the bottommost rows of the ROI and pick the max gradient peak
bot_row_limit = max(mask_rows) - 5;
[max_val_bot, max_idx_bot] = max(dY_base(bot_row_limit:max(mask_rows), :), [], 'all', 'linear');
[end_row_offset, end_col] = ind2sub(size(dY_base(bot_row_limit:max(mask_rows), :)), max_idx_bot);
end_row = bot_row_limit + end_row_offset - 1;

% =========================================================================
% 5. DYNAMIC SINGLE-PLOT ENGINE & VIDEO WRITER INITIALIZATION
% =========================================================================
num_frames = size(exported_coherence, 2);

video_filename = fullfile(export_dir, 'active_contour_only.mp4');
v_writer = VideoWriter(video_filename, 'MPEG-4');
v_writer.FrameRate = 4; 
v_writer.Quality = 98;
open(v_writer);

fig = figure('Name', 'Directional Gradient Waterline Tracker', 'Position', [100, 100, 850, 750], 'Color', 'w');                                        
ax = axes('Parent', fig); 

h_img = pcolor(ax, YQ, XQ, grid_base_filtered); shading(ax, 'interp'); hold(ax, 'on');
title(ax, 'Waterline Boundary Tracking (Snapped Entry/Exit Transitions)', 'FontSize', 12);
colormap(ax, bone); clim(ax, [min(exported_coherence(:)) max(exported_coherence(:))*0.8]); colorbar(ax);
xlabel(ax, 'Cross-Range Azimuth Y [m]'); ylabel(ax, 'Range X [m]');
xlim(ax, comp_ylim); ylim(ax, comp_xlim); axis(ax, 'equal'); grid(ax, 'on');

h_active_edges = plot(ax, NaN, NaN, 'r-', 'LineWidth', 2.5);
h_title = sgtitle(fig, 'Running Snapped Dijkstra Loop...');

% =========================================================================
% 6. CHRONOLOGICAL LOOP: ROI-BOUNDED DIRECTIONAL EDGE TRACKER
% =========================================================================
for f = 1:num_frames
    frame_vec = exported_coherence(:, f);
    
    grid_slice = griddata(x_axis, y_axis, double(frame_vec), XQ, YQ, 'linear');
    grid_slice(isnan(grid_slice)) = min(frame_vec);
    grid_slice_filtered = anisodiff(medfilt2(grid_slice, [9,9]), 4, 0.10, 15);
    
    % Extract horizontal directional gradient component specifically
    [~, dY] = gradient(grid_slice_filtered); 
    
    % Isolate dark-to-bright positive changes
    edge_energy = dY; 
    edge_energy(edge_energy < 0) = 0; 
    edge_energy(~roi_grid_mask) = 0;
    
    % Normalize cost domain
    edge_energy = (edge_energy - min(edge_energy(:))) / (max(edge_energy(:)) - min(edge_energy(:)) + eps);
    weight_matrix = 1.0 - edge_energy + 0.01; 
    weight_matrix(~roi_grid_mask) = 1e6; % Infinite cost blockout outside ROI
    
    % Build adjacency graph
    [nrows, ncols] = size(grid_slice_filtered);
    [C, R] = meshgrid(1:ncols, 1:nrows);
    node_idx = (1:(nrows*ncols))';
    
    dr = [-1, 1, 0, 0, -1, -1, 1, 1];
    dc = [0, 0, -1, 1, -1, 1, -1, 1];
    
    source_nodes = [];
    target_nodes = [];
    edge_weights = [];
    
    for k = 1:8
        neighbor_R = R + dr(k);
        neighbor_C = C + dc(k);
        
        valid_mask = (neighbor_R >= 1) & (neighbor_R <= nrows) & (neighbor_C >= 1) & (neighbor_C <= ncols);
        
        curr_indices = node_idx(valid_mask);
        neigh_indices = sub2ind([nrows, ncols], neighbor_R(valid_mask), neighbor_C(valid_mask));
        
        costs = (weight_matrix(curr_indices) + weight_matrix(neigh_indices)) / 2;
        if k > 4
            costs = costs * sqrt(2); 
        end
        
        source_nodes = [source_nodes; curr_indices];
        target_nodes = [target_nodes; neigh_indices];
        edge_weights = [edge_weights; costs];
    end
    
    G = digraph(source_nodes, target_nodes, edge_weights);
    start_node = sub2ind([nrows, ncols], start_row, start_col);
    end_node = sub2ind([nrows, ncols], end_row, end_col);
    
    path_nodes = shortestpath(G, start_node, end_node);
    
    if ~isempty(path_nodes)
        [path_rows, path_cols] = ind2sub([nrows, ncols], path_nodes);
        plot_x_coords = XQ(sub2ind(size(XQ), path_rows, path_cols));
        plot_y_coords = YQ(sub2ind(size(YQ), path_rows, path_cols));
    else
        plot_x_coords = NaN;
        plot_y_coords = NaN;
    end
    
    % --- LIVE RENDER VIEW UPDATE STAGE ---
    if ~ishandle(fig), break; end
    
    set(h_img, 'CData', grid_slice_filtered); 
    set(h_active_edges, 'XData', plot_y_coords, 'YData', plot_x_coords);
    
    set(h_title, 'String', sprintf('Frame %02d/%02d | Time Stamp: %s', ...
        f, num_frames, datestr(exported_time_axis(f), 'HH:MM:SS')));
    drawnow;
    
    writeVideo(v_writer, getframe(fig));
end

close(v_writer);
fprintf('Video export complete.\n');

% =========================================================================
% ANISOTROPIC DIFFUSION SMOOTHING FILTER HELPER
% =========================================================================
function diff_im = anisodiff(im, num_iter, delta_t, kappa)
    im = double(im);
    diff_im = im;
    for i = 1:num_iter
        deltaN = zeros(size(diff_im)); deltaS = zeros(size(diff_im));
        deltaE = zeros(size(diff_im)); deltaW = zeros(size(diff_im));
        deltaN(1:end-1,:) = diff_im(2:end,:) - diff_im(1:end-1,:);
        deltaS(2:end,:)   = diff_im(1:end-1,:) - diff_im(2:end,:);
        deltaE(:,1:end-1) = diff_im(:,2:end) - diff_im(:,1:end-1);
        deltaW(:,2:end)   = diff_im(:,1:end-1) - diff_im(:,2:end);
        cN = exp(-(deltaN/kappa).^2); cS = exp(-(deltaS/kappa).^2);
        cE = exp(-(deltaE/kappa).^2); cW = exp(-(deltaW/kappa).^2);
        diff_im = diff_im + delta_t * (cN.*deltaN + cS.*deltaS + cE.*deltaE + cW.*deltaW);
    end
end