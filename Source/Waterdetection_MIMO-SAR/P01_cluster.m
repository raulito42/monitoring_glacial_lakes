function P01_cluster(config)
    
    project_root = config.project_root;
    name2proj = config.name2proj;
    export_dir = config.export_dir;

    enable_video = false;
    path_tuned_features = fullfile(export_dir, 'tuned_features.mat');
    fprintf('Loading preprocessed dataframe...\n');
    load(path_tuned_features); 
    % =========================================================================
    % 2. TEMPORAL FEATURE ENGINEERING 
    % =========================================================================
    fprintf('Collapsing time-series into robust statistical baselines...\n');
%{
    if config.mode == "detrended"
        feat_mean_coh = mean(exported_detrended_coh, 2);
        feat_mean_amp = mean(exported_detrended_amp, 2);
        feat_mean_pvar = mean(exported_detrended_pvar, 2);
    else 
        feat_mean_coh  = mean(exported_coherence, 2);
        feat_mean_amp  = mean(exported_amplitude, 2);
        feat_mean_pvar = mean(exported_phase_var, 2);
    end
%}
    feat_mean_coh = mean(exported_detrended_coh, 2);
    feat_mean_amp = mean(exported_detrended_amp, 2);
    feat_mean_pvar = mean(exported_detrended_pvar, 2);

    Feature_Matrix = [feat_mean_coh, feat_mean_amp, feat_mean_pvar];
    
    % =========================================================================
    % 3. STANDARDIZATION & CUSTOM WEIGHTING
    % =========================================================================
    F_normalized = zscore(Feature_Matrix);
    w_coherence = 2.0;  % High weight to prioritize coherence patterns
    w_amplitude = 1.0;  
    w_phase_var = 1.2;  
    weights = [w_coherence, w_amplitude, w_phase_var];
    F_weighted = F_normalized .* weights;
    
    % =========================================================================
    % 4. EXECUTE 3-CLUSTER K-MEANS
    % =========================================================================
    num_clusters = 3;
    fprintf('Executing Weighted K-means clustering (K = %d)...\n', num_clusters);
    [cluster_idx, centroids] = kmeans(F_weighted, num_clusters, ...
        'Distance', 'sqeuclidean', ...
        'Replicates', 10, ... 
        'Options', statset('Display', 'final'));
    
    % =========================================================================
    % 5. AUTOMATED IDENTIFICATION OF THE NOISY LAND CLUSTER
    % =========================================================================
    cluster_mean_coherence = zeros(num_clusters, 1);
    for k = 1:num_clusters
        cluster_mean_coherence(k) = mean(feat_mean_coh(cluster_idx == k));
    end
    [~, land_cluster_id] = max(cluster_mean_coherence);
    [~, water_cluster_id] = min(cluster_mean_coherence);
    raw_kmeans_land_mask = (cluster_idx == land_cluster_id);
    raw_water_mask = (cluster_idx == water_cluster_id);
    water_coh_values = feat_mean_coh(raw_water_mask);
    mean_water_coh = mean(water_coh_values);
    disp(mean_water_coh);
    
    % =========================================================================
    % 6. REFINED POST-PROCESSING: BOUNDARY-SAFE CONTINUOUS SHORELINE ENGINE
    % =========================================================================
    fprintf('Applying boundary-safe gap-bridging morphology to create a continuous shoreline...\n');
    grid_mask = griddata(x_axis, y_axis, double(raw_kmeans_land_mask), XQ, YQ, 'nearest');
    
    try
        se_close = strel('disk', config.radius_close);
        se_open  = strel('disk', config.radius_open);
    catch
        se_close = stencil('disk', config.radius_close); 
        se_open  = stencil('disk', config.radius_open); 
    end
    
    smooth_grid_mask = imclose(grid_mask, se_close);
    smooth_grid_mask = imopen(smooth_grid_mask, se_open);
    
    min_island_pixel_area = 10; 
    clean_grid_mask = bwareaopen(smooth_grid_mask, min_island_pixel_area);
    
    weighted_kmeans_land_mask = interp2(XQ, YQ, double(clean_grid_mask), x_axis, y_axis, 'nearest') > 0.5;
    fprintf('--> Optimization complete. Boundary-safe cleaned land points: %d\n', sum(weighted_kmeans_land_mask));
    
    % =========================================================================
    % 7. MULTI-CLASS VISUALIZATION & DIAGNOSTICS
    % =========================================================================
    figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 1100, 500], ...
           'Name', 'Morphologically Refined K-means Segmentation');
    custom_xlimit = [min(y_axis), max(y_axis)]; 
    custom_ylimit = [min(x_axis), max(x_axis)]; 
    
    subplot(1,2,1);
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(raw_kmeans_land_mask), custom_xlimit, custom_ylimit, 'scatter');
    colormap(gca, [0.1 0.2 0.4; 0.6 0.45 0.25]); 
    colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Water / Shifting', 'Raw Land (With Speckles)'});
    title('A. Initial K-means Land Output', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    subplot(1,2,2);
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, double(weighted_kmeans_land_mask), custom_xlimit, custom_ylimit, 'scatter');
    colormap(gca, [0.1 0.2 0.4; 0.6 0.45 0.25]); 
    colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Water / Shifting', 'Cleaned Stable Land'});
    title('B. Post-Processed Refined Land Mask', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    close(gcf); 
    fprintf('=== Static Mask Processing Complete! ===\n');
    
    % =========================================================================
    % 8. PERSISTENT SAVE (SEPARATE DATA PACKAGING ARTIFACT)
    % =========================================================================
    path_land_mask = fullfile(export_dir, 'land_mask.mat');
    fprintf('Saving final clean mask to target file: %s ...\n', path_land_mask);
    save(path_land_mask, 'raw_kmeans_land_mask', 'weighted_kmeans_land_mask');
    fprintf('=== Static Mask Processing Complete! ===\n');
    
    if enable_video
        % =========================================================================
        % 9. ROUTED VIDEO WRITER ENGINE INIT
        % =========================================================================
        video_filename = fullfile(export_dir, 'cluster_validation_timelapse.mp4');
        fprintf('Initializing Video Writer Engine: %s...\n', video_filename);
        
        v_writer = VideoWriter(video_filename, 'MPEG-4');
        v_writer.FrameRate = 2.5;  
        v_writer.Quality = 95;   
        open(v_writer);          
        
        % Set up the figure dashboard with explicit sizing dimensions
        fig_video = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 900, 750], ...
                           'Name', 'Chronological Validation Loop Export Utility');
        
        num_frames = size(exported_coherence, 2); 
        
        % Isolate land coordinates for the static validation mask layer
        mask_x = y_axis;
        mask_y = x_axis;
        mask_x(~weighted_kmeans_land_mask) = NaN;
        mask_y(~weighted_kmeans_land_mask) = NaN;
        
        
        % =========================================================================
        % 10. CHRONOLOGICAL VIDEO ENCODING LOOP
        % =========================================================================
        fprintf('Running time-series streaming generation map loop...\n');
        
        for f = 1:num_frames
            % Clean axis handle window
            clf(fig_video);
            
            % --- LAYER 1: Coherence Underlay Field ---
            instantaneous_coh = exported_coherence(:, f);
            h_coherence = scatter(y_axis, x_axis, 8, instantaneous_coh, 'filled');
            hold on;
            
            colormap(gca, jet); 
            h_cb = colorbar; 
            h_cb.Label.String = sprintf('Frame %d/%d Local Coherence Value', f, num_frames);
            clim([0 1]); 
            
            % --- LAYER 2: Semi-Transparent Verification Mask ---
            h_mask = scatter(mask_x, mask_y, 14, [1 0 1], 'filled');
            set(h_mask, 'MarkerEdgeAlpha', 0.4, 'MarkerFaceAlpha', 0.2);
            
            % --- LAYER 3: Handle Layer Sorting ---
            uistack(h_mask, 'top');
            uistack(h_coherence, 'bottom');
            
            % Labeling metrics
            title(sprintf('K-Means Mask Validation Loop (Frame %02d / %d)', f, num_frames), ...
                  'FontSize', 13, 'FontWeight', 'bold');
            subtitle('Alpha Blend Tint (Magenta) = Optimized Land Casing Layer Matrix', 'FontSize', 10);
            xlabel('Azimuth / Spatial Coordinate Y');
            ylabel('Range / Spatial Coordinate X');
            
            axis equal; grid on; box on;
            xlim(custom_xlimit); ylim(custom_ylimit);
            
            % Force render engine flush
            drawnow;
            
            % Capture active plot viewport buffer array directly to stream
            current_frame = getframe(fig_video);         
            writeVideo(v_writer, current_frame);   
            
            pause(0.1); % Fast loop buffer cycle 
        end
        
        % Close out and dump the video file stream to disk
        close(v_writer); 
        fprintf('=== Video stream export complete! Target: %s ===\n', video_filename);
    end
end