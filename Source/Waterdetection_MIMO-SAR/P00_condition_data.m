function P00_condition_data(config)
    name2proj = config.name2proj;
    project_root = config.project_root;
    export_dir = config.export_dir;
    path2proj = fullfile(project_root, 'D00_sample_data', 'real', name2proj);
    path2mat  = fullfile(path2proj, '03_PSI_Interfero', '01_SLC_Filt.mat');
    
    if ~isfile(path2mat)
        error('Target complex SLC data matrix not found at: %s', path2mat);
    end
    
    if ~exist(export_dir, 'dir')
        mkdir(export_dir);
    end
    
    % =========================================================================
    % 2. LOAD SLC & SPATIAL CROPPING
    % =========================================================================
    fprintf('Loading SLC data...\n');
    load(path2mat, 'y_axis', 'x_axis', 'timestamp_abs', 'cplx');
    
    % Apply spatial domain cropping bounds matching your radar's look-window
    min_range = 10;   max_range = 180;
    min_angle = -50;  max_angle = 50; 
    pixel_ranges = sqrt(x_axis.^2 + y_axis.^2);
    pixel_angles = atan2d(y_axis, x_axis); 
    keep_mask = (pixel_ranges >= min_range) & (pixel_ranges <= max_range) & ...
                (pixel_angles >= min_angle) & (pixel_angles <= max_angle);
            
    x_axis = x_axis(keep_mask);
    y_axis = y_axis(keep_mask);
    cplx = cplx(keep_mask, :);
    pixel_ranges = pixel_ranges(keep_mask);
    
    % =========================================================================
    % 3. RECONSTRUCT INTERPOLATION GRID PROPERTIES FOR 2D MEDIAN FILTERING
    % =========================================================================
    grid_res = 1; 
    grid_padding = 2.0; 
    xq = (min(x_axis) - grid_padding):grid_res:(max(x_axis) + grid_padding);
    yq = (min(y_axis) - grid_padding):grid_res:(max(y_axis) + grid_padding);
    [XQ, YQ] = meshgrid(xq, yq);
    ylimits = [min(y_axis), max(y_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
    xlimits = [min(x_axis), max(x_axis)] + [-1 1] * abs(diff([min(y_axis), max(y_axis)])) * 0.02;
    
    % =========================================================================
    % 4. TIMELINE TIMING & FEATURE PRE-ALLOCATIONS
    % =========================================================================
    fprintf('Starting Feature Extraction Pipeline...\n');
    start_time = timestamp_abs(1);
    end_time = timestamp_abs(end);
    current_start = start_time;
    exp_loop = 1;
    num_pixels = length(x_axis); 
    max_loops = floor(seconds(end_time - start_time) / seconds(config.step_duration)) + 2;
    
    % Pre-allocate lightweight matrices for 3 tuning features
    exported_coherence = zeros(num_pixels, max_loops);
    exported_amplitude = zeros(num_pixels, max_loops);
    exported_phase_var = zeros(num_pixels, max_loops);

    exported_detrended_coh = zeros(num_pixels, max_loops);
    exported_detrended_amp = zeros(num_pixels, max_loops);
    exported_detrended_pvar = zeros(num_pixels, max_loops);

    exported_time_axis = NaT(max_loops, 1);
    
    % =========================================================================
    % 5. CHRONOLOGICAL PROCESSING LOOP (CORRECTED ARCHITECTURE SEQUENCE)
    % =========================================================================
    while (current_start + config.window_duration) <= end_time
        current_end = current_start + config.window_duration;
        frame_idx = (timestamp_abs >= current_start) & (timestamp_abs <= current_end);
        
        if sum(frame_idx) < 2
            current_start = current_start + config.step_duration;
            continue;
        end
        
        % Isolate temporal slice
        cplx_slice = cplx(:, frame_idx);
        cplx_ref = cplx_slice(:, 1);
        
        % --- SIGNAL 1: COHERENCE + RANGE COMPENSATION BOOST ---
        slice_interf_phase = angle(cplx_slice .* conj(cplx_ref));
        raw_coh = abs(mean(exp(1i * slice_interf_phase), 2));
        
        range_ramp = 1.0 + 0.40 * ((pixel_ranges - min_range) / (max_range - min_range));
        raw_coh_boosted = raw_coh .* range_ramp;
        raw_coh_boosted(raw_coh_boosted > 1) = 1;
        
        % --- SIGNAL 2: AMPLITUDE (LOG-dB SCALED PROFILES) ---
        raw_amp = mean(abs(cplx_slice), 2);
        amp_db = 20 * log10(raw_amp + eps);
        min_db = min(amp_db); max_db = max(amp_db);
        db_spread = max_db - min_db; if db_spread == 0, db_spread = eps; end
        norm_amp_initial = (amp_db - min_db) / db_spread;
        
        % --- SIGNAL 3: PHASE VARIANCE ---
        raw_pvar = var(slice_interf_phase, [], 2);
        
        
        % =========================================================================
        % PHASE A: RANGE-DEPENDENT LOCAL NORMALIZATION (DETRENDING) BEFORE GRIDDING
        % =========================================================================
        bin_width = 10;
        range_bins = min_range:5:max_range;
        
        detrended_amp   = zeros(size(norm_amp_initial));
        detrended_pvar  = zeros(size(raw_pvar));
        detrended_coher = zeros(size(raw_coh_boosted));
        
        for b = 1:length(range_bins)
            center_R = range_bins(b);
            in_bin = abs(pixel_ranges - center_R) <= (bin_width / 2);

            if sum(in_bin) > 5
                mu_amp   = mean(norm_amp_initial(in_bin)); 
                sigma_amp   = std(norm_amp_initial(in_bin)) + eps;
                mu_pvar  = mean(raw_pvar(in_bin));          
                sigma_pvar  = std(raw_pvar(in_bin)) + eps;
                mu_coher = mean(raw_coh_boosted(in_bin));   
                sigma_coher = std(raw_coh_boosted(in_bin)) + eps;
                
                detrended_amp(in_bin)   = (norm_amp_initial(in_bin) - mu_amp) / sigma_amp;
                detrended_pvar(in_bin)  = (raw_pvar(in_bin) - mu_pvar) / sigma_pvar;
                detrended_coher(in_bin) = (raw_coh_boosted(in_bin) - mu_coher) / sigma_coher;
            end

        end
        
        
        
        % Handle unassigned edge-cases globally
        unassigned = (detrended_amp == 0 & detrended_pvar == 0 & detrended_coher == 0);
        if any(unassigned)
            base_zs = zscore([norm_amp_initial(unassigned), raw_pvar(unassigned), raw_coh_boosted(unassigned)]);
            detrended_amp(unassigned)   = base_zs(:,1);
            detrended_pvar(unassigned)  = base_zs(:,2);
            detrended_coher(unassigned) = base_zs(:,3);
        end
        
        
        % =========================================================================
        % PHASE B: CASCADED TWO-STAGE CONVOLUTIONAL FILTRATION LAYER (DOUBLE CONVOLUTION)
        % =========================================================================
        %{
        grid_coh   = griddata(x_axis, y_axis, double(detrended_coher), XQ, YQ, 'linear');
        grid_amp   = griddata(x_axis, y_axis, double(detrended_amp), XQ, YQ, 'linear');
        grid_pvar  = griddata(x_axis, y_axis, double(detrended_pvar), XQ, YQ, 'linear');

        grid_coh(isnan(grid_coh))   = min(detrended_coher);
        grid_amp(isnan(grid_amp))   = min(detrended_amp);
        grid_pvar(isnan(grid_pvar)) = min(detrended_pvar);
        %}
        grid_coh = griddata(x_axis, y_axis, raw_coh_boosted, XQ, YQ, 'linear');
        grid_amp = griddata(x_axis, y_axis, norm_amp_initial, XQ, YQ, 'linear');
        grid_pvar = griddata(x_axis, y_axis, raw_pvar, XQ, YQ, 'linear');

        grid_coh_detrended = griddata(x_axis, y_axis, double(detrended_coher), XQ, YQ, 'linear');
        grid_amp_detrended = griddata(x_axis, y_axis, double(detrended_amp), XQ, YQ, 'linear');
        grid_pvar_detrended = griddata(x_axis, y_axis, double(detrended_pvar), XQ, YQ, 'linear');

        grid_coh(isnan(grid_coh))   = min(raw_coh_boosted);
        grid_amp(isnan(grid_amp))   = min(norm_amp_initial);
        grid_pvar(isnan(grid_pvar)) = min(raw_pvar);

        grid_coh_detrended(isnan(grid_coh_detrended))   = min(detrended_coher);
        grid_amp_detrended(isnan(grid_amp_detrended))   = min(detrended_amp);
        grid_pvar_detrended(isnan(grid_pvar_detrended)) = min(detrended_pvar);
        
        % --- CONVOLUTION 1: Spatial Low-Pass Denoising (Speckle Suppression) ---
        % Cleans range transitions and stabilizes local phase variance distributions
        coh_pass1 = medfilt2(grid_coh,  config.kernelfilter1); 
        amp_pass1 = medfilt2(grid_amp,  config.kernelfilter1);
        pvar_pass1 = medfilt2(grid_pvar, config.kernelfilter1);

        coh_pass1_detrended = medfilt2(grid_coh_detrended,  config.kernelfilter1); 
        amp_pass1_detrended = medfilt2(grid_amp_detrended,  config.kernelfilter1);
        pvar_pass1_detrended = medfilt2(grid_pvar_detrended, config.kernelfilter1);
        
        % --- CONVOLUTION 2: Directional Gradient Derivative (Edge Extraction) ---
        % Computes horizontal, vertical, and diagonal gradient magnitudes
        % Returns a structural boundary map rather than raw smoothed pixel intensities
        grid_coh_smooth  = medfilt2(coh_pass1,  config.kernelfilter2);
        grid_amp_smooth  = medfilt2(amp_pass1,  config.kernelfilter2);
        grid_pvar_smooth = medfilt2(pvar_pass1, config.kernelfilter2);

        grid_coh_detrended_smooth = medfilt2(coh_pass1_detrended, config.kernelfilter2);
        grid_amp_detrended_smooth = medfilt2(amp_pass1_detrended, config.kernelfilter2);
        grid_pvar_detrended_smooth = medfilt2(pvar_pass1_detrended, config.kernelfilter2);
        
        % Convert the logical binary edge masks to double arrays for clean interpolation
        grid_coh_smooth  = double(grid_coh_smooth);
        grid_amp_smooth  = double(grid_amp_smooth);
        grid_pvar_smooth = double(grid_pvar_smooth);

        grid_coh_detrended_smooth = double(grid_coh_detrended_smooth);
        grid_amp_detrended_smooth = double(grid_amp_detrended_smooth);
        grid_pvar_detrended_smooth = double(grid_pvar_detrended_smooth);

        % Interpolate the extracted gradient boundaries back onto original radar points
        smooth_coh_vec  = interp2(XQ, YQ, grid_coh_smooth, x_axis, y_axis, 'linear');
        smooth_amp_vec  = interp2(XQ, YQ, grid_amp_smooth, x_axis, y_axis, 'linear');
        smooth_pvar_vec = interp2(XQ, YQ, grid_pvar_smooth, x_axis, y_axis, 'linear');
        
        smooth_coh_vec(isnan(smooth_coh_vec))   = 0;
        smooth_amp_vec(isnan(smooth_amp_vec))   = 0;
        smooth_pvar_vec(isnan(smooth_pvar_vec)) = 0;
        
        smooth_coh_detrended_vec  = interp2(XQ, YQ, grid_coh_detrended_smooth, x_axis, y_axis, 'linear');
        smooth_amp_detrended_vec  = interp2(XQ, YQ, grid_amp_detrended_smooth, x_axis, y_axis, 'linear');
        smooth_pvar_detrended_vec = interp2(XQ, YQ, grid_pvar_detrended_smooth, x_axis, y_axis, 'linear');
        
        smooth_coh_detrended_vec(isnan(smooth_coh_detrended_vec))   = 0;
        smooth_amp_detrended_vec(isnan(smooth_amp_detrended_vec))   = 0;
        smooth_pvar_detrended_vec(isnan(smooth_pvar_detrended_vec)) = 0;

        % Store final extracted edge traces into your persistent matrix slices
        exported_coherence(:, exp_loop) = smooth_coh_vec;
        exported_amplitude(:, exp_loop) = smooth_amp_vec;
        exported_phase_var(:, exp_loop) = smooth_pvar_vec;

        exported_detrended_coh(:, exp_loop) = smooth_coh_detrended_vec;
        exported_detrended_amp(:, exp_loop) = smooth_amp_detrended_vec;
        exported_detrended_pvar(:, exp_loop) = smooth_pvar_detrended_vec;

        exported_time_axis(exp_loop)     = current_start;
    
        exp_loop = exp_loop + 1;
        current_start = current_start + config.step_duration;
    end
    
    % Trim pre-allocation padding
    exported_coherence(:, exp_loop:end) = [];
    exported_amplitude(:, exp_loop:end) = [];
    exported_phase_var(:, exp_loop:end) = [];
    exported_time_axis(exp_loop:end)     = [];

    exported_detrended_coh(:, exp_loop:end) = [];
    exported_detrended_amp(:, exp_loop:end) = [];
    exported_detrended_pvar(:, exp_loop:end) = [];

    exported_time_axis(exp_loop:end)     = [];
    
    % =========================================================================
    % 6. PERSISTENT WORKSPACE SAVING (Lightweight tuning package)
    % =========================================================================
    export_package = fullfile(export_dir, 'tuned_features.mat');
    save(export_package, 'exported_coherence', 'exported_amplitude', 'exported_phase_var', ...
        'exported_detrended_coh', 'exported_detrended_amp', 'exported_detrended_pvar', ...
         'exported_time_axis', 'x_axis', 'y_axis', 'XQ', 'YQ', 'ylimits', 'xlimits', ...
         '-v7.3');
     
    fprintf('=== Preprocessing COMPLETE! Saved lightweight package to: %s ===\n', export_package);
end