clear; clc; close all;

% =========================================================================
% 1. PATH DEFINITIONS & DATA INGESTION (DIRECTLY LINKED TO P02 EXPORTS)
% =========================================================================
name2proj = 'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms';
project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';

% Establish clear path tracking mirroring your core pipeline structure
export_dir = fullfile(project_root, 'D00_sample_data', 'real', name2proj, 'export_xxx');

% NEW DIRECTORY DESIGNATION FOR YOUR REPORT FIGURES
sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis_report');
path_tracking_results = fullfile(export_dir, 'tracking_results.mat');
path_tuned_features   = fullfile(export_dir, 'tuned_features.mat');

if ~exist(path_tracking_results, 'file')
    error('Tracking results file not found at: %s. Run the pipeline first.', path_tracking_results);
end
if ~exist(path_tuned_features, 'file')
    error('Tuned features file containing time axis not found at: %s.', path_tuned_features);
end

% Ingest variables from pipeline processing stages
metrics = load(path_tracking_results);
features = load(path_tuned_features);

gamma_nom = metrics.adaptive_threshold_history_nom;
gamma_det = metrics.adaptive_threshold_history_det;
num_frames = metrics.num_frames;

% --- PARSE REAL-TIME CLOCK TIMESTAMP AXIS ---
frames_axis = datetime(features.exported_time_axis); 
frames_axis = frames_axis(:)'; % Ensure row vector for seamless matrix patching

% --- EXTRACT CONFIGURED MULTI-LEVEL THRESHOLDS DIRECTLY FROM P02 ARRAY ---
fixed_thresh_nom = metrics.thresh_nom(1);
thresh_nom_lower = metrics.thresh_nom(2);
thresh_nom_upper = metrics.thresh_nom(3);

fixed_thresh_det = metrics.thresh_det(1);
thresh_det_lower = metrics.thresh_det(2);
thresh_det_upper = metrics.thresh_det(3);

% =========================================================================
% 2. ADVANCED STATISTICAL COMPUTATIONS
% =========================================================================
valid_idx = ~isnan(gamma_nom) & ~isnan(gamma_det);
if sum(valid_idx) > 3
    R_matrix = corrcoef(gamma_nom(valid_idx), gamma_det(valid_idx));
    global_r = R_matrix(1, 2);
else
    global_r = NaN;
end

rolling_window = 5; 
rolling_r = nan(num_frames, 1);
for t = 1:num_frames
    s_idx = max(1, t - floor(rolling_window/2));
    e_idx = min(num_frames, t + floor(rolling_window/2));
    sub_nom = gamma_nom(s_idx:e_idx);
    sub_det = gamma_det(s_idx:e_idx);
    sub_valid = ~isnan(sub_nom) & ~isnan(sub_det);
    if sum(sub_valid) >= 4  
        r_sub = corrcoef(sub_nom(sub_valid), sub_det(sub_valid));
        rolling_r(t) = r_sub(1, 2);
    end
end

% Global Plot Style Definitions
color_nom = [0.0, 0.4470, 0.7410];     % Deep Blue
color_det = [0.8500, 0.3250, 0.0980];     % Burnt Orange
color_corr = [0.4660, 0.6740, 0.1880];    % Olive Green
band_color_nom = [0.0, 0.4470, 0.7410];   % Blue tint for nominal band
band_color_det = [0.8500, 0.3250, 0.0980];% Orange tint for detrended band
clean_title_name = strrep(name2proj, '_', '\_');

% Pull actual graphic limit bounds directly from dataset array scales
%clim_nom = [min([gamma_nom(:); thresh_nom_lower])*0.9, max([gamma_nom(:); thresh_nom_upper])*1.1];
%clim_det = [min([gamma_det(:); thresh_det_lower])*0.9, max([gamma_det(:); thresh_det_upper])*1.1];
% Explicitly set limits matching the clean dashboard scales
clim_nom = [0.125, 0.155];
clim_det = [-0.5, -0.15];

if ~exist(sensitivity_export_dir, 'dir'), mkdir(sensitivity_export_dir); end

% =========================================================================
% 3. INDIVIDUAL EXPORTS (SPLIT BY ROW)
% =========================================================================

% --- FIGURE 1: DUAL ENGINE TIMELINE PLOTS (ROW 1) ---
fig_row1 = figure('Name', sprintf('Threshold Evolution (Timelines) - %s', name2proj), ...
                  'Units', 'pixels', 'Position', [200, 200, 1100, 400], 'Color', 'w');

% Left Plot: Nominal Stream
ax_r1a = subplot(1, 2, 1); hold(ax_r1a, 'on'); grid(ax_r1a, 'on'); box(ax_r1a, 'on');
h_adapt_nom = plot(ax_r1a, frames_axis, gamma_nom, '-', 'Color', color_nom, 'LineWidth', 2.5); 
X_patch = [frames_axis, fliplr(frames_axis)];
Y_patch_nom = [repelem(thresh_nom_upper, num_frames), repelem(thresh_nom_lower, num_frames)];
fill(ax_r1a, X_patch, Y_patch_nom, band_color_nom, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
h_base_nom = yline(ax_r1a, fixed_thresh_nom, 'k--', 'LineWidth', 1.5);
xlabel(ax_r1a, 'Acquisition Time', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax_r1a, 'Nominal Threshold Value', 'FontWeight', 'bold', 'Color', 'k');
ylim(ax_r1a, clim_nom); xlim(ax_r1a, [min(frames_axis), max(frames_axis)]);
set(ax_r1a, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xtickformat(ax_r1a, 'HH:mm');
ax_r1a.XAxis.SecondaryLabelFormat = ''; 
title(ax_r1a, 'Nominal Engine Scale (Coherence Matrix)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
legend(ax_r1a, [h_adapt_nom, h_base_nom], {'Adaptive Boundary (\gamma_{ad})', 'Fixed Baseline (\gamma)'}, ...
       'Location', 'northeast', 'Color', 'w', 'TextColor', 'k');

% Right Plot: Detrended Stream
ax_r1b = subplot(1, 2, 2); hold(ax_r1b, 'on'); grid(ax_r1b, 'on'); box(ax_r1b, 'on');
h_adapt_det = plot(ax_r1b, frames_axis, gamma_det, '-', 'Color', color_det, 'LineWidth', 2.5); 
Y_patch_det = [repelem(thresh_det_upper, num_frames), repelem(thresh_det_lower, num_frames)];
fill(ax_r1b, X_patch, Y_patch_det, band_color_det, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
h_base_det = yline(ax_r1b, fixed_thresh_det, 'k--', 'LineWidth', 1.5);
xlabel(ax_r1b, 'Acquisition Time', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax_r1b, 'Detrended Threshold Value', 'FontWeight', 'bold', 'Color', 'k');
ylim(ax_r1b, clim_det); xlim(ax_r1b, [min(frames_axis), max(frames_axis)]);
set(ax_r1b, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xtickformat(ax_r1b, 'HH:mm');
ax_r1b.XAxis.SecondaryLabelFormat = ''; 
title(ax_r1b, 'Detrended Engine Scale (Residual Feature Space)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
legend(ax_r1b, [h_adapt_det, h_base_det], {'Adaptive Boundary (\gamma_{ad})', 'Fixed Baseline (\gamma)'}, ...
       'Location', 'northeast', 'Color', 'w', 'TextColor', 'k');

% Unified Figure Title
sgtitle(fig_row1, sprintf('Threshold Evolution (Adaptive Limits) — %s', clean_title_name), ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');

saveas(fig_row1, fullfile(sensitivity_export_dir, 'split_row1_threshold_timelines.png'));
close(fig_row1);


% --- FIGURE 2: ROLLING TEMPORAL COUPLING (ROW 2) ---
fig_row2 = figure('Name', sprintf('Threshold Evolution (Coupling) - %s', name2proj), ...
                  'Units', 'pixels', 'Position', [200, 200, 1100, 360], 'Color', 'w');
ax_r2 = axes(fig_row2); hold(ax_r2, 'on'); grid(ax_r2, 'on'); box(ax_r2, 'on');

% Plot profiles
plot(ax_r2, frames_axis, rolling_r, '-', 'Color', color_corr, 'LineWidth', 2.2); 
fill_r = rolling_r; fill_r(isnan(fill_r)) = 0;
area(ax_r2, frames_axis, fill_r, 'FaceColor', color_corr, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
yline(ax_r2, 0, 'k:', 'LineWidth', 1.2); 

% =========================================================================
% STRICTOR GEOMETRY & BOUNDARY SCALE ENFORCEMENT ENGINE
% =========================================================================
% 1. Hard-lock Y-limits symmetrically 
ylim(ax_r2, [-1.1, 1.1]); 

% 2. Enforce identical Y-tick intervals across all projects
yticks(ax_r2, -1:0.2:1); 

% 3. Standardize X-axis boundaries relative to the current project's time vector
xlim(ax_r2, [min(frames_axis), max(frames_axis)]);
xtickformat(ax_r2, 'HH:mm');
ax_r2.XAxis.SecondaryLabelFormat = '';

% 4. FORCE FIXED PLOT BOUNDARY WIDTHS (Eliminates title/label squishing variations)
set(ax_r2, 'ActivePositionProperty', 'position'); 
set(ax_r2, 'Position', [0.08, 0.15, 0.88, 0.68]); % Directly locks down [Left, Bottom, Width, Height] in normalized coordinates

% 5. Master Canvas Style Standardization
set(ax_r2, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
set(ax_r2, 'FontName', 'Helvetica', 'FontSize', 10); 

% Labels & Titles
xlabel(ax_r2, 'Acquisition Time', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax_r2, 'Pearson Coefficient (r)', 'FontWeight', 'bold', 'Color', 'k');

title(ax_r2, {sprintf('Threshold Evolution (Engine Coupling Profile) — %s', name2proj), ...
              sprintf('(Moving Window Size = %d Frames)', rolling_window)}, ...
      'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'none');

% Export Asset
saveas(fig_row2, fullfile(sensitivity_export_dir, 'split_row2_engine_coupling.png'));
close(fig_row2);


% --- FIGURE 3: SCATTER INTERCEPT & PHASE SPACE (ROW 3) ---
fig_row3 = figure('Name', sprintf('Threshold Evolution (Phase Space) - %s', name2proj), ...
                  'Units', 'pixels', 'Position', [200, 200, 1100, 400], 'Color', 'w');
ax_r3 = axes(fig_row3); hold(ax_r3, 'on'); grid(ax_r3, 'on'); box(ax_r3, 'on');
scatter_time_num = minutes(frames_axis - frames_axis(1));
scatter(ax_r3, gamma_nom, gamma_det, 55, scatter_time_num, 'filled', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeColor', 'k', 'LineWidth', 0.6);
if sum(valid_idx) > 3
    p = polyfit(gamma_nom(valid_idx), gamma_det(valid_idx), 1);
    x_fit = linspace(min(gamma_nom), max(gamma_nom), 100);
    y_fit = polyval(p, x_fit);
    plot(ax_r3, x_fit, y_fit, 'r--', 'LineWidth', 1.5);
end
set(ax_r3, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xlabel(ax_r3, 'Nominal Scale Boundary (\gamma_{nom})', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax_r3, 'Detrended Residual Boundary (\gamma_{det})', 'FontWeight', 'bold', 'Color', 'k');

% Two-line title layout prevents cutoff along the window border
title(ax_r3, {sprintf('Threshold Evolution (Cross-Engine Phase Space Mapping)'), ...
              sprintf('Project: %s', name2proj)}, ...
      'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'none');

% Allocate extra space at the top of the canvas layout bounds
set(ax_r3, 'LooseInset', get(ax_r3, 'TightInset') + [0, 0, 0, 0.06]);

cb = colorbar(ax_r3, 'Location', 'eastoutside'); set(cb, 'Color', 'k');
ylabel(cb, 'Elapsed Time (minutes since start)', 'FontWeight', 'bold', 'Color', 'k');

saveas(fig_row3, fullfile(sensitivity_export_dir, 'split_row3_phase_space.png'));
close(fig_row3);

% =========================================================================
% 4. UNIFIED COMPILED MASTER DASHBOARD EXPORT
% =========================================================================
fig_analytics = figure('Name', 'Dual-Engine Correlation Dashboard', ...
                       'Units', 'pixels', 'Position', [150, 50, 1100, 900], ...
                       'Color', 'w');

% PANEL 1A: NOMINAL TIMELINE
ax1a = subplot(3, 2, 1); hold(ax1a, 'on'); grid(ax1a, 'on'); box(ax1a, 'on');
h_adapt_nom = plot(ax1a, frames_axis, gamma_nom, '-', 'Color', color_nom, 'LineWidth', 2.5); % Datetime first
fill(ax1a, X_patch, Y_patch_nom, band_color_nom, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
h_base_nom = yline(ax1a, fixed_thresh_nom, 'k--', 'LineWidth', 1.5);
ylabel(ax1a, 'Nominal Threshold Value', 'FontWeight', 'bold', 'Color', 'k');
ylim(ax1a, clim_nom); xlim(ax1a, [min(frames_axis), max(frames_axis)]);
set(ax1a, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top', 'XTickLabel', {}); 
title(ax1a, 'Nominal Engine Scale (Coherence Matrix)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
legend(ax1a, [h_adapt_nom, h_base_nom], {'Adaptive Boundary (\gamma_{ad})', 'Fixed Baseline (\gamma)'}, ...
       'Location', 'northeast', 'Color', 'w', 'TextColor', 'k');

% PANEL 1B: DETRENDED TIMELINE
ax1b = subplot(3, 2, 2); hold(ax1b, 'on'); grid(ax1b, 'on'); box(ax1b, 'on');
h_adapt_det = plot(ax1b, frames_axis, gamma_det, '-', 'Color', color_det, 'LineWidth', 2.5); % Datetime first
fill(ax1b, X_patch, Y_patch_det, band_color_det, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
h_base_det = yline(ax1b, fixed_thresh_det, 'k--', 'LineWidth', 1.5);
ylabel(ax1b, 'Detrended Threshold Value', 'FontWeight', 'bold', 'Color', 'k');
ylim(ax1b, clim_det); xlim(ax1b, [min(frames_axis), max(frames_axis)]);
set(ax1b, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top', 'XTickLabel', {}); 
title(ax1b, 'Detrended Engine Scale (Residual Feature Space)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
legend(ax1b, [h_adapt_det, h_base_det], {'Adaptive Boundary (\gamma_{ad})', 'Fixed Baseline (\gamma)'}, ...
       'Location', 'northeast', 'Color', 'w', 'TextColor', 'k');

% Overhead Main Header Titles
sgtitle({['Dual-Engine Threshold Analytical Profiles — Project: ', clean_title_name], ...
         sprintf('Global Track Alignment (Linear Pearson r): %.3f', global_r)}, ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');

% PANEL 2: ROLLING TEMPORAL COUPLING
ax2 = subplot(3, 2, [3, 4]); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
plot(ax2, frames_axis, rolling_r, '-', 'Color', color_corr, 'LineWidth', 2.2); % Datetime first
area(ax2, frames_axis, fill_r, 'FaceColor', color_corr, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
yline(ax2, 0, 'k:', 'LineWidth', 1.2);
ylim(ax2, [-1.05, 1.05]); xlim(ax2, [min(frames_axis), max(frames_axis)]);
set(ax2, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xtickformat(ax2, 'HH:mm');
xlabel(ax2, 'Acquisition Time (HH:mm)', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax2, 'Pearson Coefficient (r)', 'FontWeight', 'bold', 'Color', 'k');
title(ax2, sprintf('Engine Coupling Profile History (Moving Window Size = %d Frames)', rolling_window), ...
      'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');

% PANEL 3: SCATTER INTERCEPT & PHASE SPACE
ax3 = subplot(3, 2, [5, 6]); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
scatter(ax3, gamma_nom, gamma_det, 55, scatter_time_num, 'filled', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeColor', 'k', 'LineWidth', 0.6);
if sum(valid_idx) > 3
    plot(ax3, x_fit, y_fit, 'r--', 'LineWidth', 1.5);
end
set(ax3, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xlabel(ax3, 'Nominal Scale Boundary (\gamma_{nom})', 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax3, 'Detrended Residual Boundary (\gamma_{det})', 'FontWeight', 'bold', 'Color', 'k');
title(ax3, 'Cross-Engine Scale Mapping (Phase Space Intercept)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
cb = colorbar(ax3, 'Location', 'eastoutside'); set(cb, 'Color', 'k');
ylabel(cb, 'Elapsed Time (minutes since start)', 'FontWeight', 'bold', 'Color', 'k');

% Export Combined Master Version
enhanced_trend_filename = fullfile(sensitivity_export_dir, 'dual_engine_statistical_coupling.png');
saveas(fig_analytics, enhanced_trend_filename);
close(fig_analytics);

fprintf('✔ Axis configuration conflict resolved. Outputs successfully exported to:\n   👉 %s\n', sensitivity_export_dir);

% =========================================================================
% 5. STATISTICAL METRICS SUMMARY & EXPORT ENGINE
% =========================================================================
% Isolate valid (non-NaN) tracking frames for statistical computation
valid_nom_data = gamma_nom(~isnan(gamma_nom));
valid_det_data = gamma_det(~isnan(gamma_det));

% Compute descriptive metrics for the Nominal Engine Scale
mean_nom   = mean(valid_nom_data);
median_nom = median(valid_nom_data);
std_nom    = std(valid_nom_data);

% Compute descriptive metrics for the Detrended Engine Scale
mean_det   = mean(valid_det_data);
median_det = median(valid_det_data);
std_det    = std(valid_det_data);

% Build absolute filepath targeting your report subdirectory
txt_report_filename = fullfile(sensitivity_export_dir, 'adaptive_threshold_statistical_summary.txt');

% Open file write stream and dump structured tracking data blocks
fid = fopen(txt_report_filename, 'w');
if fid == -1
    error('Could not write asset tracking file at: %s', txt_report_filename);
end

fprintf(fid, '=========================================================================\n');
fprintf(fid, '            ADAPTIVE THRESHOLD DESCRIPTIVE STATISTICS REPORT             \n');
fprintf(fid, '=========================================================================\n');
fprintf(fid, 'Project Reference Sequence : %s\n', name2proj);
fprintf(fid, 'Total Monitored Frames     : %d\n', num_frames);
fprintf(fid, 'Global Correlation (r)     : %.4f\n\n', global_r);

fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, ' NOMINAL ENGINE SCALE CHARACTERISTICS (COHERENCE MATRIX)                \n');
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Mean Adaptive Threshold    : %.6f\n', mean_nom);
fprintf(fid, 'Median Adaptive Threshold  : %.6f\n', median_nom);
fprintf(fid, 'Standard Deviation (\\sigma)   : %.6f\n\n', std_nom);

fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, ' DETRENDED ENGINE SCALE CHARACTERISTICS (RESIDUAL FEATURE SPACE)         \n');
fprintf(fid, '-------------------------------------------------------------------------\n');
fprintf(fid, 'Mean Adaptive Threshold    : %.6f\n', mean_det);
fprintf(fid, 'Median Adaptive Threshold  : %.6f\n', median_det);
fprintf(fid, 'Standard Deviation (\\sigma)   : %.6f\n', std_det);
fprintf(fid, '=========================================================================\n');

fclose(fid);
fprintf('✔ Descriptive threshold statistics successfully exported to text file.\n');

% =========================================================================
% ADVANCED SENSITIVITY METRICS: VOLATILITY & MOVING DISPERSION BANDS
% =========================================================================
% 1. Compute Frame-to-Frame Threshold Volatility (First Derivative)
volatility_nom = [0; diff(gamma_nom)];
volatility_det = [0; diff(gamma_det)];

mean_abs_vol_nom = mean(abs(volatility_nom), 'omitnan');
mean_abs_vol_det = mean(abs(volatility_det), 'omitnan');

% 2. Compute a Moving Variance Envelope (Localized Confidence Band)
envelope_window = 7; % Window scale (~2 mins 20 secs)
moving_mean_nom = movmean(gamma_nom, envelope_window, 'omitnan');
moving_std_nom  = movstd(gamma_nom, envelope_window, 'omitnan');

% Define Upper and Lower Trajectory Boundaries (1.5 Sigma Coverage)
upper_conf_nom = moving_mean_nom + 1.5 * moving_std_nom;
lower_conf_nom = moving_mean_nom - 1.5 * moving_std_nom;

% --- 3. Example Plotting Implementation for a Dynamic Variance Envelope ---
fig_envelope = figure('Name', 'Adaptive Curve with Dynamic Confidence Envelope', 'Color', 'w');
ax_env = axes(fig_envelope); hold(ax_env, 'on'); grid(ax_env, 'on');

% Plot the filled dynamic confidence envelope
X_env_patch = [frames_axis, fliplr(frames_axis)];
Y_env_patch = [upper_conf_nom(:)', fliplr(lower_conf_nom(:)')];
fill(ax_env, X_env_patch, Y_env_patch, color_nom, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'on');

% Plot center tracking streams
plot(ax_env, frames_axis, gamma_nom, '-', 'Color', color_nom, 'LineWidth', 2.5);
plot(ax_env, frames_axis, moving_mean_nom, 'k--', 'LineWidth', 1.2);

xlim(ax_env, [min(frames_axis), max(frames_axis)]); ylim(ax_env, clim_nom);
xtickformat(ax_env, 'HH:mm');
ylabel(ax_env, 'Nominal Threshold Value'); xlabel(ax_env, 'Acquisition Time');
legend(ax_env, {'\pm1.5\sigma Moving Variance Band', 'Instantaneous Adaptive \gamma', 'Local Moving Trend'}, 'Location', 'northeast');
title(ax_env, 'Adaptive Threshold Evolution with Dynamic Local Dispersion Envelope');