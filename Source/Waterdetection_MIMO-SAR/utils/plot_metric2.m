function plot_metric2(nominal_fixed, trend_fixed, noise_fixed, snr_fixed, ...
                      nominal_km, trend_km, noise_kmeans, snr_kmeans, ...
                      num_frames, export_dir, showfigs, name2proj)
    vis_setting = 'on'; if ~showfigs, vis_setting = 'off'; end
    
    % --- AXIS LIMITS SYNCHRONIZATION ---
    all_tracking = [nominal_fixed(:); nominal_km(:)];
    unified_y_limits = [min(all_tracking) - 0.1*range(all_tracking), max(all_tracking) + 0.1*range(all_tracking)];
    
    all_noise = [noise_fixed(:); noise_kmeans(:)];
    unified_noise_limits = [min(all_noise) - 0.1*range(all_noise), max(all_noise) + 0.1*range(all_noise)];
    
    fig2 = figure('Name', 'Metric 2 - Model Jitter Noise Breakdown', ...
                  'Units', 'pixels', 'Position', [150 150 1100 650], ...
                  'Color', 'w', 'Visible', vis_setting);
    
    color_signal = [1.00, 0.50, 0.00]; color_trend = [0.00, 0.45, 0.74];  
    
    % ---------------------------------------------------------------------
    % Subplot 1: Fixed Threshold Waveform Tracking
    % ---------------------------------------------------------------------
    ax1 = subplot(2,2,1);
    plot(1:num_frames, nominal_fixed, 'Color', color_signal, 'LineWidth', 1.5); hold on; 
    plot(1:num_frames, trend_fixed, 'Color', color_trend, 'LineWidth', 2.5); 
    
    title('Fixed Threshold Waveform Tracking', 'FontWeight', 'bold', 'Color', [0 0 0]); 
    ylabel('Displacement (m^2)', 'Color', [0 0 0]);
    grid on; box on; ylim(unified_y_limits);
    set(ax1, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    
    lgd1 = legend({'Raw Track (\gamma = 0.35)', 'Macro Trend'}, 'Location', 'best');
    set(lgd1, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);
    
    % ---------------------------------------------------------------------
    % Subplot 2: Adaptive K-means Waveform Tracking
    % ---------------------------------------------------------------------
    ax2 = subplot(2,2,2);
    plot(1:num_frames, nominal_km, 'Color', color_signal, 'LineWidth', 1.5); hold on; 
    plot(1:num_frames, trend_km, 'Color', color_trend, 'LineWidth', 2.5); 
    
    title('Adaptive K-means Waveform Tracking', 'FontWeight', 'bold', 'Color', [0 0 0]);
    grid on; box on; ylim(unified_y_limits);
    set(ax2, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    
    lgd2 = legend({'Raw Track (Adaptive)', 'Macro Trend'}, 'Location', 'best');
    set(lgd2, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);
    
    % ---------------------------------------------------------------------
    % Subplot 3: Fixed Noise Residuals
    % ---------------------------------------------------------------------
    ax3 = subplot(2,2,3); 
    st1 = stem(1:num_frames, noise_fixed, 'Color', [0 0 0], 'LineWidth', 1.2);
    set(st1, 'MarkerFaceColor', [0 0 0], 'MarkerSize', 4);
    
    title(sprintf('Fixed Noise Residuals (SNR: %.2f dB)', snr_fixed), 'FontWeight', 'bold', 'Color', [0 0 0]); 
    xlabel('Sequential Frames', 'Color', [0 0 0]); ylabel('Noise Delta (m^2)', 'Color', [0 0 0]);
    grid on; box on; ylim(unified_noise_limits);
    set(ax3, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    
    % ---------------------------------------------------------------------
    % Subplot 4: K-means Noise Residuals
    % ---------------------------------------------------------------------
    ax4 = subplot(2,2,4); 
    st2 = stem(1:num_frames, noise_kmeans, 'Color', [0 0 0], 'LineWidth', 1.2);
    set(st2, 'MarkerFaceColor', [0 0 0], 'MarkerSize', 4);
    
    title(sprintf('K-means Noise Residuals (SNR: %.2f dB)', snr_kmeans), 'FontWeight', 'bold', 'Color', [0 0 0]); 
    xlabel('Sequential Frames', 'Color', [0 0 0]); ylabel('Noise Delta (m^2)', 'Color', [0 0 0]);
    grid on; box on; ylim(unified_noise_limits);
    set(ax4, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    
    % --- Global Super Title (Project File Name) ---
    if nargin >= 12 && ~isempty(name2proj)
        clean_title = strrep(name2proj, '_', '\_'); % Escape underscores for TeX renderer
        sgtitle(clean_title, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0], 'Interpreter', 'tex');
    end
    
    % Crisp export properties
    exportgraphics(fig2, fullfile(export_dir, 'metric_2_noise_breakdown.png'), 'Resolution', 300, 'BackgroundColor', 'w');
    if ~showfigs, close(fig2); end
end