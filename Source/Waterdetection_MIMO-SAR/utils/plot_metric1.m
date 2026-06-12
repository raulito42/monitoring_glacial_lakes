function plot_metric1(curves_fixed, curves_kmeans, num_frames, export_dir, showfigs, name2proj)
    vis_setting = 'on'; if ~showfigs, vis_setting = 'off'; end
    
    % -------------------------------------------------------------------------
    % FIX 1: PREVENT Y-AXIS SINGULARITY COLLAPSE
    % -------------------------------------------------------------------------
    all_tracking_values = [curves_fixed(:); curves_kmeans(:)];
    data_range = max(all_tracking_values) - min(all_tracking_values);
    
    % If data is flat or all zeros, force a baseline fallback span to prevent rendering failure
    if data_range < 1e-4
        data_range = 1.0; 
    end
    padding = 0.1 * data_range;
    unified_y_limits = [min(all_tracking_values) - padding, max(all_tracking_values) + padding];
    
    % -------------------------------------------------------------------------
    % FIX 2: DEFINE RENDERING ENGINE AT CONSTRUCTION TIME
    % -------------------------------------------------------------------------
    if ~showfigs
        renderer_setting = 'painters'; % Force software vector math from the first pixel
    else
        renderer_setting = 'opengl';   % Standard hardware rendering for interactive use
    end
    
    % Force the figure background window to be completely white and assign renderer immediately
    fig1 = figure('Name', 'Metric 1 - Comparative Model Robustness Sweep', ...
                  'Units', 'normalized', 'OuterPosition', [0.1 0.1 0.8 0.5], ...
                  'Color', 'w', 'Visible', vis_setting, 'Renderer', renderer_setting);
              
    c_low  = [0.20, 0.60, 0.90]; c_nom = [1.00, 0.50, 0.00]; c_high = [0.75, 0.10, 0.10];  
    
    % --- Left Subplot ---
    subplot(1,2,1);
    plot(1:num_frames, curves_fixed(:,1), '-', 'LineWidth', 1.8, 'Color', c_low); hold on;
    plot(1:num_frames, curves_fixed(:,2), '-', 'LineWidth', 2.2, 'Color', c_nom);
    plot(1:num_frames, curves_fixed(:,3), '-', 'LineWidth', 1.8, 'Color', c_high);
    grid on; box on; ylim(unified_y_limits);
    
    % Enforce absolute white/black scaling for axes, labels, and ticks
    set(gca, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    title('A. Fixed Threshold Sensitivity to Cutoffs (\gamma)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0]);
    xlabel('Sequential Chronological Frames', 'Color', [0 0 0]); 
    ylabel('Area Displacement Delta (m^2)', 'Color', [0 0 0]);
    
    lgd1 = legend('\gamma = 0.30', '\gamma = 0.35 (Baseline)', '\gamma = 0.40', 'Location', 'best');
    set(lgd1, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);
    
    % --- Right Subplot ---
    subplot(1,2,2);
    plot(1:num_frames, curves_kmeans(:,1), '-', 'LineWidth', 1.8, 'Color', c_low); hold on;
    plot(1:num_frames, curves_kmeans(:,2), '-', 'LineWidth', 2.2, 'Color', c_nom);
    plot(1:num_frames, curves_kmeans(:,3), '-', 'LineWidth', 1.8, 'Color', c_high);
    grid on; box on; ylim(unified_y_limits);
    
    % Enforce absolute white/black scaling here as well
    set(gca, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    title('B. Adaptive K-means Sensitivity to Smoothing Windows (W)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0]);
    xlabel('Sequential Chronological Frames', 'Color', [0 0 0]); 
    ylabel('Area Displacement Delta (m^2)', 'Color', [0 0 0]);
    
    lgd2 = legend('W = 1 Frame', 'W = 5 Frames (Baseline)', 'W = 9 Frames', 'Location', 'best');
    set(lgd2, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);
    
    % --- Global Super Title (Project File Name) ---
    clean_title = strrep(name2proj, '_', '\_'); % Escape underscores for clean rendering
    sgtitle(clean_title, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0], 'Interpreter', 'tex');
    
    % Export using standard modern function syntax
    exportgraphics(fig1, fullfile(export_dir, 'metric_1_robustness_sweeps.png'), ...
                   'Resolution', 300, 'BackgroundColor', 'w');
               
    if ~showfigs, close(fig1); end
end