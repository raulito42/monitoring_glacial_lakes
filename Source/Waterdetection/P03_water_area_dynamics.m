function P03_water_area_dynamics(config)
    % P03_WATER_AREA_DYNAMICS Evaluates and visualizes water surface area trends.
    % Computes net percentage fluctuations and maps dual-stream water shoreline
    % transition dynamics for both Nominal and Detrended Adaptive workspaces with
    % unified shared axes, high-contrast black text, and white backgrounds.
    
    export_dir = config.export_dir;
    name2proj = config.name2proj;
    
    path_tracking_results = fullfile(export_dir, 'tracking_results.mat');
    if ~isfile(path_tracking_results)
        error('Data mismatch: Ensure you run updated P02 script to save tracking_results.mat first!');
    end
    
    % Ingest logical tracking masks and pixel spatial scale dimensions
    load(path_tracking_results, 'masks_nom_fixed', 'masks_nom_adapt', ...
                                'masks_det_fixed', 'masks_det_adapt', ...
                                'grid_pixel_area_m2', 'num_frames');
                            
    % --- 1. COMPUTE SCALAR ABSOLUTE SURFACE AREAS (m^2) ---
    area_nom_fixed = zeros(num_frames, 1);
    area_nom_adapt = zeros(num_frames, 1);
    area_det_fixed = zeros(num_frames, 1);
    area_det_adapt = zeros(num_frames, 1);
    
    for f = 1:num_frames
        area_nom_fixed(f) = sum(masks_nom_fixed(:,:,f), 'all') * grid_pixel_area_m2;
        area_nom_adapt(f) = sum(masks_nom_adapt(:,:,f), 'all') * grid_pixel_area_m2;
        area_det_fixed(f) = sum(masks_det_fixed(:,:,f), 'all') * grid_pixel_area_m2;
        area_det_adapt(f) = sum(masks_det_adapt(:,:,f), 'all') * grid_pixel_area_m2;
    end
    
    % Compute Net Percentage Variations relative to Baseline (Frame 1)
    pct_nom_fixed = ((area_nom_fixed - area_nom_fixed(1)) / (area_nom_fixed(1) + eps)) * 100;
    pct_nom_adapt = ((area_nom_adapt - area_nom_adapt(1)) / (area_nom_adapt(1) + eps)) * 100;
    pct_det_fixed = ((area_det_fixed - area_det_fixed(1)) / (area_det_fixed(1) + eps)) * 100;
    pct_det_adapt = ((area_det_adapt - area_det_adapt(1)) / (area_det_adapt(1) + eps)) * 100;
    
    % --- 2. CALCULATE DIRECTIONAL TRANSITIONS FOR BOTH ADAPTIVE TRACKERS ---
    W_exp_nom = zeros(num_frames, 1);
    W_ret_nom = zeros(num_frames, 1);
    W_exp_det = zeros(num_frames, 1);
    W_ret_det = zeros(num_frames, 1);
    
    for f = 2:num_frames
        % Nominal Stream Evaluation Step
        prev_mask_nom = masks_nom_adapt(:,:,f-1);
        curr_mask_nom = masks_nom_adapt(:,:,f);
        W_exp_nom(f) = sum(~prev_mask_nom & curr_mask_nom, 'all') * grid_pixel_area_m2;
        W_ret_nom(f) = sum(prev_mask_nom & ~curr_mask_nom, 'all') * grid_pixel_area_m2;
        
        % Detrended Stream Evaluation Step
        prev_mask_det = masks_det_adapt(:,:,f-1);
        curr_mask_det = masks_det_adapt(:,:,f);
        W_exp_det(f) = sum(~prev_mask_det & curr_mask_det, 'all') * grid_pixel_area_m2;
        W_ret_det(f) = sum(prev_mask_det & ~curr_mask_det, 'all') * grid_pixel_area_m2;
    end
    
    net_velocity_nom = W_exp_nom - W_ret_nom;
    net_velocity_det = W_exp_det - W_ret_det;
    
    % --- 3. DYNAMIC SHARED AXIS COMPUTE (COMPARE ON SAME SCALE) ---
    % Find global maximum and minimum across all bars and plots for the transition velocity graphs
    global_max_W = max([W_exp_nom; W_exp_det; net_velocity_nom; net_velocity_det; eps]);
    global_min_W = min([-W_ret_nom; -W_ret_det; net_velocity_nom; net_velocity_det; -eps]);
    
    % Apply a uniform 10% structural boundary padding for clear visuals
    padding_W = 0.10 * max(global_max_W, abs(global_min_W));
    shared_ylim_W = [global_min_W - padding_W, global_max_W + padding_W];
    
    % --- 4. GRAPHICS GENERATION ENGINE ---
    frames_axis = 1:num_frames;
    sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis');
    if ~exist(sensitivity_export_dir, 'dir'), mkdir(sensitivity_export_dir); end
    
    % -------------------------------------------------------------------------
    % Chart A: Comparative Net Percentage Trends across Pipeline Streams
    % -------------------------------------------------------------------------
    fig_net = figure('Name', 'Net Surface Area Variance', 'Units', 'pixels', 'Position', [150, 150, 950, 500], 'Color', 'w');
    hold on;
    plot(frames_axis, pct_nom_fixed, 'b--', 'LineWidth', 1.8);
    plot(frames_axis, pct_nom_adapt, 'b-', 'LineWidth', 2.6);
    plot(frames_axis, pct_det_fixed, 'r--', 'LineWidth', 1.8);
    plot(frames_axis, pct_det_adapt, 'r-', 'LineWidth', 2.6);
    yline(0, 'k:', 'LineWidth', 1.2);
    
    grid on; box on;
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
    
    title_text_net = {'Net Cumulative Water Surface Area Variance (Delta % Relative to Frame 1)', ...
                      sprintf('Dataset: %s', name2proj)};
    title(title_text_net, 'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
       
    xlabel('Temporal Frame Sequence', 'Color', 'k'); 
    ylabel('Area Deviation Percentage (Delta %)', 'Color', 'k');
    
    legend({'Nominal Fixed', 'Nominal Adaptive', 'Detrended Fixed', 'Detrended Adaptive'}, ...
           'Location', 'best', 'TextColor', 'k', 'Color', 'w');
    
    net_chart_path = fullfile(sensitivity_export_dir, 'water_net_area_percentage_trends.png');
    saveas(fig_net, net_chart_path);
    close(fig_net);
    
    % -------------------------------------------------------------------------
    % Chart B: Dual-Panel Water Transition Velocities (Shared Axis enforced)
    % -------------------------------------------------------------------------
    fig_W = figure('Name', 'Water Shoreline Transitions', 'Units', 'pixels', 'Position', [200, 50, 1000, 800], 'Color', 'w');
    
    % Panel B1: Nominal Workspace Adaptive Dynamics tracking
    subplot(2,1,1);
    hold on;
    b_exp_nom = bar(frames_axis, W_exp_nom, 'FaceColor', [0.15 0.62 0.35], 'EdgeColor', 'none', 'FaceAlpha', 0.75);
    b_ret_nom = bar(frames_axis, -W_ret_nom, 'FaceColor', [0.85 0.23 0.23], 'EdgeColor', 'none', 'FaceAlpha', 0.75);
    p_net_nom = plot(frames_axis, net_velocity_nom, 'k-o', 'LineWidth', 1.6, 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    yline(0, 'k-', 'LineWidth', 1.2);
    
    grid on; box on;
    ylim(shared_ylim_W); % <-- Enforces identical scale bound 
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
    
    title_text_nom = {'Nominal Workspace Shoreline Transition Volumes (Nominal Adaptive Engine)', ...
                      sprintf('Dataset: %s', name2proj)};
    title(title_text_nom, 'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
    ylabel('Active Surface Delta (m^2)', 'Color', 'k');
    
    legend([b_exp_nom, b_ret_nom, p_net_nom], ...
           {'Water Encroachment (Land -> Water)', ...
            'Water Shoreline Retreat (Water -> Land)', ...
            'Net Spatial Transition Velocity'}, ...
           'Location', 'best', 'TextColor', 'k', 'Color', 'w');
       
    % Panel B2: Detrended Workspace Adaptive Dynamics tracking
    subplot(2,1,2);
    hold on;
    b_exp_det = bar(frames_axis, W_exp_det, 'FaceColor', [0.12 0.53 0.70], 'EdgeColor', 'none', 'FaceAlpha', 0.75); 
    b_ret_det = bar(frames_axis, -W_ret_det, 'FaceColor', [0.88 0.40 0.15], 'EdgeColor', 'none', 'FaceAlpha', 0.75); 
    p_net_det = plot(frames_axis, net_velocity_det, 'k-s', 'LineWidth', 1.6, 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    yline(0, 'k-', 'LineWidth', 1.2);
    
    grid on; box on;
    ylim(shared_ylim_W); % <-- Enforces identical scale bound
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
    
    title('Detrended Workspace Shoreline Transition Volumes (Detrended Adaptive Engine)', ...
          'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
    xlabel('Temporal Frame Sequence', 'Color', 'k'); 
    ylabel('Active Surface Delta (m^2)', 'Color', 'k');
    
    legend([b_exp_det, b_ret_det, p_net_det], ...
           {'Water Encroachment (Land -> Water)', ...
            'Water Shoreline Retreat (Water -> Land)', ...
            'Net Spatial Transition Velocity'}, ...
           'Location', 'best', 'TextColor', 'k', 'Color', 'w');
                               
    W_chart_path = fullfile(sensitivity_export_dir, 'water_water_transition_dynamics.png');
    saveas(fig_W, W_chart_path);
    close(fig_W);
    
    % --- 5. DATA LOG EXPORT ENGINE ---
    csv_filename = fullfile(export_dir, 'water_surface_area_metrics.csv');
    Metrics_Table = table(frames_axis', area_nom_fixed, pct_nom_fixed, area_nom_adapt, pct_nom_adapt, ...
                          area_det_fixed, pct_det_fixed, area_det_adapt, pct_det_adapt, ...
                          W_exp_nom, W_ret_nom, net_velocity_nom, ...
                          W_exp_det, W_ret_det, net_velocity_det, ...
                          'VariableNames', {'Frame', 'Area_NomFixed_m2', 'PctChange_NomFixed', ...
                                            'Area_NomAdapt_m2', 'PctChange_NomAdapt', ...
                                            'Area_DetFixed_m2', 'PctChange_DetFixed', ...
                                            'Area_DetAdapt_m2', 'PctChange_DetAdapt', ...
                                            'Nom_W_Expansion_m2', 'Nom_W_Retreat_m2', 'Nom_Net_Shift_m2', ...
                                            'Det_W_Expansion_m2', 'Det_W_Retreat_m2', 'Det_Net_Shift_m2'});
    writetable(Metrics_Table, csv_filename);
    
    fprintf('✔ Surface trends plots generated under sensitivity collection.\n');
    fprintf('✔ Complete structural dataset exported to: %s\n', csv_filename);
end