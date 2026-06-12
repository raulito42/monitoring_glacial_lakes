function P04_sensitivity_analysis(config)
% P04_SENSITIVITY_ANALYSIS Runs parametric sweeps and metrics validations.
% FIXED: Preallocates and populates all encroachment, retreat, and W_net tracking 
% matrices across nominal, detrended, fixed, and adaptive processing streams.
    export_dir = config.export_dir;
    name2proj = config.name2proj;
    
    path_tuned_features = fullfile(export_dir, 'tuned_features.mat');
    path_land_mask      = fullfile(export_dir, 'land_mask.mat');
    
    if ~isfile(path_tuned_features) || ~isfile(path_land_mask)
        error('Data mismatch: Ensure P00 and P01 have been executed first!');
    end
    
    % Ingest multi-attribute context structures 
    vars_features = load(path_tuned_features);
    vars_mask = load(path_land_mask);
    
    % Dynamic utility script target registration 
    script_dir = fileparts(mfilename('fullpath'));
    utils_path = fullfile(script_dir, 'utils');
    if exist(utils_path, 'dir') && ~contains(path, utils_path), addpath(utils_path); end
    
    % Intersect spatial tracking zones securely
    if isfield(vars_mask, 'roi_spatial_mask_2d') && isfield(vars_mask, 'narrow_tracking_zone_2d')
        evaluation_universe_mask = vars_mask.narrow_tracking_zone_2d & vars_mask.roi_spatial_mask_2d;
    elseif isfield(vars_mask, 'narrow_tracking_zone_2d')
        evaluation_universe_mask = vars_mask.narrow_tracking_zone_2d;
    else
        error('Essential tracking ribbon configurations missing from land_mask.mat');
    end
    
    num_frames = size(vars_features.exported_coherence, 2);
    grid_pixel_area_m2 = abs(vars_features.XQ(1,2) - vars_features.XQ(1,1)) * abs(vars_features.YQ(2,1) - vars_features.YQ(1,1));
    dbscan_min_pts = 3; 
    ribbon_indices = find(evaluation_universe_mask == 1); 
    
    sensitivity_export_dir = fullfile(export_dir, 'sensitivity_analysis_report');
    if ~exist(sensitivity_export_dir, 'dir'), mkdir(sensitivity_export_dir); end
    
    % Load configured baseline anchors from profile parameters
    base_thresh_nom = config.thresh_nom(1);
    base_thresh_det = config.thresh_det(1);
    default_temp_window = 5;
    
    color_map = [0.000, 0.447, 0.741; ... % Blue
                 0.850, 0.325, 0.098; ... % Orange
                 1.000, 0.000, 0.000];    % Red
    
    % -------------------------------------------------------------------------
    % --- SWEEP MODULE A: FIXED THRESHOLDS VARIATION + SPATIAL PROXIES ---
    % -------------------------------------------------------------------------
    fixed_sweeps_nom = [base_thresh_nom - 0.05, base_thresh_nom, base_thresh_nom + 0.05];
    fixed_sweeps_det = [base_thresh_det - 0.15, base_thresh_det, base_thresh_det + 0.15];
    
    curves_fixed_nom = zeros(num_frames, 3);
    curves_fixed_det = zeros(num_frames, 3);
    
    rej_fixed_nom_accum = zeros(num_frames, 3);
    rej_fixed_det_accum = zeros(num_frames, 3);
    
    % PREALLOCATION FIXED: Dynamic Transition Buffers & W_net
    encroachment_fixed_nom = zeros(num_frames, 3);
    retreat_fixed_nom      = zeros(num_frames, 3);
    wnet_fixed_nom         = zeros(num_frames, 3);
    
    encroachment_fixed_det = zeros(num_frames, 3);
    retreat_fixed_det      = zeros(num_frames, 3);
    wnet_fixed_det         = zeros(num_frames, 3);
    
    for t = 1:3
        % A1. Nominal Coherence Stream Sweep Execution Loop
        t_nom = fixed_sweeps_nom(t);
        prev_mask = [];
        for f = 1:num_frames
            s_f = max(1, f - floor(default_temp_window/2));
            e_f = min(num_frames, f + floor(default_temp_window/2));
            frame_coh = median(vars_features.exported_coherence(:, s_f:e_f), 2);
            grid_coh = griddata(vars_features.x_axis, vars_features.y_axis, double(frame_coh), vars_features.XQ, vars_features.YQ, 'linear');
            grid_coh(isnan(grid_coh)) = 1; 
            raw_mask = (grid_coh < t_nom) & evaluation_universe_mask;
            cleaned_mask = apply_dbscan_filter(raw_mask, vars_features.XQ, vars_features.YQ, dbscan_min_pts);
            curves_fixed_nom(f, t) = sum(cleaned_mask, 'all') * grid_pixel_area_m2;
            
            raw_pts = sum(raw_mask, 'all');
            rej_fixed_nom_accum(f, t) = (raw_pts - sum(cleaned_mask, 'all')) / (raw_pts + eps) * 100;
            
            if f == 1
                encroachment_fixed_nom(f, t) = 0;
                retreat_fixed_nom(f, t)      = 0;
                wnet_fixed_nom(f, t)         = 0;
            else
                encroach_pixels = (prev_mask == 0) & (cleaned_mask == 1);
                encroachment_fixed_nom(f, t) = sum(encroach_pixels, 'all') * grid_pixel_area_m2;
                
                retreat_pixels = (prev_mask == 1) & (cleaned_mask == 0);
                retreat_fixed_nom(f, t) = sum(retreat_pixels, 'all') * grid_pixel_area_m2;
                
                wnet_fixed_nom(f, t) = encroachment_fixed_nom(f, t) - retreat_fixed_nom(f, t);
            end
            prev_mask = cleaned_mask;
        end
        curves_fixed_nom(:, t) = curves_fixed_nom(:, t) - curves_fixed_nom(1, t);
        
        % A2. Detrended Coherence Stream Sweep Execution Loop
        t_det = fixed_sweeps_det(t);
        prev_mask = [];
        for f = 1:num_frames
            s_f = max(1, f - floor(default_temp_window/2));
            e_f = min(num_frames, f + floor(default_temp_window/2));
            frame_det = median(vars_features.exported_detrended_coh(:, s_f:e_f), 2);
            grid_det = griddata(vars_features.x_axis, vars_features.y_axis, double(frame_det), vars_features.XQ, vars_features.YQ, 'linear');
            grid_det(isnan(grid_det)) = 1; 
            raw_mask = (grid_det < t_det) & evaluation_universe_mask;
            cleaned_mask = apply_dbscan_filter(raw_mask, vars_features.XQ, vars_features.YQ, dbscan_min_pts);
            curves_fixed_det(f, t) = sum(cleaned_mask, 'all') * grid_pixel_area_m2;
            
            raw_pts = sum(raw_mask, 'all');
            rej_fixed_det_accum(f, t) = (raw_pts - sum(cleaned_mask, 'all')) / (raw_pts + eps) * 100;
            
            if f == 1
                encroachment_fixed_det(f, t) = 0;
                retreat_fixed_det(f, t)      = 0;
                wnet_fixed_det(f, t)         = 0;
            else
                encroach_pixels = (prev_mask == 0) & (cleaned_mask == 1);
                encroachment_fixed_det(f, t) = sum(encroach_pixels, 'all') * grid_pixel_area_m2;
                
                retreat_pixels = (prev_mask == 1) & (cleaned_mask == 0);
                retreat_fixed_det(f, t) = sum(retreat_pixels, 'all') * grid_pixel_area_m2;
                
                wnet_fixed_det(f, t) = encroachment_fixed_det(f, t) - retreat_fixed_det(f, t);
            end
            prev_mask = cleaned_mask;
        end
        curves_fixed_det(:, t) = curves_fixed_det(:, t) - curves_fixed_det(1, t);
    end
    
    % -------------------------------------------------------------------------
    % --- SWEEP MODULE B: ADAPTIVE SMOOTHING WINDOW VARIATION + SPATIAL PROXIES ---
    % -------------------------------------------------------------------------
    kmeans_windows = [1, 5, 9]; 
    curves_kmeans_nom = zeros(num_frames, 3);
    curves_kmeans_det = zeros(num_frames, 3);
    
    rej_kmeans_nom_accum = zeros(num_frames, 3);
    rej_kmeans_det_accum = zeros(num_frames, 3);
    weights = [2.0, 0.5, 0.5];
    
    % PREALLOCATION FIXED: Dynamic Adaptive Transition Buffers & W_net
    encroachment_kmeans_nom = zeros(num_frames, 3);
    retreat_kmeans_nom      = zeros(num_frames, 3);
    wnet_kmeans_nom         = zeros(num_frames, 3);
    
    encroachment_kmeans_det = zeros(num_frames, 3);
    retreat_kmeans_det      = zeros(num_frames, 3);
    wnet_kmeans_det         = zeros(num_frames, 3);
    
    for w = 1:3
        current_window = kmeans_windows(w);
        prev_mask_nom = [];
        prev_mask_det = [];
        for f = 1:num_frames
            s_f = max(1, f - floor(current_window/2));
            e_f = min(num_frames, f + floor(current_window/2));
            
            % --- B1. Nominal Adaptive Stream Sweep ---
            f_coh = median(vars_features.exported_coherence(:, s_f:e_f), 2);
            g_coh = griddata(vars_features.x_axis, vars_features.y_axis, double(f_coh), vars_features.XQ, vars_features.YQ, 'linear');
            g_coh(isnan(g_coh)) = 1;
            
            f_amp = median(vars_features.exported_amplitude(:, s_f:e_f), 2);
            g_amp = griddata(vars_features.x_axis, vars_features.y_axis, double(f_amp), vars_features.XQ, vars_features.YQ, 'linear');
            g_amp(isnan(g_amp)) = 0;
            
            f_pvar = median(vars_features.exported_phase_var(:, s_f:e_f), 2);
            g_pvar = griddata(vars_features.x_axis, vars_features.y_axis, double(f_pvar), vars_features.XQ, vars_features.YQ, 'linear');
            g_pvar(isnan(g_pvar)) = 0;
            
            if length(ribbon_indices) >= 3
                F_Mat_nom = [double(g_coh(ribbon_indices)), 20*log10(abs(double(g_amp(ribbon_indices)))+eps), double(g_pvar(ribbon_indices))];
                F_Norm_nom = zscore(real(F_Mat_nom)) .* weights;
                [c_idx, ~] = kmeans(F_Norm_nom, 3, 'Distance', 'sqeuclidean', 'Replicates', 2, 'Options', statset('MaxIter', 100));
                
                c_means = zeros(3, 1);
                for k = 1:3, c_means(k) = mean(F_Mat_nom(c_idx == k, 1)); end
                [~, s_ord] = sort(c_means, 'ascend');
                
                raw_grid_km = false(size(vars_features.XQ));
                raw_grid_km(ribbon_indices(c_idx == s_ord(1))) = true;
                cleaned_km = apply_dbscan_filter(raw_grid_km, vars_features.XQ, vars_features.YQ, dbscan_min_pts);
                curves_kmeans_nom(f, w) = sum(cleaned_km, 'all') * grid_pixel_area_m2;
                
                raw_pts = sum(raw_grid_km, 'all');
                rej_kmeans_nom_accum(f, w) = (raw_pts - sum(cleaned_km, 'all')) / (raw_pts + eps) * 100;
                
                if f == 1
                    encroachment_kmeans_nom(f, w) = 0;
                    retreat_kmeans_nom(f, w)      = 0;
                    wnet_kmeans_nom(f, w)         = 0;
                else
                    encroach_pixels = (prev_mask_nom == 0) & (cleaned_km == 1);
                    encroachment_kmeans_nom(f, w) = sum(encroach_pixels, 'all') * grid_pixel_area_m2;
                    
                    retreat_pixels = (prev_mask_nom == 1) & (cleaned_km == 0);
                    retreat_kmeans_nom(f, w) = sum(retreat_pixels, 'all') * grid_pixel_area_m2;
                    
                    wnet_kmeans_nom(f, w) = encroachment_kmeans_nom(f, w) - retreat_kmeans_nom(f, w);
                end
                prev_mask_nom = cleaned_km;
            end
            
            % --- B2. Detrended Adaptive Stream Sweep ---
            f_coh_d = median(vars_features.exported_detrended_coh(:, s_f:e_f), 2);
            g_coh_d = griddata(vars_features.x_axis, vars_features.y_axis, double(f_coh_d), vars_features.XQ, vars_features.YQ, 'linear');
            g_coh_d(isnan(g_coh_d)) = 1;
            
            f_amp_d = median(vars_features.exported_detrended_amp(:, s_f:e_f), 2);
            g_amp_d = griddata(vars_features.x_axis, vars_features.y_axis, double(f_amp_d), vars_features.XQ, vars_features.YQ, 'linear');
            g_amp_d(isnan(g_amp_d)) = 0;
            
            f_pvar_d = median(vars_features.exported_detrended_pvar(:, s_f:e_f), 2);
            g_pvar_d = griddata(vars_features.x_axis, vars_features.y_axis, double(f_pvar_d), vars_features.XQ, vars_features.YQ, 'linear');
            g_pvar_d(isnan(g_pvar_d)) = 0;
            
            if length(ribbon_indices) >= 3
                F_Mat_det = [double(g_coh_d(ribbon_indices)), double(g_amp_d(ribbon_indices)), double(g_pvar_d(ribbon_indices))];
                F_Norm_det = zscore(real(F_Mat_det)) .* weights;
                [c_idx_d, ~] = kmeans(F_Norm_det, 3, 'Distance', 'sqeuclidean', 'Replicates', 2, 'Options', statset('MaxIter', 100));
                
                c_means_d = zeros(3, 1);
                for k = 1:3, c_means_d(k) = mean(F_Mat_det(c_idx_d == k, 1)); end
                [~, s_ord_d] = sort(c_means_d, 'ascend');
                
                raw_grid_km_d = false(size(vars_features.XQ));
                raw_grid_km_d(ribbon_indices(c_idx_d == s_ord_d(1))) = true;
                cleaned_km_d = apply_dbscan_filter(raw_grid_km_d, vars_features.XQ, vars_features.YQ, dbscan_min_pts);
                curves_kmeans_det(f, w) = sum(cleaned_km_d, 'all') * grid_pixel_area_m2;
                
                raw_pts = sum(raw_grid_km_d, 'all');
                rej_kmeans_det_accum(f, w) = (raw_pts - sum(cleaned_km_d, 'all')) / (raw_pts + eps) * 100;
                
                if f == 1
                    encroachment_kmeans_det(f, w) = 0;
                    retreat_kmeans_det(f, w)      = 0;
                    wnet_kmeans_det(f, w)         = 0;
                else
                    encroach_pixels = (prev_mask_det == 0) & (cleaned_km_d == 1);
                    encroachment_kmeans_det(f, w) = sum(encroach_pixels, 'all') * grid_pixel_area_m2;
                    
                    retreat_pixels = (prev_mask_det == 1) & (cleaned_km_d == 0);
                    retreat_kmeans_det(f, w) = sum(retreat_pixels, 'all') * grid_pixel_area_m2;
                    
                    wnet_kmeans_det(f, w) = encroachment_kmeans_det(f, w) - retreat_kmeans_det(f, w);
                end
                prev_mask_det = cleaned_km_d;
            end
        end
        curves_kmeans_nom(:, w) = curves_kmeans_nom(:, w) - curves_kmeans_nom(1, w);
        curves_kmeans_det(:, w) = curves_kmeans_det(:, w) - curves_kmeans_det(1, w);
    end
    
    % =========================================================================
    % --- SWEEP MODULE C: MULTI-LEVEL COMPARATIVE METRIC CALCULATIONS ---
    % =========================================================================
    stats_fixed_nom = struct('snr', zeros(1,3), 'rmsd', zeros(1,3), 'p2p', zeros(1,3), 'jitter', zeros(1,3), 'rej', zeros(1,3));
    stats_fixed_det = struct('snr', zeros(1,3), 'rmsd', zeros(1,3), 'p2p', zeros(1,3), 'jitter', zeros(1,3), 'rej', zeros(1,3));
    stats_kmeans_nom = struct('snr', zeros(1,3), 'rmsd', zeros(1,3), 'p2p', zeros(1,3), 'jitter', zeros(1,3), 'rej', zeros(1,3));
    stats_kmeans_det = struct('snr', zeros(1,3), 'rmsd', zeros(1,3), 'p2p', zeros(1,3), 'jitter', zeros(1,3), 'rej', zeros(1,3));
    
    for idx = 1:3
        sig = curves_fixed_nom(:, idx); trend = medfilt1(sig, 5); noise = sig - trend;
        stats_fixed_nom.snr(idx)    = 10 * log10(var(trend) / (var(noise) + eps));
        stats_fixed_nom.rmsd(idx)   = sqrt(mean(sig.^2));
        stats_fixed_nom.p2p(idx)    = max(sig) - min(sig);
        stats_fixed_nom.jitter(idx) = mean(abs(diff(sig)));
        stats_fixed_nom.rej(idx)    = mean(rej_fixed_nom_accum(:, idx));
        
        sig = curves_fixed_det(:, idx); trend = medfilt1(sig, 5); noise = sig - trend;
        stats_fixed_det.snr(idx)    = 10 * log10(var(trend) / (var(noise) + eps));
        stats_fixed_det.rmsd(idx)   = sqrt(mean(sig.^2));
        stats_fixed_det.p2p(idx)    = max(sig) - min(sig);
        stats_fixed_det.jitter(idx) = mean(abs(diff(sig)));
        stats_fixed_det.rej(idx)    = mean(rej_fixed_det_accum(:, idx));
        
        sig = curves_kmeans_nom(:, idx); trend = medfilt1(sig, 5); noise = sig - trend;
        stats_kmeans_nom.snr(idx)    = 10 * log10(var(trend) / (var(noise) + eps));
        stats_kmeans_nom.rmsd(idx)   = sqrt(mean(sig.^2));
        stats_kmeans_nom.p2p(idx)    = max(sig) - min(sig);
        stats_kmeans_nom.jitter(idx) = mean(abs(diff(sig)));
        stats_kmeans_nom.rej(idx)    = mean(rej_kmeans_nom_accum(:, idx));
        
        sig = curves_kmeans_det(:, idx); trend = medfilt1(sig, 5); noise = sig - trend;
        stats_kmeans_det.snr(idx)    = 10 * log10(var(trend) / (var(noise) + eps));
        stats_kmeans_det.rmsd(idx)   = sqrt(mean(sig.^2));
        stats_kmeans_det.p2p(idx)    = max(sig) - min(sig);
        stats_kmeans_det.jitter(idx) = mean(abs(diff(sig)));
        stats_kmeans_det.rej(idx)    = mean(rej_kmeans_det_accum(:, idx));
    end

    % -------------------------------------------------------------------------
    % --- SWEEP MODULE D: STYLIZED VISUALIZATION AND DATA EXPORTS ---
    % -------------------------------------------------------------------------
    frames_axis = 1:num_frames;
    fig_sweep = figure('Name', 'Parametric Sensitivity Sweeps', 'Units', 'pixels', 'Position', [100, 100, 1100, 850], 'Color', 'w');
    clean_proj_name = strrep(name2proj, '_', '\_');
    
    global_max_sweep = max([curves_fixed_nom(:); curves_kmeans_nom(:); curves_fixed_det(:); curves_kmeans_det(:); 10]);
    global_min_sweep = min([curves_fixed_nom(:); curves_kmeans_nom(:); curves_fixed_det(:); curves_kmeans_det(:); -10]);
    padding_sweep = 0.15 * max(global_max_sweep, abs(global_min_sweep));
    shared_ylim_sweep = [global_min_sweep - padding_sweep, global_max_sweep + padding_sweep];
    
    subplot(2,2,1); hold on; set(gca, 'ColorOrder', color_map);
    plot(frames_axis, curves_fixed_nom, 'LineWidth', 1.8); grid on; box on; ylim(shared_ylim_sweep);
    title({'Nominal Stream: Fixed Threshold Variations', ['Dataset: ', clean_proj_name]}, 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Temporal Frame Sequence'); ylabel('Delta Area Deviation (m^2)');
    labels_nom = cell(1,3); for idx = 1:3, labels_nom{idx} = sprintf('\\gamma = %.3f', fixed_sweeps_nom(idx)); end
    legend(labels_nom, 'Location', 'best');
    
    subplot(2,2,2); hold on; set(gca, 'ColorOrder', color_map);
    plot(frames_axis, curves_kmeans_nom, 'LineWidth', 1.8); grid on; box on; ylim(shared_ylim_sweep);
    title({'Nominal Stream: Adaptive Filtering Windows', ['Dataset: ', clean_proj_name]}, 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Temporal Frame Sequence'); ylabel('Delta Area Deviation (m^2)');
    labels_w1 = cell(1,3); for idx = 1:3, labels_w1{idx} = sprintf('Window = %d Frames', kmeans_windows(idx)); end
    legend(labels_w1, 'Location', 'best');
    
    subplot(2,2,3); hold on; set(gca, 'ColorOrder', color_map);
    plot(frames_axis, curves_fixed_det, 'LineWidth', 1.8); grid on; box on; ylim(shared_ylim_sweep);
    title({'Detrended Stream: Fixed Threshold Variations', ['Dataset: ', clean_proj_name]}, 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Temporal Frame Sequence'); ylabel('Delta Area Deviation (m^2)');
    labels_det = cell(1,3); for idx = 1:3, labels_det{idx} = sprintf('\\gamma = %.3f', fixed_sweeps_det(idx)); end
    legend(labels_det, 'Location', 'best');
    
    subplot(2,2,4); hold on; set(gca, 'ColorOrder', color_map);
    plot(frames_axis, curves_kmeans_det, 'LineWidth', 1.8); grid on; box on; ylim(shared_ylim_sweep);
    title({'Detrended Stream: Adaptive Filtering Windows', ['Dataset: ', clean_proj_name]}, 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Temporal Frame Sequence'); ylabel('Delta Area Deviation (m^2)');
    legend(labels_w1, 'Location', 'best');
    
    saveas(fig_sweep, fullfile(sensitivity_export_dir, 'parametric_sensitivity_sweeps.png'));
    close(fig_sweep);
    
    % =========================================================================
    % TEXT REPORT EXPORT ENGINE 1: SUMMARY STATS WITH SPATIAL REJECTION
    % =========================================================================
    txt_filename = fullfile(sensitivity_export_dir, 'pipeline_snr_metrics.txt');
    fid = fopen(txt_filename, 'w');
    if fid ~= -1
        fprintf(fid, '==================================================================================\n');
        fprintf(fid, 'PIPELINE PARAMETRIC SENSITIVITY METRICS REPORT (TEMPORAL + SPATIAL PROXIES)\n');
        fprintf(fid, '==================================================================================\n');
        fprintf(fid, 'Dataset Profile : %s\n', name2proj);
        fprintf(fid, 'Analysis Date   : %s\n\n', datestr(now));
        
        fprintf(fid, '--- 1. NOMINAL STREAM: FIXED THRESHOLD SWEEP EVALUATION ---\n');
        fprintf(fid, 'Threshold Variant      |   SNR (dB) |   RMSD(m2) |   P2P (m2) | Jitter(m2) | Spatial Rej(%%)\n');
        fprintf(fid, '-----------------------------------------------------------------------------------------\n');
        for idx = 1:3
            fprintf(fid, 'gamma = %13.3f | %10.2f | %10.2f | %10.2f | %10.2f | %14.1f%%\n', ...
                fixed_sweeps_nom(idx), stats_fixed_nom.snr(idx), stats_fixed_nom.rmsd(idx), stats_fixed_nom.p2p(idx), stats_fixed_nom.jitter(idx), stats_fixed_nom.rej(idx));
        end
        fprintf(fid, '-----------------------------------------------------------------------------------------\n\n');
        
        fprintf(fid, '--- 2. DETRENDED STREAM: FIXED THRESHOLD SWEEP EVALUATION ---\n');
        fprintf(fid, 'Threshold Variant      |   SNR (dB) |   RMSD(m2) |   P2P (m2) | Jitter(m2) | Spatial Rej(%%)\n');
        fprintf(fid, '-----------------------------------------------------------------------------------------\n');
        for idx = 1:3
            fprintf(fid, 'gamma = %13.3f | %10.2f | %10.2f | %10.2f | %10.2f | %14.1f%%\n', ...
                fixed_sweeps_det(idx), stats_fixed_det.snr(idx), stats_fixed_det.rmsd(idx), stats_fixed_det.p2p(idx), stats_fixed_det.jitter(idx), stats_fixed_det.rej(idx));
        end
        fprintf(fid, '-----------------------------------------------------------------------------------------\n\n');
        
        fprintf(fid, '--- 3. NOMINAL STREAM: ADAPTIVE WINDOW SIZE EVALUATION ---\n');
        fprintf(fid, 'Window Size Variant    |   SNR (dB) |   RMSD(m2) |   P2P (m2) | Jitter(m2) | Spatial Rej(%%)\n');
        fprintf(fid, '-----------------------------------------------------------------------------------------\n');
        for idx = 1:3
            fprintf(fid, 'Window = %11d | %10.2f | %10.2f | %10.2f | %10.2f | %14.1f%%\n', ...
                kmeans_windows(idx), stats_kmeans_nom.snr(idx), stats_kmeans_nom.rmsd(idx), stats_kmeans_nom.p2p(idx), stats_kmeans_nom.jitter(idx), stats_kmeans_nom.rej(idx));
        end
        fprintf(fid, '-----------------------------------------------------------------------------------------\n\n');
        
        fprintf(fid, '--- 4. DETRENDED STREAM: ADAPTIVE WINDOW SIZE EVALUATION ---\n');
        fprintf(fid, 'Window Size Variant    |   SNR (dB) |   RMSD(m2) |   P2P (m2) | Jitter(m2) | Spatial Rej(%%)\n');
        fprintf(fid, '-----------------------------------------------------------------------------------------\n');
        for idx = 1:3
            fprintf(fid, 'Window = %11d | %10.2f | %10.2f | %10.2f | %10.2f | %14.1f%%\n', ...
                kmeans_windows(idx), stats_kmeans_det.snr(idx), stats_kmeans_det.rmsd(idx), stats_kmeans_det.p2p(idx), stats_kmeans_det.jitter(idx), stats_kmeans_det.rej(idx));
        end
        fprintf(fid, '==================================================================================\n');
        fclose(fid);
    end
    
    % =========================================================================
    % SAVE DATA PROFILES (Includes all preallocated transition structures and W_net arrays)
    % =========================================================================
    path_sensitivity_data = fullfile(sensitivity_export_dir, 'sensitivity_sweep_curves.mat');
    save(path_sensitivity_data, 'curves_fixed_nom', 'curves_fixed_det', ...
                                'curves_kmeans_nom', 'curves_kmeans_det', ...
                                'fixed_sweeps_nom', 'fixed_sweeps_det', ...
                                'kmeans_windows', 'num_frames', 'name2proj', ...
                                'stats_fixed_nom', 'stats_fixed_det', ...
                                'stats_kmeans_nom', 'stats_kmeans_det', ...
                                'encroachment_fixed_nom', 'retreat_fixed_nom', ...
                                'encroachment_fixed_det', 'retreat_fixed_det', ...
                                'encroachment_kmeans_nom', 'retreat_kmeans_nom', ...
                                'encroachment_kmeans_det', 'retreat_kmeans_det', ...
                                'wnet_fixed_nom', 'wnet_fixed_det', ...
                                'wnet_kmeans_nom', 'wnet_kmeans_det'); % <-- W_net tracking fully preserved
    fprintf('✔ Dual-metric analytics report saved to: %s\n', sensitivity_export_dir);
    
    if contains(path, utils_path), rmpath(utils_path); end
end