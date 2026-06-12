clear; clc; close all;

% =========================================================================
% 1. PATH CONFIGURATION & DATA INGESTION
% =========================================================================
name2proj = 'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms';
project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';

% Pipeline directory alignment
export_dir = fullfile(project_root, 'D00_sample_data', 'real', name2proj, 'export_xxx');
sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis_report');

% Input data targets
csv_data_file   = fullfile(export_dir, 'water_surface_area_metrics.csv');
path_tuned_features = fullfile(export_dir, 'tuned_features.mat');

% Safety verifications
if ~isfile(csv_data_file)
    error('Target metrics CSV file not found: %s. Please run P03 first.', csv_data_file);
end
if ~isfile(path_tuned_features)
    error('Tuned features file containing time axis not found at: %s.', path_tuned_features);
end

% Read datasets
metrics = readtable(csv_data_file);
features = load(path_tuned_features);

% --- EXTRAS REAL-TIME CLOCK TIMESTAMP AXIS ---
frames_axis = datetime(features.exported_time_axis); 
frames_axis = frames_axis(:)'; % Row vector alignment
num_frames  = length(frames_axis);

if num_frames ~= height(metrics)
    error('Dimension mismatch between CSV rows (%d) and datetime points (%d).', height(metrics), num_frames);
end

% =========================================================================
% 2. GLOBAL PUBLICATION CANVAS STYLE DEFINITIONS
% =========================================================================
font_name          = 'Helvetica';
font_size_title    = 12;
font_size_axes     = 10;
font_size_legend   = 9;
text_weight        = 'bold';
text_color         = 'k';
line_width_thick   = 2.5;
line_width_thin    = 1.5;

% Unified high-contrast color scheme
color_nom_fixed    = [0.000, 0.447, 0.741];  % Muted Blue
color_nom_adapt    = [0.000, 0.000, 1.000];  % Pure Blue
color_det_fixed    = [0.850, 0.325, 0.098];  % Burnt Orange
color_det_adapt    = [1.000, 0.000, 0.000];  % Pure Red

color_encroach_nom = [0.150, 0.620, 0.350];  % Forest Green
color_retreat_nom  = [0.850, 0.230, 0.230];  % Deep Crimson
color_encroach_det = [0.120, 0.530, 0.700];  % Teal Blue
color_retreat_det  = [0.880, 0.400, 0.150];  % Rust Orange

if ~exist(sensitivity_export_dir, 'dir'), mkdir(sensitivity_export_dir); end
shared_xlim = [min(frames_axis), max(frames_axis)];

% =========================================================================
% 3. FIGURE 1: STANDALONE NET PERCENTAGE TREND CHANNELS
% =========================================================================
fig_net = figure('Name', 'Report - Net Surface Area Variance', ...
                 'Units', 'pixels', 'Position', [150, 150, 1000, 500], 'Color', 'w');
ax_net = axes(fig_net); hold(ax_net, 'on'); grid(ax_net, 'on'); box(ax_net, 'on');
set(ax_net, 'Color', 'w');

% Plot profiles
plot(ax_net, frames_axis, metrics.PctChange_NomFixed, '-', 'Color', color_nom_fixed, 'LineWidth', line_width_thin);
plot(ax_net, frames_axis, metrics.PctChange_NomAdapt, '-', 'Color', color_nom_adapt, 'LineWidth', line_width_thick);
plot(ax_net, frames_axis, metrics.PctChange_DetFixed, '-', 'Color', color_det_fixed, 'LineWidth', line_width_thin);
plot(ax_net, frames_axis, metrics.PctChange_DetAdapt, '-', 'Color', color_det_adapt, 'LineWidth', line_width_thick);
yline(ax_net, 0, '-', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');

% Axes & Labels Formatting
xlim(ax_net, shared_xlim); xtickformat(ax_net, 'HH:mm');
ax_net.XAxis.SecondaryLabelFormat = '';
ylim_vals = [metrics.PctChange_NomFixed; metrics.PctChange_NomAdapt; metrics.PctChange_DetFixed; metrics.PctChange_DetAdapt];
ylim(ax_net, [min(ylim_vals)-2, max(ylim_vals)+2]);

xlabel(ax_net, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'FontSize', font_size_axes, 'Color', text_color);
ylabel(ax_net, 'Area Deviation Percentage (Delta %)', 'FontWeight', text_weight, 'FontSize', font_size_axes, 'Color', text_color);
title(ax_net, {sprintf('Net Cumulative Water Surface Area Variance (Relative to Frame 1)'), ...
               sprintf('Project: %s', name2proj)}, ...
      'FontName', font_name, 'FontSize', font_size_title, 'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

legend(ax_net, {'Nominal Stream: Fixed', 'Nominal Stream: Adaptive', 'Detrended Stream: Fixed', 'Detrended Stream: Adaptive'}, ...
       'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', 'w');
set(ax_net, 'FontName', font_name, 'FontSize', font_size_axes, 'XColor', text_color, 'YColor', text_color, 'Layer', 'top');

% Save Standalone Chart A
net_chart_path = fullfile(sensitivity_export_dir, 'water_net_area_percentage_trends.png');
saveas(fig_net, net_chart_path);
close(fig_net);

% =========================================================================
% 4. FIGURE 2: STANDALONE DUAL-PANEL SHORELINE TRANSITIONS
% =========================================================================
fig_W = figure('Name', 'Report - Water Shoreline Transitions', ...
                   'Units', 'pixels', 'Position', [200, 50, 1100, 800], 'Color', 'w');

% Compute dynamic identical vertical boundaries matching global max magnitudes
global_max_W = max([metrics.Nom_W_Expansion_m2; metrics.Det_W_Expansion_m2; metrics.Nom_Net_Shift_m2; metrics.Det_Net_Shift_m2; 1]);
global_min_W = min([-metrics.Nom_W_Retreat_m2; -metrics.Det_W_Retreat_m2; metrics.Nom_Net_Shift_m2; metrics.Det_Net_Shift_m2; -1]);
padding_W    = 0.15 * max(global_max_W, abs(global_min_W));
shared_ylim_W = [global_min_W - padding_W, global_max_W + padding_W];

% --- SUBPLOT 1: Nominal Workspace ---
ax_g1 = subplot(2,1,1); hold(ax_g1, 'on'); grid(ax_g1, 'on'); box(ax_g1, 'on');
set(ax_g1, 'Color', 'w');
b_exp_nom = bar(ax_g1, frames_axis, metrics.Nom_W_Expansion_m2, 'FaceColor', color_encroach_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_nom = bar(ax_g1, frames_axis, -metrics.Nom_W_Retreat_m2, 'FaceColor', color_retreat_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_nom = plot(ax_g1, frames_axis, metrics.Nom_Net_Shift_m2, '-o', 'Color', 'k', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'k');
yline(ax_g1, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim(ax_g1, shared_xlim); ylim(ax_g1, shared_ylim_W); xtickformat(ax_g1, 'HH:mm');
ax_g1.XAxis.SecondaryLabelFormat = '';
title(ax_g1, 'Nominal Workspace Shoreline Transition Areas (Nominal Adaptive Engine)', 'FontSize', font_size_title, 'FontWeight', text_weight, 'Color', text_color);
ylabel(ax_g1, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'FontSize', font_size_axes, 'Color', text_color);
legend(ax_g1, [b_exp_nom, b_ret_nom, p_net_nom], {'Water Encroachment (Land \rightarrow Water)', 'Water Shoreline Retreat (Water \rightarrow Land)', 'Net Spatial Transition Velocity'}, ...
       'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', 'w');
set(ax_g1, 'FontName', font_name, 'FontSize', font_size_axes, 'XColor', text_color, 'YColor', text_color, 'Layer', 'top');

% --- SUBPLOT 2: Detrended Workspace ---
ax_g2 = subplot(2,1,2); hold(ax_g2, 'on'); grid(ax_g2, 'on'); box(ax_g2, 'on');
set(ax_g2, 'Color', 'w');
b_exp_det = bar(ax_g2, frames_axis, metrics.Det_W_Expansion_m2, 'FaceColor', color_encroach_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_det = bar(ax_g2, frames_axis, -metrics.Det_W_Retreat_m2, 'FaceColor', color_retreat_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_det = plot(ax_g2, frames_axis, metrics.Det_Net_Shift_m2, '-s', 'Color', 'k', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'k');
yline(ax_g2, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim(ax_g2, shared_xlim); ylim(ax_g2, shared_ylim_W); xtickformat(ax_g2, 'HH:mm');
ax_g2.XAxis.SecondaryLabelFormat = '';
title(ax_g2, 'Detrended Workspace Shoreline Transition Areas (Detrended Adaptive Engine)', 'FontSize', font_size_title, 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_g2, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'FontSize', font_size_axes, 'Color', text_color);
ylabel(ax_g2, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'FontSize', font_size_axes, 'Color', text_color);
legend(ax_g2, [b_exp_det, b_ret_det, p_net_det], {'Water Encroachment (Land \rightarrow Water)', 'Water Shoreline Retreat (Water \rightarrow Land)', 'Net Spatial Transition Velocity'}, ...
       'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', 'w');
set(ax_g2, 'FontName', font_name, 'FontSize', font_size_axes, 'XColor', text_color, 'YColor', text_color, 'Layer', 'top');

set(ax_g1, 'LooseInset', get(ax_g1, 'TightInset') + [0, 0.01, 0, 0.02]);
set(ax_g2, 'LooseInset', get(ax_g2, 'TightInset') + [0, 0.01, 0, 0.02]);
sgtitle(fig_W, sprintf('Dynamic Shoreline Churn Velocity Comparison  |  Dataset: %s', name2proj), ...
        'FontName', font_name, 'FontSize', font_size_title+1, 'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

% Save Standalone Chart B
W_chart_path = fullfile(sensitivity_export_dir, 'water_water_transition_dynamics.png');
saveas(fig_W, W_chart_path);
close(fig_W);

% =========================================================================
% ALTERNATIVE 1: COMPACT HORIZONTAL 3-COLUMN MATRIX DASHBOARD (WHITE/BLACK STYLED)
% =========================================================================
fig_dash = figure('Name', 'Report - Compact Horizontal Dashboard', ...
                  'Units', 'pixels', 'Position', [50, 100, 1600, 420], 'Color', 'w');

% Enforce explicit scale limits
ylim_net        = [-105, 105];
ylim_transition = [-30, 30];

% --- PANEL 1: Left ---
ax_dash1 = subplot(1,3,1); hold(ax_dash1, 'on'); grid(ax_dash1, 'on'); box(ax_dash1, 'on');
set(ax_dash1, 'Color', 'w');

plot(ax_dash1, frames_axis, metrics.PctChange_NomFixed, '-', 'Color', color_nom_fixed, 'LineWidth', line_width_thin);
plot(ax_dash1, frames_axis, metrics.PctChange_NomAdapt, '-', 'Color', color_nom_adapt, 'LineWidth', line_width_thick);
plot(ax_dash1, frames_axis, metrics.PctChange_DetFixed, '-', 'Color', color_det_fixed, 'LineWidth', line_width_thin);
plot(ax_dash1, frames_axis, metrics.PctChange_DetAdapt, '-', 'Color', color_det_adapt, 'LineWidth', line_width_thick);
yline(ax_dash1, 0, '-', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');

xlim(ax_dash1, shared_xlim); xtickformat(ax_dash1, 'HH:mm'); ylim(ax_dash1, ylim_net);
ax_dash1.XAxis.SecondaryLabelFormat = '';

ylabel(ax_dash1, 'Area Deviation (Delta %)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_dash1, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_dash1, 'Net Cumulative Water Surface Area Variance', 'FontSize', font_size_title-1, 'Color', text_color);

lgd1 = legend(ax_dash1, {'Nom. Fixed', 'Nom. Adapt', 'Det. Fixed', 'Det. Adapt'}, ...
       'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd1, 'Color', 'none');

% --- PANEL 2: Center ---
ax_dash2 = subplot(1,3,2); hold(ax_dash2, 'on'); grid(ax_dash2, 'on'); box(ax_dash2, 'on');
set(ax_dash2, 'Color', 'w');

b_exp_nom2 = bar(ax_dash2, frames_axis, metrics.Nom_W_Expansion_m2, 'FaceColor', color_encroach_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_nom2 = bar(ax_dash2, frames_axis, -metrics.Nom_W_Retreat_m2, 'FaceColor', color_retreat_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_nom2 = plot(ax_dash2, frames_axis, metrics.Nom_Net_Shift_m2, '-o', 'Color', 'k', 'LineWidth', 1.5, 'MarkerSize', 3, 'MarkerFaceColor', 'k');
yline(ax_dash2, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');

xlim(ax_dash2, shared_xlim); ylim(ax_dash2, ylim_transition); xtickformat(ax_dash2, 'HH:mm');
ax_dash2.XAxis.SecondaryLabelFormat = '';

ylabel(ax_dash2, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_dash2, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_dash2, 'Nominal Workspace Shoreline Transition Areas', 'FontSize', font_size_title-1, 'Color', text_color);

lgd2 = legend(ax_dash2, [b_exp_nom2, b_ret_nom2, p_net_nom2], ...
       {'Water Encroach.', 'Water Retreat', 'Net Velocity'}, ...
       'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd2, 'Color', 'none');

% --- PANEL 3: Right ---
ax_dash3 = subplot(1,3,3); hold(ax_dash3, 'on'); grid(ax_dash3, 'on'); box(ax_dash3, 'on');
set(ax_dash3, 'Color', 'w');

b_exp_det2 = bar(ax_dash3, frames_axis, metrics.Det_W_Expansion_m2, 'FaceColor', color_encroach_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_det2 = bar(ax_dash3, frames_axis, -metrics.Det_W_Retreat_m2, 'FaceColor', color_retreat_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_det2 = plot(ax_dash3, frames_axis, metrics.Det_Net_Shift_m2, '-s', 'Color', 'k', 'LineWidth', 1.5, 'MarkerSize', 3, 'MarkerFaceColor', 'k');
yline(ax_dash3, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');

xlim(ax_dash3, shared_xlim); ylim(ax_dash3, ylim_transition); xtickformat(ax_dash3, 'HH:mm');
ax_dash3.XAxis.SecondaryLabelFormat = '';

ylabel(ax_dash3, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_dash3, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_dash3, 'Detrended Workspace Shoreline Transition Areas', 'FontSize', font_size_title-1, 'Color', text_color);

lgd3 = legend(ax_dash3, [b_exp_det2, b_ret_det2, p_net_det2], ...
       {'Water Encroach.', 'Water Retreat', 'Net Velocity'}, ...
       'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd3, 'Color', 'none');

% --- Master Style Syncing ---
all_axes = [ax_dash1, ax_dash2, ax_dash3];
for i = 1:length(all_axes)
    set(all_axes(i), 'FontName', font_name, 'FontSize', font_size_axes, 'XColor', text_color, 'YColor', text_color, 'Layer', 'top');
    set(all_axes(i), 'LooseInset', get(all_axes(i), 'TightInset') + [0, 0.01, 0, 0.02]);
end

% Standard upper head header block
sgtitle(fig_dash, sprintf('Water Displacement & Shoreline Dynamics Grid  |  Dataset: %s', name2proj), ...
        'FontName', font_name, 'FontSize', font_size_title, 'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

% Save execution asset
unified_chart_path = fullfile(sensitivity_export_dir, 'horizontal_compact_dashboard.png');
saveas(fig_dash, unified_chart_path);
close(fig_dash);

fprintf('✔ Re-scaled unified dashboard successfully generated and saved to directory.\n');

% =========================================================================
% ALTERNATIVE 2: COMPACT HORIZONTAL 3-COLUMN DASHBOARD WITH MOVING AVERAGE SMOOTHING
% =========================================================================
% --- 1. Filter & Axis Limit Configurations (ADAPT THESE AS NEEDED) ---
smooth_window = 5;       % Central moving average frame window length (odd integer recommended)
ylim_net_smooth = [-105, 105];   % Y-limits for Panel 1 (Area Deviation %)
ylim_tran_smooth = [-30, 30];    % Y-limits for Panels 2 & 3 (Transition Areas m^2)

% --- 2. Calculate Temporal Moving Window Filters ---
smooth_pct_nom_fixed = movmean(metrics.PctChange_NomFixed, smooth_window);
smooth_pct_nom_adapt = movmean(metrics.PctChange_NomAdapt, smooth_window);
smooth_pct_det_fixed = movmean(metrics.PctChange_DetFixed, smooth_window);
smooth_pct_det_adapt = movmean(metrics.PctChange_DetAdapt, smooth_window);

smooth_exp_nom = movmean(metrics.Nom_W_Expansion_m2, smooth_window);
smooth_ret_nom = movmean(metrics.Nom_W_Retreat_m2, smooth_window);
smooth_exp_det = movmean(metrics.Det_W_Expansion_m2, smooth_window);
smooth_ret_det = movmean(metrics.Det_W_Retreat_m2, smooth_window);

% Derive smoothed net transformation vectors
smooth_net_nom = smooth_exp_nom - smooth_ret_nom;
smooth_net_det = smooth_exp_det - smooth_ret_det;

% --- 3. Figure Canvas Initialization ---
fig_dash_smooth = figure('Name', 'Report - Filtered Compact Horizontal Dashboard', ...
                         'Units', 'pixels', 'Position', [80, 120, 1600, 420], 'Color', 'w');

% --- PANEL 1: Left (Smoothed Net Percentages) ---
ax_sm1 = subplot(1,3,1); hold(ax_sm1, 'on'); grid(ax_sm1, 'on'); box(ax_sm1, 'on');
set(ax_sm1, 'Color', 'w');
plot(ax_sm1, frames_axis, smooth_pct_nom_fixed, '-', 'Color', color_nom_fixed, 'LineWidth', line_width_thin);
plot(ax_sm1, frames_axis, smooth_pct_nom_adapt, '-', 'Color', color_nom_adapt, 'LineWidth', line_width_thick);
plot(ax_sm1, frames_axis, smooth_pct_det_fixed, '-', 'Color', color_det_fixed, 'LineWidth', line_width_thin);
plot(ax_sm1, frames_axis, smooth_pct_det_adapt, '-', 'Color', color_det_adapt, 'LineWidth', line_width_thick);
yline(ax_sm1, 0, '-', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim(ax_sm1, shared_xlim); xtickformat(ax_sm1, 'HH:mm'); ylim(ax_sm1, ylim_net_smooth);
ax_sm1.XAxis.SecondaryLabelFormat = '';
ylabel(ax_sm1, 'Area Deviation (Delta %)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_sm1, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_sm1, 'Net Cumulative Water Surface Area Variance', 'FontSize', font_size_title-1, 'Color', text_color);
lgd_sm1 = legend(ax_sm1, {'Nom. Fixed', 'Nom. Adapt', 'Det. Fixed', 'Det. Adapt'}, ...
          'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd_sm1, 'Color', 'none');

% --- PANEL 2: Center (Smoothed Nominal Transitions) ---
ax_sm2 = subplot(1,3,2); hold(ax_sm2, 'on'); grid(ax_sm2, 'on'); box(ax_sm2, 'on');
set(ax_sm2, 'Color', 'w');
b_exp_nom_sm = bar(ax_sm2, frames_axis, smooth_exp_nom, 'FaceColor', color_encroach_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_nom_sm = bar(ax_sm2, frames_axis, -smooth_ret_nom, 'FaceColor', color_retreat_nom, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_nom_sm = plot(ax_sm2, frames_axis, smooth_net_nom, '-o', 'Color', 'k', 'LineWidth', 1.5, 'MarkerSize', 3, 'MarkerFaceColor', 'k');
yline(ax_sm2, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim(ax_sm2, shared_xlim); ylim(ax_sm2, ylim_tran_smooth); xtickformat(ax_sm2, 'HH:mm');
ax_sm2.XAxis.SecondaryLabelFormat = '';
ylabel(ax_sm2, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_sm2, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_sm2, 'Nominal Workspace Shoreline Transition Areas', 'FontSize', font_size_title-1, 'Color', text_color);
lgd_sm2 = legend(ax_sm2, [b_exp_nom_sm, b_ret_nom_sm, p_net_nom_sm], ...
          {'Water Encroach.', 'Water Retreat', 'Net Velocity'}, ...
          'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd_sm2, 'Color', 'none');

% --- PANEL 3: Right (Smoothed Detrended Transitions) ---
ax_sm3 = subplot(1,3,3); hold(ax_sm3, 'on'); grid(ax_sm3, 'on'); box(ax_sm3, 'on');
set(ax_sm3, 'Color', 'w');
b_exp_det_sm = bar(ax_sm3, frames_axis, smooth_exp_det, 'FaceColor', color_encroach_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
b_ret_det_sm = bar(ax_sm3, frames_axis, -smooth_ret_det, 'FaceColor', color_retreat_det, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
p_net_det_sm = plot(ax_sm3, frames_axis, smooth_net_det, '-s', 'Color', 'k', 'LineWidth', 1.5, 'MarkerSize', 3, 'MarkerFaceColor', 'k');
yline(ax_sm3, 0, '-', 'Color', 'k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlim(ax_sm3, shared_xlim); ylim(ax_sm3, ylim_tran_smooth); xtickformat(ax_sm3, 'HH:mm');
ax_sm3.XAxis.SecondaryLabelFormat = '';
ylabel(ax_sm3, 'Active Surface Delta (m^2)', 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax_sm3, 'Acquisition Time (HH:mm)', 'FontWeight', text_weight, 'Color', text_color);
title(ax_sm3, 'Detrended Workspace Shoreline Transition Areas', 'FontSize', font_size_title-1, 'Color', text_color);
lgd_sm3 = legend(ax_sm3, [b_exp_det_sm, b_ret_det_sm, p_net_det_sm], ...
          {'Water Encroach.', 'Water Retreat', 'Net Velocity'}, ...
          'Location', 'northeast', 'FontSize', font_size_legend-1, 'TextColor', text_color, 'Interpreter', 'tex');
set(lgd_sm3, 'Color', 'none');

% --- 4. Dashboard Canvas Formatting & Syncing ---
sm_axes = [ax_sm1, ax_sm2, ax_sm3];
for i = 1:length(sm_axes)
    set(sm_axes(i), 'FontName', font_name, 'FontSize', font_size_axes, 'XColor', text_color, 'YColor', text_color, 'Layer', 'top');
    set(sm_axes(i), 'LooseInset', get(sm_axes(i), 'TightInset') + [0, 0.01, 0, 0.02]);
end

sgtitle(fig_dash_smooth, sprintf('Water Displacement & Shoreline Dynamics Grid (Filtered Window = %d frames)  |  Dataset: %s', smooth_window, name2proj), ...
        'FontName', font_name, 'FontSize', font_size_title, 'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

% --- 5. Export Performance Asset ---
smoothed_chart_path = fullfile(sensitivity_export_dir, 'horizontal_compact_dashboard_smoothed.png');
saveas(fig_dash_smooth, smoothed_chart_path);
close(fig_dash_smooth);
fprintf('✔ Smoothed uniform dashboard successfully generated and saved to directory.\n');