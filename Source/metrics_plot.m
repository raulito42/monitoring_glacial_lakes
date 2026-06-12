clear; clc; close all;

% =========================================================================
% 1. GLOBAL ENVIRONMENT CONFIGURATION
% =========================================================================
project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';

% Vertical syntax format avoids line-continuation ellipse bugs
projects_list = { 
    'MIMO_C77_GS_P1_001_20min_20260519_102536_01300000ms'
    'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms'
    'MIMO_C77_GS_P2_002_15min_20260519_121708_00910000ms'
    'MIMO_C77_GS_P3_001_15min_20260519_130316_00910000ms'
    'MIMO_C77_Pond_lowSlope_21min_ohneCR_20260513_121908'
    'MIMO_C77_Pond_lowSlope_21min_20260513_115401'
};

num_projects = length(projects_list);
compiled_data = cell(num_projects, 1);
short_names = cell(num_projects, 1);
valid_flags = false(num_projects, 1); % Tracks which files actually loaded

% =========================================================================
% 2. DATA INGESTION ENGINE
% =========================================================================
fprintf('Parsing project sensitivity reports...\n');
for p = 1:num_projects
    proj_name = projects_list{p};
    
    if contains(proj_name, 'GS_P1')
        short_names{p} = 'Glacier P1';
    elseif contains(proj_name, 'GS_P2_001')
        short_names{p} = 'Glacier P2 (A)';
    elseif contains(proj_name, 'GS_P2_002')
        short_names{p} = 'Glacier P2 (B)';
    elseif contains(proj_name, 'GS_P3')
        short_names{p} = 'Glacier P3';
    elseif contains(proj_name, 'Pond_lowSlope') && contains(proj_name, 'ohneCR')
        short_names{p} = 'Pond (No CR)';
    elseif contains(proj_name, 'Pond_lowSlope')
        short_names{p} = 'Campus Pond';
    else
        short_names{p} = ['Dataset ' num2str(p)];
    end
    
    % Hardcoded absolute structural lookup path matching your directory tree
    target_mat_path = fullfile(project_root, 'D00_sample_data', 'real', proj_name, 'export_xxx', 'sensitivity_analysis_report', 'sensitivity_sweep_curves.mat');
    
    if ~isfile(target_mat_path)
        warning('File missing for project "%s". Skipping metrics extraction.\nLooked in: %s\n', short_names{p}, target_mat_path);
        continue;
    end
    
    compiled_data{p} = load(target_mat_path);
    valid_flags(p) = true;
    fprintf('✔ Successfully extracted metrics for: %s\n', short_names{p});
end

% Filter list elements to match only files that successfully loaded
active_indices = find(valid_flags);
num_active = length(active_indices);

if num_active == 0
    error('Pipeline Error: Zero data files were loaded. Verify the absolute path strings.');
end

% Strip out skipped/empty indices to keep the visualization clean
plot_names = short_names(active_indices);

% =========================================================================
% 3. ANALYTICAL DATA COMPILATION
% =========================================================================
snr_matrix    = zeros(num_active, 4); 
p2p_matrix    = zeros(num_active, 4);
jitter_matrix = zeros(num_active, 4);

for idx = 1:num_active
    p = active_indices(idx);
    d = compiled_data{p};
    baseline_idx = 2; % Variant 2 / W = 5 frames
    
    % Guard block checking if P04 processing structures are present
    if ~isfield(d, 'stats_fixed_nom')
        error('Data structural error in file %d. "stats_fixed_nom" not found.', p);
    end
    
    % Populating matrix columns: [NomFix, DetFix, NomAdp, DetAdp]
    snr_matrix(idx, 1) = d.stats_fixed_nom.snr(baseline_idx);
    snr_matrix(idx, 2) = d.stats_fixed_det.snr(baseline_idx);
    snr_matrix(idx, 3) = d.stats_kmeans_nom.snr(baseline_idx);
    snr_matrix(idx, 4) = d.stats_kmeans_det.snr(baseline_idx);
    
    p2p_matrix(idx, 1) = d.stats_fixed_nom.p2p(baseline_idx);
    p2p_matrix(idx, 2) = d.stats_fixed_det.p2p(baseline_idx);
    p2p_matrix(idx, 3) = d.stats_kmeans_nom.p2p(baseline_idx);
    p2p_matrix(idx, 4) = d.stats_kmeans_det.p2p(baseline_idx);
    
    jitter_matrix(idx, 1) = d.stats_fixed_nom.jitter(baseline_idx);
    jitter_matrix(idx, 2) = d.stats_fixed_det.jitter(baseline_idx);
    jitter_matrix(idx, 3) = d.stats_kmeans_nom.jitter(baseline_idx);
    jitter_matrix(idx, 4) = d.stats_kmeans_det.jitter(baseline_idx);
end

% Set lower bound floor limits to clean up visual artifacts from any infinite values
snr_matrix(isinf(snr_matrix) | isnan(snr_matrix)) = -10; 

% =========================================================================
% 4. GRAPHICAL PLOTTING AND EXPORT ENGINE
% =========================================================================
fig_summary = figure('Name', 'MIMO-SAR Pipeline Engine Benchmarks', ...
                     'Units', 'pixels', 'Position', [100, 100, 1400, 700], 'Color', 'w');

t = tiledlayout(1, 3, 'TileSpacing', 'loose', 'Padding', 'normal');

engine_colors = [0.145, 0.345, 0.608; ... % Deep Corporate Blue
                 0.424, 0.612, 0.839; ... % Muted Ice Blue
                 0.886, 0.345, 0.133; ... % Industrial Orange
                 0.957, 0.643, 0.376];    % Sandy Coral

engine_labels = {'Nominal Fixed \gamma', 'Detrended Fixed \gamma', ...
                 'Nominal Adaptive (W=5)', 'Detrended Adaptive (W=5)'};

% --- PANEL 1: SNR COMPARISON ---
nexttile;
b1 = bar(snr_matrix, 'grouped', 'EdgeColor', 'none');
for k = 1:4, b1(k).FaceColor = engine_colors(k, :); end
grid on; box on; ylabel('Signal-to-Noise Ratio (dB)', 'FontWeight', 'bold');
set(gca, 'XTickLabel', plot_names, 'FontSize', 9, 'XTickLabelRotation', 30);
title('Pipeline Tracking Stability (SNR)', 'FontSize', 12, 'FontWeight', 'bold');

% --- PANEL 2: MIN-MAX RANGE (P2P) ---
nexttile;
b2 = bar(p2p_matrix, 'grouped', 'EdgeColor', 'none');
for k = 1:4, b2(k).FaceColor = engine_colors(k, :); end
grid on; box on; ylabel('Absolute Area Dynamic Range (m^2)', 'FontWeight', 'bold');
set(gca, 'XTickLabel', plot_names, 'FontSize', 9, 'XTickLabelRotation', 30);
title('Maximum Boundary Envelope Spread', 'FontSize', 12, 'FontWeight', 'bold');

% --- PANEL 3: JITTER (VOLATILITY) ---
nexttile;
b3 = bar(jitter_matrix, 'grouped', 'EdgeColor', 'none');
for k = 1:4, b3(k).FaceColor = engine_colors(k, :); end
grid on; box on; ylabel('Frame-by-Frame Volatility Jitter (m^2)', 'FontWeight', 'bold');
set(gca, 'XTickLabel', plot_names, 'FontSize', 9, 'XTickLabelRotation', 30);
title('High-Frequency Boundary Flicker', 'FontSize', 12, 'FontWeight', 'bold');

% Global structural layout formatting
title(t, 'MIMO-SAR Tracking Engine Performance Summary (All Experimental Deployments)', 'FontSize', 15, 'FontWeight', 'bold');
hl = legend(engine_labels, 'Orientation', 'horizontal');
hl.Layout.Tile = 'south'; 
hl.Box = 'off';
hl.FontSize = 11;

drawnow;

% Export graphic asset back to the parent directory root
save_target = fullfile(project_root, 'compiled_pipeline_performance_overview.png');
saveas(fig_summary, save_target);
fprintf('\n✔ Process complete! Overview image compiled for all active datasets.\n➡ Output Location: %s\n', save_target);