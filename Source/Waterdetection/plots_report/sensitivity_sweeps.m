clear; clc; close all;
% =========================================================================
% 1. PATH DEFINITIONS & DATA INGESTION (DIRECTLY LINKED TO P02 EXPORTS)
% =========================================================================
name2proj = 'MIMO_C77_Pond_lowSlope_21min_20260513_115401';
project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';

% Establish clear path tracking mirroring your core pipeline structure
export_dir = fullfile(project_root, 'D00_sample_data', 'real', name2proj, 'export_xxx');

% NEW DIRECTORY DESIGNATION FOR YOUR REPORT FIGURES
sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis_report');
path_tuned_features   = fullfile(export_dir, 'tuned_features.mat');

% Targets for our plotting dataset
mat_data_file = fullfile(sensitivity_export_dir, 'sensitivity_sweep_curves.mat');
if ~isfile(mat_data_file)
    error('Target matrix sweep data file "%s" was not found inside the report directory.', mat_data_file);
end

features = load(path_tuned_features);
frames_axis = datetime(features.exported_time_axis); 
frames_axis = frames_axis(:)'; % Ensure row vector for seamless matrix patching

% --- Master Canvas Frame Properties ---
canvas_position   = [100, 100, 1200, 850];    % [Left, Bottom, Width, Height] in pixels
background_color  = 'w';                      % Primary canvas background tint ('w' = white)

% --- Global Text Scaling, Weights, and Fonts ---
font_name         = 'Helvetica';              % Font family selection
font_size_sgtitle = 14;                       % Global overall figure super-title font size
font_size_titles  = 11;                       % Subplot titles font size
font_size_axes    = 10;                       % Axis ticks and labels font size
font_size_legend  = 9;                        % Inside-plot legend box font size
text_weight       = 'bold';                   % Font styling flag ('bold', 'normal')
text_color        = 'k';                      % Global text color channel ('k' = black)

% --- Data Curve Aesthetics ---
line_width        = 2.2;                      % Thickness of time-series data lines

% --- Custom High-Contrast Color Palette (UPDATED: RED, GREEN, BLUE) ---
color_palette = [ ...
    1.000, 0.000, 0.000; ...   % Variant 1: Pure Red
    0.000, 0.600, 0.000; ...   % Variant 2: Vibrant Green
    0.000, 0.000, 1.000     ...   % Variant 3: Pure Blue
];

% --- Axis Limits & Padding Management ---
y_axis_padding_pct = 0.20;                    % Added vertical spacing margin above/below max limits
x_label_string     = 'Acquisition Time';      % Updated to reflect DateTime values
y_label_string     = 'Delta Area Deviation (m^2)';

% --- Layout Margins (LooseInset Padding Modifiers) ---
top_margin_pad     = 0.03;                    % Vertical breathing room tracking modifier
bottom_margin_pad  = 0.01;                    % Base line height buffer allocation

%% =========================================================================
%% CORE EXECUTION: INGEST DATA & BUILD GRAPHICS
%% =========================================================================
% Ingest matrix values safely into workspace memory
data_payload = load(mat_data_file);

% Unpack primary curves
curves_fixed_nom  = data_payload.curves_fixed_nom;
curves_kmeans_nom = data_payload.curves_kmeans_nom;
curves_fixed_det  = data_payload.curves_fixed_det;
curves_kmeans_det = data_payload.curves_kmeans_det;
fixed_sweeps_nom  = data_payload.fixed_sweeps_nom;
fixed_sweeps_det  = data_payload.fixed_sweeps_det;
kmeans_windows    = data_payload.kmeans_windows;

% DEFENSIVE FALLBACK: Check and reconstruct V_net arrays if missing from file
if isfield(data_payload, 'wnet_fixed_nom')
    wnet_fixed_nom  = data_payload.wnet_fixed_nom;
    wnet_kmeans_nom = data_payload.wnet_kmeans_nom;
    wnet_fixed_det  = data_payload.wnet_fixed_det;
    wnet_kmeans_det = data_payload.wnet_kmeans_det;
else
    warning('V_net variables missing from source MAT file. Reconstructing mathematically from transition layers...');
    wnet_fixed_nom  = data_payload.encroachment_fixed_nom  - data_payload.retreat_fixed_nom;
    wnet_fixed_det  = data_payload.encroachment_fixed_det  - data_payload.retreat_fixed_det;
    wnet_kmeans_nom = data_payload.encroachment_kmeans_nom - data_payload.retreat_kmeans_nom;
    wnet_kmeans_det = data_payload.encroachment_kmeans_det - data_payload.retreat_kmeans_det;
end

% Instantiate polished window frame
fig_sweep = figure('Name', 'Parametric Sensitivity Canvas Customizer', ...
                   'Units', 'pixels', 'Position', canvas_position, 'Color', background_color);

% Compute dynamic shared Y-axis parameters securely
global_max_sweep = max([curves_fixed_nom(:); curves_kmeans_nom(:); curves_fixed_det(:); curves_kmeans_det(:); 10]);
global_min_sweep = min([curves_fixed_nom(:); curves_kmeans_nom(:); curves_fixed_det(:); curves_kmeans_det(:); -10]);
padding_sweep    = y_axis_padding_pct * max(global_max_sweep, abs(global_min_sweep));
shared_ylim_sweep = [global_min_sweep - padding_sweep, global_max_sweep + padding_sweep];

% Dynamic x-axis configuration boundaries
shared_xlim_sweep = [min(frames_axis), max(frames_axis)];

% -------------------------------------------------------------------------
% SUBPLOT 1: NOMINAL STREAM — FIXED THRESHOLDS
% -------------------------------------------------------------------------
ax1 = subplot(2,2,1); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
set(ax1, 'Color', background_color);
for idx = 1:3
    plot(ax1, frames_axis, curves_fixed_nom(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(ax1, shared_ylim_sweep); xlim(ax1, shared_xlim_sweep); xtickformat(ax1, 'HH:mm');
title(ax1, 'Nominal Stream: Fixed Threshold Variations', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax1, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(ax1, y_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes);
labels_nom = cell(1,3); 
for idx = 1:3, labels_nom{idx} = sprintf('\\gamma = %.3f', fixed_sweeps_nom(idx)); end
legend(ax1, labels_nom, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% SUBPLOT 2: NOMINAL STREAM — ADAPTIVE WINDOWS
% -------------------------------------------------------------------------
ax2 = subplot(2,2,2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
set(ax2, 'Color', background_color);
for idx = 1:3
    plot(ax2, frames_axis, curves_kmeans_nom(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(ax2, shared_ylim_sweep); xlim(ax2, shared_xlim_sweep); xtickformat(ax2, 'HH:mm');
title(ax2, 'Nominal Stream: Adaptive Filtering Windows', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax2, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(ax2, y_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes);
labels_w1 = cell(1,3); 
for idx = 1:3, labels_w1{idx} = sprintf('Window = %d Frames', kmeans_windows(idx)); end
legend(ax2, labels_w1, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% SUBPLOT 3: DETRENDED STREAM — FIXED THRESHOLDS
% -------------------------------------------------------------------------
ax3 = subplot(2,2,3); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
set(ax3, 'Color', background_color);
for idx = 1:3
    plot(ax3, frames_axis, curves_fixed_det(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(ax3, shared_ylim_sweep); xlim(ax3, shared_xlim_sweep); xtickformat(ax3, 'HH:mm');
title(ax3, 'Detrended Stream: Fixed Threshold Variations', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax3, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(ax3, y_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes);
labels_det = cell(1,3); 
for idx = 1:3, labels_det{idx} = sprintf('\\gamma = %.3f', fixed_sweeps_det(idx)); end
legend(ax3, labels_det, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% SUBPLOT 4: DETRENDED STREAM — ADAPTIVE WINDOWS
% -------------------------------------------------------------------------
ax4 = subplot(2,2,4); hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');
set(ax4, 'Color', background_color);
for idx = 1:3
    plot(ax4, frames_axis, curves_kmeans_det(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(ax4, shared_ylim_sweep); xlim(ax4, shared_xlim_sweep); xtickformat(ax4, 'HH:mm');
title(ax4, 'Detrended Stream: Adaptive Filtering Windows', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(ax4, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(ax4, y_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes);
legend(ax4, labels_w1, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

%% =========================================================================
%% MASTER GLOBAL CANVAS OPTIMIZATIONS (UNIFIED TITLES & MARGIN ADJUSTMENTS)
%% =========================================================================
all_axes = [ax1, ax2, ax3, ax4];
for i = 1:length(all_axes)
    set(all_axes(i), 'FontName', font_name, 'FontSize', font_size_axes, ...
                     'XColor', text_color, 'YColor', text_color, 'Layer', 'top');
    
    % Inject structural padding to secure axis boundaries against clipping errors
    tight_inset = get(all_axes(i), 'TightInset');
    set(all_axes(i), 'LooseInset', tight_inset + [0, bottom_margin_pad, 0, top_margin_pad]);
    
    % Strip secondary dynamic calendar labels from cluttering the timeline rows
    all_axes(i).XAxis.SecondaryLabelFormat = '';
end

% Formulate overarching descriptive clean super-title
master_title_string = sprintf('Pipeline Parametric Sensitivity Matrix Sweeps  |  Project: %s', name2proj);
sgtitle(fig_sweep, master_title_string, 'FontName', font_name, 'FontSize', font_size_sgtitle, ...
        'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

%% =========================================================================
%% SAVE FINAL OPTIMIZED IMAGE
%% =========================================================================
export_filename = fullfile(sensitivity_export_dir, 'optimized_parametric_sensitivity_sweeps2.png');
saveas(fig_sweep, export_filename);
close(fig_sweep);
fprintf('✔ Visually polished sensitivity dashboard exported successfully as: "%s"\n', export_filename);

%% =========================================================================
%% COMPANION EXECUTION: GENERATE V_NET METRICS SENSITIVITY CANVAS
%% =========================================================================
% Instantiate secondary window frame for Net Areal Transition Proxies
fig_wnet = figure('Name', 'Wnet Sensitivity Canvas Customizer', ...
                  'Units', 'pixels', 'Position', canvas_position, 'Color', background_color);

% Compute localized shared axis bounds specific to V_net magnitudes
global_max_wnet = max([wnet_fixed_nom(:); wnet_kmeans_nom(:); wnet_fixed_det(:); wnet_kmeans_det(:); 10]);
global_min_wnet = min([wnet_fixed_nom(:); wnet_kmeans_nom(:); wnet_fixed_det(:); wnet_kmeans_det(:); -10]);
padding_wnet    = y_axis_padding_pct * max(global_max_wnet, abs(global_min_wnet));
shared_ylim_wnet = [global_min_wnet - padding_wnet, global_max_wnet + padding_wnet];
y_label_wnet     = 'Net Areal Transition W_{net} (m^2)';

% -------------------------------------------------------------------------
% V_NET SUBPLOT 1: NOMINAL STREAM — FIXED THRESHOLDS
% -------------------------------------------------------------------------
vn_ax1 = subplot(2,2,1); hold(vn_ax1, 'on'); grid(vn_ax1, 'on'); box(vn_ax1, 'on');
set(vn_ax1, 'Color', background_color);
for idx = 1:3
    plot(vn_ax1, frames_axis, wnet_fixed_nom(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(vn_ax1, shared_ylim_wnet); xlim(vn_ax1, shared_xlim_sweep); xtickformat(vn_ax1, 'HH:mm');
title(vn_ax1, 'Nominal Stream: Fixed Threshold W_{net} Sweeps', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(vn_ax1, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(vn_ax1, y_label_wnet, 'FontWeight', text_weight, 'FontSize', font_size_axes);
legend(vn_ax1, labels_nom, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% V_NET SUBPLOT 2: NOMINAL STREAM — ADAPTIVE WINDOWS
% -------------------------------------------------------------------------
vn_ax2 = subplot(2,2,2); hold(vn_ax2, 'on'); grid(vn_ax2, 'on'); box(vn_ax2, 'on');
set(vn_ax2, 'Color', background_color);
for idx = 1:3
    plot(vn_ax2, frames_axis, wnet_kmeans_nom(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(vn_ax2, shared_ylim_wnet); xlim(vn_ax2, shared_xlim_sweep); xtickformat(vn_ax2, 'HH:mm');
title(vn_ax2, 'Nominal Stream: Adaptive Filtering Window W_{net} Sweeps', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(vn_ax2, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(vn_ax2, y_label_wnet, 'FontWeight', text_weight, 'FontSize', font_size_axes);
legend(vn_ax2, labels_w1, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% V_NET SUBPLOT 3: DETRENDED STREAM — FIXED THRESHOLDS
% -------------------------------------------------------------------------
vn_ax3 = subplot(2,2,3); hold(vn_ax3, 'on'); grid(vn_ax3, 'on'); box(vn_ax3, 'on');
set(vn_ax3, 'Color', background_color);
for idx = 1:3
    plot(vn_ax3, frames_axis, wnet_fixed_det(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(vn_ax3, shared_ylim_wnet); xlim(vn_ax3, shared_xlim_sweep); xtickformat(vn_ax3, 'HH:mm');
title(vn_ax3, 'Detrended Stream: Fixed Threshold W_{net} Sweeps', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(vn_ax3, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(vn_ax3, y_label_wnet, 'FontWeight', text_weight, 'FontSize', font_size_axes);
legend(vn_ax3, labels_det, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

% -------------------------------------------------------------------------
% V_NET SUBPLOT 4: DETRENDED STREAM — ADAPTIVE WINDOWS
% -------------------------------------------------------------------------
vn_ax4 = subplot(2,2,4); hold(vn_ax4, 'on'); grid(vn_ax4, 'on'); box(vn_ax4, 'on');
set(vn_ax4, 'Color', background_color);
for idx = 1:3
    plot(vn_ax4, frames_axis, wnet_kmeans_det(:, idx), '-', ...
         'Color', color_palette(idx, :), 'LineWidth', line_width);
end
ylim(vn_ax4, shared_ylim_wnet); xlim(vn_ax4, shared_xlim_sweep); xtickformat(vn_ax4, 'HH:mm');
title(vn_ax4, 'Detrended Stream: Adaptive Filtering Window W_{net} Sweeps', 'FontSize', font_size_titles, 'FontWeight', text_weight, 'Color', text_color);
xlabel(vn_ax4, x_label_string, 'FontWeight', text_weight, 'FontSize', font_size_axes); 
ylabel(vn_ax4, y_label_wnet, 'FontWeight', text_weight, 'FontSize', font_size_axes);
legend(vn_ax4, labels_w1, 'Location', 'best', 'FontSize', font_size_legend, 'TextColor', text_color, 'Color', background_color);

%% =========================================================================
%% MASTER METRIC CANVAS OPTIMIZATIONS
%% =========================================================================
all_wnet_axes = [vn_ax1, vn_ax2, vn_ax3, vn_ax4];
for i = 1:length(all_wnet_axes)
    set(all_wnet_axes(i), 'FontName', font_name, 'FontSize', font_size_axes, ...
                          'XColor', text_color, 'YColor', text_color, 'Layer', 'top');
    tight_inset = get(all_wnet_axes(i), 'TightInset');
    set(all_wnet_axes(i), 'LooseInset', tight_inset + [0, bottom_margin_pad, 0, top_margin_pad]);
    all_wnet_axes(i).XAxis.SecondaryLabelFormat = '';
end

master_wnet_title = sprintf('(Net Transition Area) Sensitivity Sweeps  |  Project: %s', name2proj);
sgtitle(fig_wnet, master_wnet_title, 'FontName', font_name, 'FontSize', font_size_sgtitle, ...
        'FontWeight', text_weight, 'Color', text_color, 'Interpreter', 'none');

wnet_export_filename = fullfile(sensitivity_export_dir, 'optimized_wnet_sensitivity_sweeps2.png');
saveas(fig_wnet, wnet_export_filename);
close(fig_wnet);
fprintf('✔ Visually polished V_net dashboard exported successfully as: "%s"\n', wnet_export_filename);