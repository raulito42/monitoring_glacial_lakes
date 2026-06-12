function P02_water_tracking_unified(config)
    % P02_WATER_TRACKING_UNIFIED Unified dual-engine radar tracking pipeline.
    % Simultaneously processes Nominal and Detrended streams using environment-specific settings.
    
    % --- AUTOMATED UTILS PATH REGISTRATION ---
    script_dir = fileparts(mfilename('fullpath')); 
    utils_dir = fullfile(script_dir, 'utils');
    if exist(utils_dir, 'dir'), addpath(utils_dir); end
    project_root = config.project_root;
    name2proj = config.name2proj;
    export_dir = config.export_dir;
    
    % --- CONFIGURATION SETTINGS ---
    enable_video = true;
    temporal_window = 5;
    path_tuned_features = fullfile(export_dir, 'tuned_features.mat');
    path_land_mask      = fullfile(export_dir, 'land_mask.mat');
    tuned_features = load(path_tuned_features); 
    land_mask = load(path_land_mask);
    binary_land_mask = land_mask.weighted_kmeans_land_mask;
    dbscan_min_pts = 6;   
    
    % --- INGEST MULTI-ENVIRONMENT THRESHOLDS FROM CONFIG ---
    thresh_nom = config.thresh_nom;
    thresh_det = config.thresh_det;
    climits_nom = [0 1];
    climits_det = [-3 3];
    
    % --- PREPARE SENSITIVITY ANALYSIS EXPORT DIRECTORY ---
    sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis');
    if ~exist(sensitivity_export_dir, 'dir'), mkdir(sensitivity_export_dir); end
    
    % =========================================================================
    % 2. INTERACTIVE REGION OF INTEREST (ROI) SELECTION VIA LAND MASK
    % =========================================================================
    XQ = tuned_features.XQ; YQ = tuned_features.YQ;
    comp_fig = figure('Name', 'ROI Selection', 'Units', 'normalized', 'OuterPosition', [0.1 0.1 0.6 0.7], 'Color', 'w');
    x_axis = tuned_features.x_axis; y_axis = tuned_features.y_axis;
    scatter(y_axis, x_axis, 8, double(binary_land_mask), 'filled');
    colormap(gca, [0.1 0.2 0.4; 0.9 0.65 0.15]); 
    axis equal; grid on; hold on;
    roi_tool = drawpolygon(gca, 'Color', 'r', 'LineWidth', 2.0);
    
    if isempty(roi_tool.Position)
        roi_spatial_mask_2d = true(size(XQ));
    else
        roi_spatial_mask_2d = inpolygon(YQ, XQ, roi_tool.Position(:,1), roi_tool.Position(:,2));
    end
    close(comp_fig);
    
    % =========================================================================
    % 3. GEOMETRIC SHORELINE RIBBON BUFFER CONFIGURATION
    % =========================================================================
    grid_land_mask = griddata(x_axis, y_axis, double(binary_land_mask), XQ, YQ, 'nearest');
    grid_land_mask(isnan(grid_land_mask)) = 0;
    
    try 
        se1 = strel('disk', config.se1_radius); 
        se4 = strel('disk', config.se4_radius); 
    catch 
        se1 = stencil('disk', config.se1_radius);
        se4 = stencil('disk', config.se4_radius); 
    end
    
    shoreline_perimeter_grid = grid_land_mask - imerode(grid_land_mask, se1);
    shoreline_ribbon_grid = imdilate(shoreline_perimeter_grid, se4);
    grid_ribbon = (shoreline_ribbon_grid > 0.5) & roi_spatial_mask_2d;
    narrow_tracking_zone_2d = grid_ribbon;
    
    save(path_land_mask, 'narrow_tracking_zone_2d', 'roi_spatial_mask_2d', '-append');
    
    % =========================================================================
    % 4. DUAL-ENGINE WORKSPACE CONCURRENCY 
    % =========================================================================
    num_frames = size(tuned_features.exported_coherence, 2);
    grid_pixel_area_m2 = abs(XQ(1,2) - XQ(1,1)) * abs(YQ(2,1) - YQ(1,1));
    ribbon_linear_grid_idx = find(grid_ribbon == 1);
    weights = [2.0, 0.5, 0.5]; 
    
    masks_nom_fixed = false([size(XQ), num_frames]);
    masks_nom_adapt = false([size(XQ), num_frames]);
    masks_det_fixed = false([size(XQ), num_frames]);
    masks_det_adapt = false([size(XQ), num_frames]);
    
    adaptive_threshold_history_nom = nan(num_frames, 1);
    adaptive_threshold_history_det = nan(num_frames, 1);
    
    % --- RUN TIME-SERIES CORRECTIONS LOOP ---
    for f = 1:num_frames
        s_idx = max(1, f - floor(temporal_window/2));
        e_idx = min(num_frames, f + floor(temporal_window/2));
        
        % ---------------------------------------------------------------------
        % ENGINE BRANCH A: NOMINAL STREAM PROCESSING
        % ---------------------------------------------------------------------
        f_coh_nom  = mean(tuned_features.exported_coherence(:, s_idx:e_idx), 2);
        f_amp_nom  = mean(tuned_features.exported_amplitude(:, s_idx:e_idx), 2);
        f_pvar_nom = mean(tuned_features.exported_phase_var(:, s_idx:e_idx), 2);
        
        g_coh_nom = griddata(x_axis, y_axis, double(f_coh_nom), XQ, YQ, 'linear'); g_coh_nom(isnan(g_coh_nom)) = 0;
        g_amp_nom = griddata(x_axis, y_axis, double(f_amp_nom), XQ, YQ, 'linear'); g_amp_nom(isnan(g_amp_nom)) = 0;
        g_pvar_nom = griddata(x_axis, y_axis, double(f_pvar_nom), XQ, YQ, 'linear'); g_pvar_nom(isnan(g_pvar_nom)) = 0;
        
        m_nf = apply_dbscan_filter(grid_ribbon & (g_coh_nom < thresh_nom(1)), XQ, YQ, dbscan_min_pts);
        masks_nom_fixed(:,:,f) = m_nf;
        
        rib_coh_nom  = double(g_coh_nom(ribbon_linear_grid_idx));
        rib_amp_nom  = 20 * log10(abs(double(g_amp_nom(ribbon_linear_grid_idx))) + eps);
        rib_pvar_nom = double(g_pvar_nom(ribbon_linear_grid_idx));
        
        if ~isempty(rib_coh_nom) && length(rib_coh_nom) >= 3
            F_w = zscore(real([rib_coh_nom, rib_amp_nom, rib_pvar_nom])) .* weights;
            [c_idx, ~] = kmeans(F_w, 3, 'Distance', 'sqeuclidean', 'Replicates', 3, 'Options', statset('MaxIter', 150));
            c_means = zeros(3, 1); for k = 1:3, c_means(k) = mean(rib_coh_nom(c_idx == k)); end
            [sorted_means, sort_order] = sort(c_means, 'ascend');
            
            adaptive_threshold_history_nom(f) = max(0.1, min(0.9, sorted_means(1)));
            
            raw_grid_km = false(size(XQ)); raw_grid_km(ribbon_linear_grid_idx(c_idx == sort_order(1))) = true;
            masks_nom_adapt(:,:,f) = apply_dbscan_filter(raw_grid_km, XQ, YQ, dbscan_min_pts);
        end
        
        % ---------------------------------------------------------------------
        % ENGINE BRANCH B: DETRENDED STREAM PROCESSING
        % ---------------------------------------------------------------------
        f_coh_det  = mean(tuned_features.exported_detrended_coh(:, s_idx:e_idx), 2);
        f_amp_det  = mean(tuned_features.exported_detrended_amp(:, s_idx:e_idx), 2);
        f_pvar_det = mean(tuned_features.exported_detrended_pvar(:, s_idx:e_idx), 2);
        
        g_coh_det = griddata(x_axis, y_axis, double(f_coh_det), XQ, YQ, 'linear'); g_coh_det(isnan(g_coh_det)) = 0;
        g_amp_det = griddata(x_axis, y_axis, double(f_amp_det), XQ, YQ, 'linear'); g_amp_det(isnan(g_amp_det)) = 0;
        g_pvar_det = griddata(x_axis, y_axis, double(f_pvar_det), XQ, YQ, 'linear'); g_pvar_det(isnan(g_pvar_det)) = 0;
        
        m_df = apply_dbscan_filter(grid_ribbon & (g_coh_det < thresh_det(1)), XQ, YQ, dbscan_min_pts);
        masks_det_fixed(:,:,f) = m_df;
        
        rib_coh_det  = double(g_coh_det(ribbon_linear_grid_idx));
        rib_amp_det  = 20 * log10(abs(double(g_amp_det(ribbon_linear_grid_idx))) + eps);
        rib_pvar_det = double(g_pvar_det(ribbon_linear_grid_idx));
        
        if ~isempty(rib_coh_det) && length(rib_coh_det) >= 3
            F_w = zscore(real([rib_coh_det, rib_amp_det, rib_pvar_det])) .* weights;
            [c_idx, ~] = kmeans(F_w, 3, 'Distance', 'sqeuclidean', 'Replicates', 3, 'Options', statset('MaxIter', 150));
            c_means = zeros(3, 1); for k = 1:3, c_means(k) = mean(rib_coh_det(c_idx == k)); end
            [sorted_means, sort_order] = sort(c_means, 'ascend');
            
            adaptive_threshold_history_det(f) = max(-1, min(1, sorted_means(1)));
            
            raw_grid_km = false(size(XQ)); raw_grid_km(ribbon_linear_grid_idx(c_idx == sort_order(1))) = true;
            masks_det_adapt(:,:,f) = apply_dbscan_filter(raw_grid_km, XQ, YQ, dbscan_min_pts);
        end
    end
    
    % =========================================================================
    % 5. COMPARATIVE FOUR-QUADRANT GRAPHICS VIDEO EXPORT ENGINE
    % =========================================================================  
    if enable_video
        video_filename = fullfile(export_dir, 'complete_dual_engine_tracking_dashboard.mp4');
        fprintf('Building Unified Quad-Grid Tracking Frame Array: %s...\n', video_filename);
        
        v_writer = VideoWriter(video_filename, 'MPEG-4');
        v_writer.FrameRate = 2.5;  
        v_writer.Quality = 95;   
        open(v_writer);  
        
        % Establish figure and fix properties to prevent UI context size stretching
        fig_video = figure('Name', 'Unified Dual-Engine Workspace Dashboard', ...
                           'Units', 'pixels', 'Position', [50, 50, 1200, 800], ...
                           'Color', 'w', 'Visible', 'on');
                       
        x_limit = [min(x_axis), max(x_axis)];
        y_limit = [min(y_axis), max(y_axis)];
        
        % Explicitly cache expected static dimension bounds on first draw allocation
        target_height = [];
        target_width = [];
        
        for f = 1:num_frames
            % Clear child objects without completely tearing down background handles
            clf(fig_video);
            
            % TOP-LEFT: NOMINAL FIXED
            subplot(2,2,1);
            plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, tuned_features.exported_coherence(:,f), y_limit, x_limit, 'scatter');
            colormap(gca, parula); clim(climits_nom); hold on;
            m = masks_nom_fixed(:,:,f); m_x = YQ; m_y = XQ; m_x(~m) = NaN; m_y(~m) = NaN;
            h = scatter(m_x(:), m_y(:), 8, 'k', 'filled'); if ~isempty(h), set(h, 'MarkerEdgeAlpha',0.4,'MarkerFaceAlpha',0.4); end
            title(sprintf('Nominal Fixed (\\gamma = %.2f) — Frame %d', thresh_nom(1), f), 'FontSize', 10, 'FontWeight', 'bold');
            grid on; box on;
            
            % TOP-RIGHT: NOMINAL ADAPTIVE
            subplot(2,2,2);
            plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, tuned_features.exported_coherence(:,f), y_limit, x_limit, 'scatter');
            colormap(gca, parula); clim(climits_nom); hold on;
            m = masks_nom_adapt(:,:,f); m_x = YQ; m_y = XQ; m_x(~m) = NaN; m_y(~m) = NaN;
            h = scatter(m_x(:), m_y(:), 8, 'k', 'filled'); if ~isempty(h), set(h, 'MarkerEdgeAlpha',0.4,'MarkerFaceAlpha',0.4); end
            title(sprintf('Nominal Adaptive (\\gamma_{ad} = %.2f) — Frame %d', adaptive_threshold_history_nom(f), f), 'FontSize', 10, 'FontWeight', 'bold');
            grid on; box on;
            
            % BOTTOM-LEFT: DETRENDED FIXED
            subplot(2,2,3);
            plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, tuned_features.exported_detrended_coh(:,f), y_limit, x_limit, 'scatter');
            colormap(gca, parula); clim(climits_det); hold on;
            m = masks_det_fixed(:,:,f); m_x = YQ; m_y = XQ; m_x(~m) = NaN; m_y(~m) = NaN;
            h = scatter(m_x(:), m_y(:), 8, 'k', 'filled'); if ~isempty(h), set(h, 'MarkerEdgeAlpha',0.4,'MarkerFaceAlpha',0.4); end
            title(sprintf('Detrended Fixed (\\gamma = %.2f) — Frame %d', thresh_det(1), f), 'FontSize', 10, 'FontWeight', 'bold');
            grid on; box on;
            
            % BOTTOM-RIGHT: DETRENDED ADAPTIVE
            subplot(2,2,4);
            plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, tuned_features.exported_detrended_coh(:,f), y_limit, x_limit, 'scatter');
            colormap(gca, parula); clim(climits_det); hold on;
            m = masks_det_adapt(:,:,f); m_x = YQ; m_y = XQ; m_x(~m) = NaN; m_y(~m) = NaN;
            h = scatter(m_x(:), m_y(:), 8, 'k', 'filled'); if ~isempty(h), set(h, 'MarkerEdgeAlpha',0.4,'MarkerFaceAlpha',0.4); end
            title(sprintf('Detrended Adaptive (\\gamma_{ad} = %.2f) — Frame %d', adaptive_threshold_history_det(f), f), 'FontSize', 10, 'FontWeight', 'bold');
            grid on; box on;
            
            drawnow;
            video_frame = getframe(fig_video);
            
            % Capture dimensions on first iteration
            if isempty(target_height)
                target_height = size(video_frame.cdata, 1);
                target_width  = size(video_frame.cdata, 2);
            else
                % Cleanly handle pixel shifts to keep shapes uniform
                if size(video_frame.cdata, 1) ~= target_height || size(video_frame.cdata, 2) ~= target_width
                    video_frame.cdata = imresize(video_frame.cdata, [target_height, target_width]);
                end
            end
            
            writeVideo(v_writer, video_frame);
            pause(0.05);
        end
        close(v_writer);
        close(fig_video);
    end

    % =========================================================================
    % 6. PERSISTENT ADAPTIVE THRESHOLD TREND PLOTTING ENGINE
    % =========================================================================
    fprintf('Generating Threshold Evolution Curves for Project: %s...\n', name2proj);
    fig_trends = figure('Name', 'Adaptive Cutoff Evolutions', 'Units', 'pixels', 'Position', [100, 100, 1000, 700], 'Color', 'w');
    frames_axis = 1:num_frames;
    
    % Ingest the environment-specific visual boundaries directly from the main batch configuration
    plot_clim_nom = config.clim_nom;
    plot_clim_det = config.clim_det;
    
    % -------------------------------------------------------------------------
    % Top Panel: Nominal Adaptive History Tracking
    % -------------------------------------------------------------------------
    subplot(2,1,1);
    hold on;
    h_nom_line = plot(frames_axis, adaptive_threshold_history_nom, 'b-', 'LineWidth', 2.5);
    h_nom_base = yline(thresh_nom(1), 'k--', 'LineWidth', 1.5);
    
    if length(thresh_nom) >= 3
        fill([frames_axis, fliplr(frames_axis)], ...
             [repelem(thresh_nom(2), num_frames), repelem(thresh_nom(3), num_frames)], ...
             [0.7 0.8 1], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
    end
    grid on; box on;
    ylim(plot_clim_nom); % Scaled dynamically from config.clim_nom
    
    % Enforce a clean white axes workspace with high-contrast pure black grids, borders, and ticks
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top'); 
    
    % Native cell array handles multi-line titles robustly without raw \newline string issues
    title({'Nominal Workspace Adaptive Coherence Threshold Evolution (\gamma_{ad})', ...
           sprintf('Dataset: %s', name2proj)}, 'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold');
    
    xlabel('Temporal Frame Sequence', 'Color', 'k'); 
    ylabel('Coherence Filter Boundary', 'Color', 'k');
    
    legend([h_nom_line, h_nom_base], ...
           {'Adaptive Clustering Boundary (\gamma_{ad})', 'Configured Fixed Base (\gamma_{nom})'}, ...
           'Location', 'best', 'TextColor', 'k', 'Color', 'w');
    
    % -------------------------------------------------------------------------
    % Bottom Panel: Detrended Residual Adaptive History Tracking
    % -------------------------------------------------------------------------
    subplot(2,1,2);
    hold on;
    h_det_line = plot(frames_axis, adaptive_threshold_history_det, 'r-', 'LineWidth', 2.5);
    h_det_base = yline(thresh_det(1), 'k--', 'LineWidth', 1.5);
    
    if length(thresh_det) >= 3
        fill([frames_axis, fliplr(frames_axis)], ...
             [repelem(thresh_det(2), num_frames), repelem(thresh_det(3), num_frames)], ...
             [1 0.7 0.7], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
    end
    grid on; box on;
    ylim(plot_clim_det); % Scaled dynamically from config.clim_det
    
    % Enforce a clean white axes workspace with high-contrast pure black grids, borders, and ticks
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top'); 
    
    title('Detrended Workspace Adaptive Residual Threshold Evolution (\gamma_{ad})', ...
          'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold');
      
    xlabel('Temporal Frame Sequence', 'Color', 'k'); 
    ylabel('Residual Feature Metric Value', 'Color', 'k');
    
    legend([h_det_line, h_det_base], ...
           {'Adaptive Clustering Boundary (\gamma_{ad})', 'Configured Fixed Base (\gamma_{det})'}, ...
           'Location', 'best', 'TextColor', 'k', 'Color', 'w');
    
    % Export graphics object to sensitivity package
    trend_filename = fullfile(sensitivity_export_dir, 'adaptive_threshold_evolution_trends.png');
    saveas(fig_trends, trend_filename);
    close(fig_trends);
    fprintf('✔ Threshold trends evaluation charts exported to: %s\n', trend_filename);

    % Export processed engine masks and metrics for spatial dynamics tracking
    path_tracking_results = fullfile(export_dir, 'tracking_results.mat');
    save(path_tracking_results, 'masks_nom_fixed', 'masks_nom_adapt', ...
                                'masks_det_fixed', 'masks_det_adapt', ...
                                'grid_pixel_area_m2', 'num_frames', ...
                                'adaptive_threshold_history_nom', 'adaptive_threshold_history_det', ...
                                'thresh_nom', 'thresh_det', 'plot_clim_nom', 'plot_clim_det');
    fprintf('✔ Tracking masks and area data exported to: %s\n', path_tracking_results);
end 