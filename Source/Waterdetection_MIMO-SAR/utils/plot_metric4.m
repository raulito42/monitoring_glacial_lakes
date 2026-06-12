function plot_metric4(nominal_fixed_signal, nominal_kmeans_signal, noise_fixed, noise_kmeans, export_dir, showfigs, name2proj)
    vis_setting = 'on'; if ~showfigs, vis_setting = 'off'; end
    
    mean_fixed  = mean(nominal_fixed_signal);
    mean_kmeans = mean(nominal_kmeans_signal);
    
    % Adjusted Position: increased vertical height to 600px to give text room to breathe
    fig4 = figure('Name', 'Metric 4 - Statistical Bias & Noise Distributions', ...
                  'Units', 'pixels', 'Position', [200 100 1000 600], ...
                  'Color', 'w', 'Visible', vis_setting);

    % ---------------------------------------------------------------------
    % Subplot A: Boxplot
    % ---------------------------------------------------------------------
    ax1 = subplot(1,2,1);
    boxplot([nominal_fixed_signal, nominal_kmeans_signal], 'Labels', {'Fixed Threshold', 'Adaptive K-means'}, 'Colors', 'b');
    grid on; box on;
    ylabel('Area Displacement Delta (m^2)', 'FontWeight', 'bold', 'Color', [0 0 0]);
    title('A. Overall Signal Distribution & Bias Spread', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0]);
    hold on;
    
    plot(1, mean_fixed, 'rd', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    plot(2, mean_kmeans, 'gd', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    
    set(ax1, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    
    lgd_box = legend('Mean Anchor Point', 'Location', 'north');
    set(lgd_box, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);

    % ---------------------------------------------------------------------
    % Subplot B: Distribution Density Profiles
    % ---------------------------------------------------------------------
    ax2 = subplot(1,2,2);
    color_signal = [1.00, 0.50, 0.00]; color_trend = [0.00, 0.45, 0.74];
    
    try
        [f_fix, x_fix] = ksdensity(noise_fixed);
        [f_km, x_km]   = ksdensity(noise_kmeans);
        plot(x_fix, f_fix, 'Color', color_signal, 'LineWidth', 2.5); hold on;
        plot(x_km, f_km, 'Color', color_trend, 'LineWidth', 2.5);
        fill(x_fix, f_fix, color_signal, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
        fill(x_km, f_km, color_trend, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
        ylabel('Probability Density', 'Color', [0 0 0]);
    catch
        histogram(noise_fixed, 'Normalization', 'pdf', 'FaceColor', color_signal, 'FaceAlpha', 0.4); hold on;
        histogram(noise_kmeans, 'Normalization', 'pdf', 'FaceColor', color_trend, 'FaceAlpha', 0.4);
        ylabel('Relative Density', 'Color', [0 0 0]);
    end
    
    grid on; box on;
    set(ax2, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'GridColor', [0 0 0], 'GridAlpha', 0.2);
    xlabel('Noise Residuals Value (m^2)', 'FontWeight', 'bold', 'Color', [0 0 0]);
    title('B. Noise Residual Error Distributions', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0]);
    
    lgd_dist = legend({'Fixed Threshold Noise', 'Adaptive K-means Noise'}, 'Location', 'northeast');
    set(lgd_dist, 'Color', 'w', 'EdgeColor', [0 0 0], 'TextColor', [0 0 0]);

    % ---------------------------------------------------------------------
    % --- CRITICAL OVERLAP CORRECTION ---
    % ---------------------------------------------------------------------
    % Slightly shift both subplots downward to make room for the large file name title
    ax1.Position(2) = 0.12; ax1.Position(4) = 0.73;
    ax2.Position(2) = 0.12; ax2.Position(4) = 0.73;

    if nargin >= 7 && ~isempty(name2proj)
        clean_title = strrep(name2proj, '_', '\_'); 
        % Injecting explicit margin rules below the global header text
        sgtitle(clean_title, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0], 'Interpreter', 'tex');
    end

    % Export with background handling
    exportgraphics(fig4, fullfile(export_dir, 'metric_4_statistical_distributions.png'), 'Resolution', 300, 'BackgroundColor', 'w');
    
    % ---------------------------------------------------------------------
    % Save Text Report Summary
    % ---------------------------------------------------------------------
    fid = fopen(fullfile(export_dir, 'statistical_summary_report.txt'), 'w');
    if fid ~= -1
        fprintf(fid, '==================================================\n');
        fprintf(fid, '     STATISTICAL BIAS & STABILITY REPORT          \n');
        fprintf(fid, '==================================================\n');
        fprintf(fid, 'Fixed Mean Offset Area:    %14.4f m^2\n', mean_fixed);
        fprintf(fid, 'K-means Mean Offset Area:  %14.4f m^2\n', mean_kmeans);
        fprintf(fid, '--------------------------------------------------\n');
        fprintf(fid, 'Fixed Noise Variance:      %14.4f m^2\n', var(noise_fixed));
        fprintf(fid, 'K-means Noise Variance:    %14.4f m^2\n', var(noise_kmeans));
        fprintf(fid, '--------------------------------------------------\n');
        fprintf(fid, 'Fixed Noise IQR:           %14.4f m^2\n', iqr(noise_fixed));
        fprintf(fid, 'K-means Noise IQR:         %14.4f m^2\n', iqr(noise_kmeans));
        fprintf(fid, '==================================================\n');
        fclose(fid);
    end
    if ~showfigs, close(fig4); end
end