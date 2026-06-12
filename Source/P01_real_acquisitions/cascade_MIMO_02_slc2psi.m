
%% cascade_MIMO_02_slc2cum.m
%
% The following function takes as an input the SLCs created by the function
% cascade_MIMO_01_raw2slc.m and calculates the interferogram of the time
% series.
%
% -------------------------------------------------------------------------
%
% Input:
%
% - path2proj:      A string refering to a structured folder with raw data.
%                   The directory should have a folders and a file.
%                   I) In "02_SLC_Radar_Data":
%                    a) The results created with cascade_MIMO_01_raw2slc.m
%                   II) A m-file with the same name as the proj_name and
%                   describing various acquisition properties and loading
%                   the data in the folder "02_SLC_Radar_Data".
%                   
% - filt_by_rng:    A cell consisting of three entries describing the 
%                   filtering based on slant range limitations: 
%                   {true/false, minDist, maxDist}
%                    a) The first entry defines if the distance filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the minimal distance to
%                       keep in meters.
%                    c) The third entry defines the maximal distance to
%                       keep in meters.
% - filt_by_lr:     A cell consisting of three entries describing the 
%                   filtering based on cross range limitations: 
%                   {true/false, minDist, maxDist}
%                    a) The first entry defines if the distance filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the left cross range in 
%                       meters.
%                    c) The third entry defines the right cross range in
%                       meters.
%
% - filt_by_azi:    A cell consisting of three entries describing the 
%                   filtering based on azimuth: 
%                   {true/false, minAzimuth, maxAzimuth}
%                    a) The first entry defines if the azimuth filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the minimal azimuth [deg].
%                    c) The third entry defines the maximal azimuth [deg].

% - filt_by_asi:    A cell consisting of two entries describing the 
%                   filtering based on the amplitude stability index: 
%                   {true/false, minASI}
%                    a) The first entry defines if the ASI filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the minimal ASI required.

% - filt_by_coh:    A cell consisting of two entries describing the 
%                   filtering based on the coherence [3x3 neighbourhood]: 
%                   {true/false, minCoh}
%                    a) The first entry defines if the COH filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the minimal COH required.

% - filt_by_mrd:    A cell consisting of three entries describing the 
%                   filtering based on a maximum reasonable displacement: 
%                   {true/false, maxAbsDisp, maxAvgDisp}
%                    a) The first entry defines if the MRD filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the maximal absolute 
%                       displacement [m].
%                    c) The third entry defines the maximal average
%                       displacement [m].
%
% - filt_by_time:   A cell consisting of three entries describing the 
%                   filtering based on a date/time selection: 
%                   {true/false, minDatetime, maxDatetime}
%                    a) The first entry defines if the MRD filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the start time [datetime].
%                    c) The third entry defines the end time [datetime].
%
% - filt_by_aoi:    A cell consisting of two entries describing the
%                   filtering based on N area of interests: 
%                   {true/false, numAOI}
%                    a) The first entry defines if the AOI filtering
%                       is applied (true) or not (false).
%                    b) The second entry defines the number of AoI to be
%                       expected.
%
% -------------------------------------------------------------------------
%                          Overall Workflow
%
%
%                    +------------------------------+
%   (1)              |  cascade_MIMO_01_raw2slc.m   |
%                    +--------------+---------------+
%                                   |
%                                   |
%                    +--------------¦---------------+
%   (2)              |  cascade_MIMO_02_slc2psi.m   |
%                    +--------------+---------------+  
%                                   |
%          +------------------------+------------------------+
%          |                                                 |
% 
% -------------------------------------------------------------------------
% by Andreas Baumann-Ouyang, ETH Zürich (27th July 2022)

%{
function cascade_MIMO_02_slc2psi(path2proj,... 
    filt_by_rng, filt_by_lr,...
    filt_by_azi, filt_by_asi,...
    filt_by_coh,...
    filt_by_maxDisp,...
    filt_by_time,...
    filt_by_aoi)
    
    %% --- HIDDEN AUTO-CONFIG BLOCK ---
    filt_by_mrd = filt_by_maxDisp;
    num_antenna = 86;
    length_antenna = 3;
    % 1. Find JSON
    f_json = dir(fullfile(path2proj, '01_Raw_Radar_Data', '*.mmwave.json'));
    if isempty(f_json)
        error('JSON config not found in %s', path2proj);
    end
    p = JsonParser(fullfile(f_json(1).folder, f_json(1).name));
    
    % 2. Calculate Lambda
    c0 = physconst('LightSpeed');
    slope = p.DevConfig(1).Profile.FreqSlope;
    adc_rate = p.DevConfig(1).Profile.SamplingRate * 1e3;
    num_ADC_smpl = p.DevConfig(1).Profile.NumSamples;
    bw_chirp = (num_ADC_smpl / adc_rate) * slope * 1e12;
    centerFreq = (p.DevConfig(1).Profile.StartFreq * 1e9) + (bw_chirp / 2); 
    lambda = c0 / centerFreq;
    rng_res = c0 / (2 * bw_chirp);
    
    % 3. Extract Start Time from Folder Name
    % Logic: Look for YYYYMMDD_HHMMSS in the path string
    time_tokens = regexp(path2proj, '(\d{8})_(\d{6})', 'tokens');
    if ~isempty(time_tokens)
        start_time = datetime([time_tokens{1}{1} time_tokens{1}{2}], 'InputFormat', 'yyyyMMddHHmmss');
    else
        start_time = datetime('now'); % Fallback
    end
    
    % 4. Build Timestamps
    % Using 'Periodicity' which we identified earlier
    frame_period = p.DevConfig(1).FrameConfig.Periodicity;
    num_frames_raw   = p.DevConfig(1).FrameConfig.NumFrames;
    data_hz_raw  = 1000 / frame_period;
    timestamp_abs = start_time + (0:num_frames_raw-1) * seconds(1/data_hz_raw);

    %% --- LOAD EXTERNAL GEOMETRY FILE ---
    % Build the path to the parameter file folder inside the project directory
    % Extract just the short project folder name from the absolute path
    [~, proj_name, ~] = fileparts(path2proj); 

    path_parm = fullfile(path2proj, '00_Parameter_Files');
    config_filename = [proj_name, '.m']; % FIX: Changed path2proj to proj_name
    path2config = fullfile(path_parm, config_filename);
    
    if isfile(path2config)
        % Temporarily add the folder to the search path to run the script cleanly
        [config_dir, config_name, ~] = fileparts(path2config);
        addpath(config_dir);
        try
            run(config_name); % Executes project file to load radar_position and radar_orient
            fprintf('Successfully loaded geometry from configuration file: %s\n', config_filename);
        catch
            warning('Error running configuration file %s. Using fallback geometry parameters.', config_filename);
            radar_position = [0.0, 0.0, 1.5];
            radar_orient   = [168.5943, 69.7854, 90.000];
        end
        rmpath(config_dir); % Remove it from the search path to keep the space clean
    else
        % Default fallback values if the script hasn't been created yet
        warning('Geometry configuration file %s not found in %s. Using defaults.', config_filename, path_parm);
        radar_position = [0.0, 0.0, 1.5];
        radar_orient   = [168.5943, 69.7854, 90.000];
    end
    %% --- END HIDDEN BLOCK ---

    [~,proj_name,~]= fileparts(path2proj);
    name_folder = sprintf('03_PSI_Interfero');
    path2store = fullfile(path2proj,name_folder);

    if ~isfolder(path2store)
        mkdir(path2store)
    end

    %% Data to be loaded
    %% --- DATA LOADING ---
    path_to_slc = fullfile(path2proj, '02_SLC_Radar_data');
    
    % This loads the .mat files and creates 'cplx'
    [x_axis, y_axis, cplx, coh, ~] = load_slc_files(path_to_slc);
    num_frames_loaded = size(cplx, 2);
    
    % Calculate the "Effective Step Size" automatically
    % This compares how many frames the JSON expected vs what was actually loaded
    eff_step = max(1, floor(num_frames_raw / num_frames_loaded));
    
    % Generate timestamps that EXACTLY match the number of columns in 'cplx'
    frame_indices = (0:num_frames_loaded-1) * eff_step;
    timestamp_abs = start_time + seconds(frame_indices * (frame_period/1000));
    timestamp_rel = seconds(timestamp_abs - timestamp_abs(1));
    
    % Update data_hz to the decimated rate for processing logic
    data_hz = 1000 / (frame_period * eff_step);
    
    % Pack for plotting
    data.x_axis = x_axis;
    data.y_axis = y_axis;
    data.coh    = coh.mean;
    step_i = 1;
    fprintf('Step % 2d: Processing Radar Data (%s)\n', step_i, proj_name);
    %run(sprintf("%s.m",proj_name));
    
    scale_rad2mm = lambda / (4*pi) * 1000; % from radian to mm
    N_obs = 2*data_hz; % Average over first 2 seconds of observations and shift.
    
    %% Temporal Filtering & Downsampling (Fixed Logic)
    stride_rate = 2; % Take every 10th frame (10Hz -> 1Hz)
    
    % Create a dedicated mask for the stride selection
    stride_mask = false(size(timestamp_abs));
    stride_mask(1:stride_rate:end) = true;
    
    if filt_by_time{1} == 1
        % Find frames within the absolute time window
        time_mask = timestamp_abs >= min(filt_by_time{2:3}) & ...
                    timestamp_abs <= max(filt_by_time{2:3});
        
        % Keep only frames that fall inside the window AND match our stride
        idx_keep = time_mask & stride_mask;
    else
        % If no time filter is used, just use the stride mask directly
        idx_keep = stride_mask;
    end
    idx_keep = logical(idx_keep);
    
    cplx = cplx(:,idx_keep);
    timestamp_abs = timestamp_abs(idx_keep);
    timestamp_rel = timestamp_rel(idx_keep);
    
    % --- ADD THIS LINE TO FIX METADATA ---
    data_hz = data_hz / stride_rate; 
    % -------------------------------------
    
    field_names = fields(coh);
    for field_i = 1:length(field_names)
        dims_n = ndims(coh.(field_names{field_i}));
        if dims_n == 2
            [m1,n] = size(coh.(field_names{field_i}));
            if n == length(idx_keep)
                coh.(field_names{field_i}) = coh.(field_names{field_i})(:,idx_keep);
            end
        elseif dims_n == 3
            [m1,m2,n] = size(coh.(field_names{field_i}));
            if n == length(idx_keep)
                coh.(field_names{field_i}) = coh.(field_names{field_i})(:,:,idx_keep);
            end
        end
    end
    
    sct_rng = filt_by_rng{3};
    %% Geometrical Filtering based on Area of Interest
    if filt_by_aoi{1}==1
        path2aoi = fullfile(path2store,'aoi.mat');
        if ~isfile(path2aoi)
            [aoi, desc] = set_aoi_scXobs(filt_by_aoi{2},...
                                         cplx,...
                                         coh.mean(:,end),...
                                         coh.class(:,end),...
                                         y_axis,...
                                         x_axis,...
                                         filt_by_aoi{3});
            save(path2aoi,"aoi","desc");
        else
            load(path2aoi,"aoi","desc");
        end
        filt_aoi = get_idx_in_aoi(y_axis,x_axis, aoi);
    else
        filt_aoi = ones(size(sct_rng));
    end

    sct_phi = round(atan2(x_axis, y_axis) - pi/2, 6);
    sct_rng = round(sqrt(x_axis.^2 + y_axis.^2), 4);
    
    if filt_by_azi{1} == 1 % Filtering based on Azimuth
        if length(filt_by_azi) == 2
            filt_azi = abs(sct_phi)*180/pi<=abs(filt_by_azi{2});
        else
            filt_azi = sct_phi*180/pi >= min(filt_by_azi{2:3}) & ...
                       sct_phi*180/pi <= max(filt_by_azi{2:3});
        end
    else
        filt_azi = ones(size(sct_rng));
    end
    
    if filt_by_rng{1} == 1 % Filtering based on Range
        filt_rng = sct_rng >= min(filt_by_rng{2:3}) & ....
                   sct_rng <= max(filt_by_rng{2:3}) ;
    else
        filt_rng = ones(size(sct_rng));
    end
    
    
    if filt_by_lr{1} == 1 % Filtering based on Cross-Range Borders
        filt_lr = y_axis >= min(filt_by_lr{2:3}) & ...
                  y_axis <= max(filt_by_lr{2:3});
    else
        filt_lr = ones(size(sct_rng));
    end
    
    
    filter_data = filt_rng & filt_azi & filt_lr & filt_aoi;
    
    cplx(~filter_data,:)=[];
    x_axis(~filter_data)=[];
    y_axis(~filter_data)=[];
    
    for field_i = 1:length(field_names)
        dims_n = ndims(coh.(field_names{field_i}));
        if dims_n == 2
            [m,n1] = size(coh.(field_names{field_i}));
            if m == length(filter_data)
                coh.(field_names{field_i})(~filter_data,:) = [];
            end
        elseif dims_n == 3
            warning('Not defined.');
        end
    end
    
    clearvars sct_rng sct_phi
    
    %% Statistical Filtering
    coh.mean = mean(coh.coh_1N,2);
    coh.std = std(coh.coh_1N,[],2);
    
    if filt_by_coh{1}
        filt_coh = coh.mean >= filt_by_coh{2};
    else
        filt_coh = ones(size(coh.mean));
    end
    
    sct_amp = abs(cplx);
    sct_std = std(sct_amp,[],2);
    sct_avg = mean(sct_amp,2);
    asi = 1-(sct_std./sct_avg); % Amplitude Stability Index
    
    if filt_by_asi{1}
        if ~exist('filt_asi','var')
            filt_asi = asi >= filt_by_asi{2};
        end
    else
        filt_asi = ones(size(cplx));
    end
    
    filter_data = filt_asi & filt_coh;
    
    cplx(~filter_data,:)=[];
    x_axis(~filter_data)=[];
    y_axis(~filter_data)=[];
    asi(~filter_data)=[];
    
    for field_i = 1:length(field_names)
        dims_n = ndims(coh.(field_names{field_i}));
        if dims_n == 2
            [m,n1] = size(coh.(field_names{field_i}));
            if m == length(filter_data)
                coh.(field_names{field_i})(~filter_data,:) = [];
            end
        elseif dims_n == 3
            warning('Not defined.');
        end
    end
    
    clearvars stc_amp sct_std sct_avg
    
    %% Number of Scatter / Observations
    [n_sct,n_obs] = size(cplx);
       
    % %% Interferograms
    % step_i = step_i+1;
    % fprintf("Step % 2d: Compute Interferograms\n",step_i); % Averaging 
    % data.interf = complex(zeros(n_sct,n_obs-1));
    % cplx_avg = mean(cplx(:,1:N_obs),2);
    % for obs_i = 1:n_obs-1
    %     data.interf(:,obs_i) = cplx(:,obs_i+1) .* conj(cplx_avg);
    % end
    %% Interferograms
    step_i = step_i+1;
    fprintf("Step % 2d: Compute Interferograms\n",step_i); 
    data.interf = complex(zeros(n_sct,n_obs-1));
    
    % FIX: Use only the first frame as reference, no averaging!
    cplx_avg = cplx(:,1); 
    
    for obs_i = 1:n_obs-1
        data.interf(:,obs_i) = cplx(:,obs_i+1) .* conj(cplx_avg);
    end
    
    %% Store Time Stamp to data
    data.time_rel_interf = timestamp_rel(1:end-1) + ...
                                diff(timestamp_rel)/2; % Duration
    data.time_abs_interf = timestamp_abs(1:end-1) + ...
                                diff(timestamp_abs)/2; % Datetime
    
    data.time_rel_interf_unit = 'duration';
    data.time_abs_interf_unit = 'datetime';
    
    %% Saving SLC file
    fname = '01_SLC_Filt';
    path2mat = join([fullfile(path2store,fname),'.mat'],'');
    
    coher = coh.mean;
    coher_class = coh.class;
    coher_std = coh.std;
    class_id = coh.class_id;
    class_descr = coh.class_descr;
    
    step_i = step_i+1;
    fprintf("Step % 2d: Saving SLC file as *.mat\n",step_i);
    save(path2mat,...
        'cplx',...
        'coher',...
        'coher_class',...
        'coher_std',...
        'class_id',...
        'class_descr',...
        'y_axis','x_axis',...
        'timestamp_rel',...
        'timestamp_abs');
     
    clearvars cplx coher coher_class coher_std class_id class_descr
    
    %% Interferometric Phases
    step_i = step_i+1;
    fprintf("Step % 2d: Compute Interferometric Phases and Unwrap\n",step_i)
    data.ampl = abs(data.interf); % Magnitude of Complex Values
    data.phase = angle(data.interf); % Interferometric Phase
    
    %% Cumulative Displacement
    step_i = step_i+1;
    fprintf("Step % 2d: Compute Displacements in Line of Sights\n",step_i)
    data.cumdispl = unwrap(data.phase,[],2) * scale_rad2mm;
    
    %% Store Geometric Properties to data
    step_i = step_i+1;
    fprintf("Step % 2d: Range and Azimuth\n",step_i)
    
    data.x_axis = x_axis;
    data.x_axis_unit = 'm';
    data.y_axis = y_axis;
    data.y_axis_unit = 'm';
    data.azimuth = round(atan2(y_axis,x_axis)*180/pi,6);
    data.azimuth_unit = 'deg';
    data.range = round(sqrt(x_axis.^2+y_axis.^2),3);
    data.range_unit = 'm';
    data.asi = asi; % Amplitude Stability Index
    data.coh = coh.mean; % Coherence in [3x3] neighbourhood
    data.coh_class = coh.class; % Coherence Classes
    data.coh_std = coh.std; % Standard Deviation
    data.coh_class_id = coh.class_id; % Class ID [-2...1]
    data.coh_class_descr = coh.class_descr; % Description of Class ID
    
    %% Store Filtering Properties to data
    data.proc_filt.type = [];
    data.proc_filt.type_val = [];
    data.proc_filt.type_unit = [];
    
    if filt_by_rng{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Slant Range [min/max]';
        data.proc_filt.type_val{end+1} = filt_by_rng{2:3};
        data.proc_filt.type_unit{end+1} = 'm';
    end
    
    if filt_by_lr{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Cross Range [left/right]';
        data.proc_filt.type_val{end+1} = filt_by_lr{2:3};
        data.proc_filt.type_unit{end+1} = 'm';
    end
    
    if filt_by_azi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Azimuth [min/max]';
        data.proc_filt.type_val{end+1} = filt_by_azi{2:3};
        data.proc_filt.type_unit{end+1} = 'deg';
    end
    
    if filt_by_coh{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Coherence [min]';
        data.proc_filt.type_val{end+1} = filt_by_coh{2};
        data.proc_filt.type_unit{end+1} = '-';
    end
    
    if filt_by_asi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Amplitude Stability Index [min]';
        data.proc_filt.type_val{end+1} = filt_by_asi{2};
        data.proc_filt.type_unit{end+1} = '-';
    end
    
    if filt_by_mrd{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Maximum Displacement [MaxAbsDispl, MaxMeanDispl]';
        data.proc_filt.type_val{end+1} = filt_by_mrd{2:3};
        data.proc_filt.type_unit{end+1} = 'mm';
    end
    
    if filt_by_time{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Time [minDate, maxDate]';
        data.proc_filt.type_val{end+1} = filt_by_time{2:3};
        data.proc_filt.type_unit{end+1} = 'datetime';
    end

    if filt_by_aoi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Area of Interest [y_axis, x_axis]';
        data.proc_filt.type_val{end+1} = aoi;
        data.proc_filt.type_unit{end+1} = 'm';
    end
    
    %% Store Radar Properties to data
    data.radar.position = radar_position; %[m]
    data.radar.position_unit = 'm'; 
    data.radar.orientation = radar_orient; %[degree]
    data.radar.orientation_unit = 'deg'; 
    data.radar.azimuth.num_virt_ant = num_antenna; %[-]
    data.radar.elevation.resolution = round((1/length_antenna)*180/pi,6); %[degree]
    data.radar.elevation.resolution_unit = 'deg'; 
    data.radar.range.resolution = rng_res; % [m]
    data.radar.range.resolution_unit = 'm';
    data.radar.azimuth.all = round(unique(data.azimuth),6);
    data.radar.azimuth.all_unit = 'deg'; 
    data.radar.range.all = unique(data.range);
    data.radar.range.all_unit = 'm'; 
    
    %% Store Processed Data
    step_i = step_i+1;
    fprintf("Step % 2d: Saving Mat-File.\n",step_i)
    
    fname = '02_PSI';
    path2mat = join([fullfile(path2store,fname),'.mat'],'');
    save(path2mat,'data');
    
    %% Plot Overview
    fig = figure('units','normalized','outerposition',[0 0 1 1]);
    
    ylimits = [min(data.y_axis),max(data.y_axis)];
    ylimits = ylimits + [-1 1] * abs(diff(ylimits)) * 0.05;
    xlimits = [min(data.x_axis),max(data.x_axis)];
    xlimits = xlimits + [-1 1] * abs(diff(ylimits)) * 0.05;
    
    %% Amplitude
    % ax(1)=subplot(2,2,1); 
    % ampl = log10(mean(data.ampl,2));
    % plot_polar_range_azimuth_2D_AB_preAX(data.y_axis,...
    %                                      data.x_axis,...
    %                                      ampl,...
    %                                      ylimits,xlimits,'scatter');
    % hcb = colorbar;
    % hcb.Label.String = "Amplitude [log10(A)]";
    % climits_val = [floor(prctile(ampl,5)),ceil(prctile(ampl,95))];
    % clim(climits_val);
    % caxis(climits_val);
    %% Amplitude (Forced Sidelobe Clean Up)
    ax(1)=subplot(2,2,1); 
    ampl = log10(mean(data.ampl,2));
    
    % --- NEW: Clear out the background noise floor manually ---
    % Find a cutoff value just above the arc background level
    cutoff_noise = prctile(ampl, 15); 
    ampl_clean = ampl;
    ampl_clean(ampl_clean < cutoff_noise) = cutoff_noise; 
    % ----------------------------------------------------------
    
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis,...
                                         data.x_axis,...
                                         ampl_clean,... % Plot the cleaned matrix
                                         ylimits,xlimits,'scatter');
    hcb = colorbar;
    hcb.Label.String = "Amplitude [log10(A)]";
    
    % Match your custom 5% to 95% limits
    climits_val = [prctile(ampl_clean,5), prctile(ampl_clean,95)];
    clim(climits_val);
    box on
    axis equal
    
    %% Amplitude Stability Index
    ax(2)=subplot(2,2,2);
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis,...
                                         data.x_axis,...
                                         data.asi,...
                                         ylimits,xlimits,'scatter');
    hcb = colorbar;
    hcb.Label.String = "Amplitude Stability Index [-]";
    climits_val = [floor(prctile(data.asi,50)*20)/20,1];
    clim(climits_val);
    caxis(climits_val);
    box on
    axis equal
    
    %% Coherence
    ax(3)=subplot(2,2,3);
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis,...
                                         data.x_axis,...
                                          data.coh,...
                                          ylimits,xlimits,'scatter');
    hcb = colorbar;
    hcb.Label.String = "Mean Coherence [0...1]";
    climits_val = [prctile(data.coh,20),prctile(data.coh,98)];
    clim(climits_val);
    caxis(climits_val);
    box on
    axis equal
    
    %% Maximal Displacement in Time
    ax(4)=subplot(2,2,4);
    prc_tile_coh = prctile(data.coh,95);
    max_abs_displ = max(abs(data.cumdispl(data.coh>=min([prc_tile_coh,0.95]),:)),[],1);
    idx_time_max = find(max_abs_displ==max(max_abs_displ));
    displace = squeeze(data.cumdispl(:,idx_time_max));

    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis,...
                                         data.x_axis,...
                                         displace,...
                                         ylimits,xlimits,'scatter');
    hcb = colorbar;
    hcb.Label.String = "Displacement [mm]";
    climits = [prctile(displace,5),prctile(displace,50)];
    climits = [-max(abs(climits)),max(abs(climits))];
    clim(climits);
    caxis(climits);
    box on
    axis equal

    
    Link = linkprop(ax,{'CameraUpVector', 'CameraPosition', 'CameraTarget', 'XLim', 'YLim'});
    setappdata(gcf, 'StoreTheLink', Link);
    
    sgtitle(sprintf('%s - Overview',replace(proj_name,'_',' ')));
    
    exportgraphics(fig,replace(path2mat,'.mat','.png'),'Resolution',600);
    savefig(fig,replace(path2mat,'.mat','.fig'));
%}

function cascade_MIMO_02_slc2psi(path2proj,... 
    filt_by_rng, filt_by_lr,...
    filt_by_azi, filt_by_asi,...
    filt_by_coh,...
    filt_by_maxDisp,...
    filt_by_time,...
    filt_by_aoi)
    
    %% --- HIDDEN AUTO-CONFIG BLOCK ---
    filt_by_mrd = filt_by_maxDisp;
    num_antenna = 86;
    length_antenna = 3;
    
    % 1. Find JSON Config
    f_json = dir(fullfile(path2proj, '01_Raw_Radar_Data', '*.mmwave.json'));
    if isempty(f_json), error('JSON config not found in %s', path2proj); end
    p = JsonParser(fullfile(f_json(1).folder, f_json(1).name));
    
    % 2. Calculate Radar Parameters
    c0 = physconst('LightSpeed');
    slope = p.DevConfig(1).Profile.FreqSlope;
    adc_rate = p.DevConfig(1).Profile.SamplingRate * 1e3;
    num_ADC_smpl = p.DevConfig(1).Profile.NumSamples;
    bw_chirp = (num_ADC_smpl / adc_rate) * slope * 1e12;
    centerFreq = (p.DevConfig(1).Profile.StartFreq * 1e9) + (bw_chirp / 2); 
    lambda = c0 / centerFreq;
    rng_res = c0 / (2 * bw_chirp);
    
    % 3. Extract Start Time from Project Path String
    time_tokens = regexp(path2proj, '(\d{8})_(\d{6})', 'tokens');
    if ~isempty(time_tokens)
        start_time = datetime([time_tokens{1}{1} time_tokens{1}{2}], 'InputFormat', 'yyyyMMddHHmmss');
    else
        start_time = datetime('now');
    end
    
    frame_period = p.DevConfig(1).FrameConfig.Periodicity;
    num_frames_raw = p.DevConfig(1).FrameConfig.NumFrames;
    scale_rad2mm = lambda / (4*pi) * 1000; % Convert from radians to mm
    
    % 4. Load External Radar Geometry Configuration Parameters
    [~, proj_name, ~] = fileparts(path2proj);
    path_parm = fullfile(path2proj, '00_Parameter_Files');
    config_filename = [proj_name, '.m'];
    path2config = fullfile(path_parm, config_filename);
    
    if isfile(path2config)
        [config_dir, config_name, ~] = fileparts(path2config);
        addpath(config_dir);
        try 
            run(config_name); 
            fprintf('Successfully loaded geometry from configuration file: %s\n', config_filename);
        catch
            warning('Error running configuration file %s. Using fallback geometry parameters.', config_filename);
            radar_position = [0.0, 0.0, 1.5]; radar_orient = [168.5943, 69.7854, 90.000];
        end
        rmpath(config_dir);
    else
        warning('Geometry configuration file %s not found in %s. Using defaults.', config_filename, path_parm);
        radar_position = [0.0, 0.0, 1.5]; radar_orient = [168.5943, 69.7854, 90.000];
    end
    
    % 5. Establish Save Directories
    name_folder = '03_PSI_Interfero';
    path2store = fullfile(path2proj, name_folder);
    if ~isfolder(path2store), mkdir(path2store); end
    
    path_to_slc = fullfile(path2proj, '02_SLC_Radar_data');
    if ~isfolder(path_to_slc), path_to_slc = fullfile(path2proj, '02_SLC_Radar_Data'); end
    slc_files = dir(fullfile(path_to_slc, '*.mat'));
    if isempty(slc_files), error('No SLC data files found in: %s', path_to_slc); end
    
    step_i = 1;
    fprintf('Step % 2d: Processing Radar Data (%s)\n', step_i, proj_name);

    % =========================================================================
    % PASS 1: DETERMINE THE GLOBAL SURVIVING PIXEL MASK (AOI & GEOMETRY)
    % =========================================================================
    fprintf('Pass 1: Analyzing spatial structures to map persistent targets...\n');
    master_init = load(fullfile(slc_files(1).folder, slc_files(1).name), 'complex_data_static', 'x_axis', 'y_axis', 'coh');
    
    global_x = master_init.x_axis;
    global_y = master_init.y_axis;
    
    sct_phi = round(atan2(global_x, global_y) - pi/2, 6);
    sct_rng = round(sqrt(global_x.^2 + global_y.^2), 4);
    
    % --- Core Area of Interest (AOI) Filter Logic Execution ---
    if filt_by_aoi{1} == 1
        path2aoi = fullfile(path2store, 'aoi.mat');
        if ~isfile(path2aoi)
            [aoi, desc] = set_aoi_scXobs(filt_by_aoi{2},...
                                         master_init.complex_data_static,...
                                         master_init.coh.mean(:,end),...
                                         master_init.coh.class(:,end),...
                                         global_y,...
                                         global_x,...
                                         filt_by_aoi{3});
            save(path2aoi, "aoi", "desc");
        else
            load(path2aoi, "aoi", "desc");
        end
        filt_aoi = get_idx_in_aoi(global_y, global_x, aoi);
    else
        filt_aoi = ones(size(sct_rng));
    end
    
    % --- Geometrical Bounds Filters ---
    if filt_by_azi{1} == 1
        if length(filt_by_azi) == 2
            filt_azi = abs(sct_phi)*180/pi <= abs(filt_by_azi{2});
        else
            filt_azi = sct_phi*180/pi >= min(filt_by_azi{2:3}) & sct_phi*180/pi <= max(filt_by_azi{2:3});
        end
    else
        filt_azi = ones(size(sct_rng));
    end
    
    if filt_by_rng{1} == 1
        filt_rng = sct_rng >= min(filt_by_rng{2:3}) & sct_rng <= max(filt_by_rng{2:3});
    else
        filt_rng = ones(size(sct_rng));
    end
    
    if filt_by_lr{1} == 1
        filt_lr = global_y >= min(filt_by_lr{2:3}) & global_y <= max(filt_by_lr{2:3});
    else
        filt_lr = ones(size(sct_rng));
    end
    
    spatial_mask = logical(filt_rng & filt_azi & filt_lr & filt_aoi);
    
    % --- Statistical Filters Baseline (Coherence & Amplitude Stability) ---
    local_coh_mean = mean(master_init.coh.coh_1N, 2);
    if filt_by_coh{1}
        filt_coh = local_coh_mean >= filt_by_coh{2};
    else
        filt_coh = ones(size(local_coh_mean));
    end
    
    local_amp = abs(master_init.complex_data_static);
    asi = 1 - (std(local_amp, [], 2) ./ mean(local_amp, 2));
    if filt_by_asi{1}
        filt_asi = asi >= filt_by_asi{2};
    else
        filt_asi = ones(size(asi));
    end
    
    global_surviving_mask = logical(spatial_mask & filt_coh & filt_asi);
    
    final_x_axis = global_x(global_surviving_mask);
    final_y_axis = global_y(global_surviving_mask);
    N_surviving_pts = length(final_x_axis);
    
    % Keep a record of metadata components from first file structures
    saved_class_id = master_init.coh.class_id;
    saved_class_descr = master_init.coh.class_descr;
    saved_coher_class = master_init.coh.class(global_surviving_mask, :);
    
    fprintf('Identification complete. %d highly stable target points detected.\n', N_surviving_pts);
    clear master_init local_amp asi local_coh_mean;
    
    % =========================================================================
    % PASS 2: TIME SERIES HORIZON AND MEMORY CONTAINERS PREALLOCATION
    % =========================================================================
    stride_rate = 2; % Matches original downsampling step size
    total_decimated_frames = 0;
    
    % Track chunk specifications and absolute timelines without loading large arrays
    chunk_frames_count = zeros(1, length(slc_files));
    chunk_keep_masks = cell(1, length(slc_files));
    global_frame_counter = 0;
    
    for chunk_idx = 1:length(slc_files)
        m_meta = matfile(fullfile(slc_files(chunk_idx).folder, slc_files(chunk_idx).name));
        [~, n_frames] = size(m_meta, 'complex_data_static');
        chunk_frames_count(chunk_idx) = n_frames;
        
        % Construct timestamps for this chunk to check time-window filter bounds
        frame_indices = global_frame_counter + (0:n_frames-1);
        local_time_abs = start_time + seconds(frame_indices * (frame_period / 1000));
        
        stride_mask = false(1, n_frames);
        stride_mask(1:stride_rate:end) = true;
        
        if filt_by_time{1} == 1
            time_mask = local_time_abs >= min(filt_by_time{2:3}) & local_time_abs <= max(filt_by_time{2:3});
            idx_keep = time_mask & stride_mask;
        else
            idx_keep = stride_mask;
        end
        
        chunk_keep_masks{chunk_idx} = idx_keep;
        total_decimated_frames = total_decimated_frames + sum(idx_keep);
        global_frame_counter = global_frame_counter + n_frames;
    end
    
    % Allocate unified containers safely in RAM
    global_cplx      = complex(zeros(N_surviving_pts, total_decimated_frames));
    global_time_abs  = NaT(1, total_decimated_frames);              % CRITICAL FIX: Empty Datetime array
    global_time_rel  = seconds(zeros(1, total_decimated_frames));   % CRITICAL FIX: Empty Duration array
    global_coher_vec = zeros(N_surviving_pts, length(slc_files));
    global_coher_std = zeros(N_surviving_pts, length(slc_files));
    
    % Lock master anchor frame (Frame 1 of Block 1)
    master_init_data = load(fullfile(slc_files(1).folder, slc_files(1).name), 'complex_data_static');
    global_master_subset = master_init_data.complex_data_static(global_surviving_mask, 1);
    clear master_init_data;
    
    % =========================================================================
    % PASS 3: STREAMING AND EXTRACTION LOOP
    % =========================================================================
    curr_frame_ptr = 1;
    cumulative_frames_scanned = 0;
    
    for chunk_idx = 1:length(slc_files)
        fprintf('Pass 2: Slicing matrices from block %d/%d...\n', chunk_idx, length(slc_files));
        chunk_data = load(fullfile(slc_files(chunk_idx).folder, slc_files(chunk_idx).name));
        
        local_cplx = chunk_data.complex_data_static;
        local_coh  = chunk_data.coh;
        n_frames = size(local_cplx, 2);
        
        frame_indices = cumulative_frames_scanned + (0:n_frames-1);
        local_time_abs = start_time + seconds(frame_indices * (frame_period / 1000));
        local_time_rel = seconds(local_time_abs - start_time);
        
        idx_keep = chunk_keep_masks{chunk_idx};
        local_filtered_cplx = local_cplx(global_surviving_mask, idx_keep);
        n_inserted_frames = size(local_filtered_cplx, 2);
        
        if n_inserted_frames > 0
            end_frame_ptr = curr_frame_ptr + n_inserted_frames - 1;
            
            % Insert sliced segment into the master allocation block
            global_cplx(:, curr_frame_ptr:end_frame_ptr) = local_filtered_cplx;
            global_time_abs(curr_frame_ptr:end_frame_ptr) = local_time_abs(idx_keep);
            global_time_rel(curr_frame_ptr:end_frame_ptr) = local_time_rel(idx_keep);
            
            curr_frame_ptr = end_frame_ptr + 1;
        end
        
        % Accumulate structural data diagnostics
        local_coh_mean = mean(local_coh.coh_1N, 2);
        global_coher_vec(:, chunk_idx) = local_coh_mean(global_surviving_mask);
        global_coher_std(:, chunk_idx) = local_coh.std(global_surviving_mask);
        
        cumulative_frames_scanned = cumulative_frames_scanned + n_frames;
        clear chunk_data local_cplx local_filtered_cplx;
    end
    
    % Trim any allocation padding rows safely
    if (curr_frame_ptr - 1) < total_decimated_frames
        needed_frames = curr_frame_ptr - 1;
        global_cplx(:, needed_frames+1:end) = [];
        global_time_abs(needed_frames+1:end) = [];
        global_time_rel(needed_frames+1:end) = [];
    end
    
    % =========================================================================
    % PASS 4: UNIFIED DISPLACEMENT COMPREHENSION
    % =========================================================================
    step_i = step_i + 1;
    fprintf("Step % 2d: Compute Interferograms\n", step_i); 
    
    n_total_obs = size(global_cplx, 2);
    data_interf = complex(zeros(N_surviving_pts, n_total_obs));
    
    for obs_i = 1:n_total_obs
        data_interf(:, obs_i) = global_cplx(:, obs_i) .* conj(global_master_subset);
    end
    
    % Timestamps configuration matching your exact timeline shifts
    data.time_rel_interf = global_time_rel;
    data.time_abs_interf = global_time_abs;
    data.time_rel_interf_unit = 'duration';
    data.time_abs_interf_unit = 'datetime';
    
    % =========================================================================
    % PASS 5: WRITE EXPORT TO UNIFIED 01_SLC_Filt.mat
    % =========================================================================
    fname = '01_SLC_Filt';
    path2mat = fullfile(path2store, [fname, '.mat']);
    step_i = step_i + 1;
    fprintf("Step % 2d: Saving Unified SLC database file to: %s\n", step_i, path2mat);
    
    cplx = global_cplx;
    coher = mean(global_coher_vec, 2);
    coher_std = mean(global_coher_std, 2);
    coher_class = saved_coher_class; 
    class_id = saved_class_id;
    class_descr = saved_class_descr;
    y_axis = final_y_axis;
    x_axis = final_x_axis;
    timestamp_abs = global_time_abs;
    timestamp_rel = global_time_rel;
    
    save(path2mat, 'cplx', 'coher', 'coher_class', 'coher_std', 'class_id', 'class_descr', ...
                   'y_axis', 'x_axis', 'timestamp_rel', 'timestamp_abs', '-v7.3');
               
    clearvars cplx coher coher_class coher_std class_id class_descr
    
    % Uncomment this block if you want PSI
    %{
    % =========================================================================
    % PASS 6: WRITING MASTER OUTPUT DATASET (02_PSI.mat)
    % =========================================================================
    step_i = step_i + 1;
    fprintf("Step % 2d: Compute Interferometric Phases and Unwrap\n", step_i);
    data.ampl = abs(data_interf); 
    data.phase = angle(data_interf); 
    
    step_i = step_i + 1;
    fprintf("Step % 2d: Compute Displacements in Line of Sights\n", step_i);
    data.cumdispl = unwrap(data.phase, [], 2) * scale_rad2mm;
    
    step_i = step_i + 1;
    fprintf("Step % 2d: Structuring Radar/Geometric Metadata Profiles\n", step_i);
    
    data.x_axis = final_x_axis;         data.x_axis_unit = 'm';
    data.y_axis = final_y_axis;         data.y_axis_unit = 'm';
    data.azimuth = round(atan2(final_y_axis, final_x_axis)*180/pi, 6);
    data.azimuth_unit = 'deg';
    data.range = round(sqrt(final_x_axis.^2 + final_y_axis.^2), 3);
    data.range_unit = 'm';
    
    % Recalculate Amplitude Stability Index over total global set
    sct_amp = abs(global_cplx);
    data.asi = 1 - (std(sct_amp, [], 2) ./ mean(sct_amp, 2));
    data.coh = mean(global_coher_vec, 2); 
    data.coh_class = saved_coher_class; 
    data.coh_std = mean(global_coher_std, 2); 
    data.coh_class_id = saved_class_id; 
    data.coh_class_descr = saved_class_descr;
    
    % Populate original configuration verification metadata arrays
    data.proc_filt.type = []; data.proc_filt.type_val = []; data.proc_filt.type_unit = [];
    if filt_by_rng{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Slant Range [min/max]';
        data.proc_filt.type_val{end+1} = filt_by_rng{2:3}; data.proc_filt.type_unit{end+1} = 'm';
    end
    if filt_by_lr{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Cross Range [left/right]';
        data.proc_filt.type_val{end+1} = filt_by_lr{2:3}; data.proc_filt.type_unit{end+1} = 'm';
    end
    if filt_by_azi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Azimuth [min/max]';
        data.proc_filt.type_val{end+1} = filt_by_azi{2:3}; data.proc_filt.type_unit{end+1} = 'deg';
    end
    if filt_by_coh{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Coherence [min]';
        data.proc_filt.type_val{end+1} = filt_by_coh{2}; data.proc_filt.type_unit{end+1} = '-';
    end
    if filt_by_asi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Amplitude Stability Index [min]';
        data.proc_filt.type_val{end+1} = filt_by_asi{2}; data.proc_filt.type_unit{end+1} = '-';
    end
    if filt_by_mrd{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Maximum Displacement [MaxAbsDispl, MaxMeanDispl]';
        data.proc_filt.type_val{end+1} = filt_by_mrd{2:3}; data.proc_filt.type_unit{end+1} = 'mm';
    end
    if filt_by_time{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Time [minDate, maxDate]';
        data.proc_filt.type_val{end+1} = filt_by_time{2:3}; data.proc_filt.type_unit{end+1} = 'datetime';
    end
    if filt_by_aoi{1} == 1
        data.proc_filt.type{end+1} = 'Filter by Area of Interest [y_axis, x_axis]';
        data.proc_filt.type_val{end+1} = aoi; data.proc_filt.type_unit{end+1} = 'm';
    end
    
    data.radar.position = radar_position; data.radar.position_unit = 'm'; 
    data.radar.orientation = radar_orient; data.radar.orientation_unit = 'deg'; 
    data.radar.azimuth.num_virt_ant = num_antenna; 
    data.radar.elevation.resolution = round((1/length_antenna)*180/pi,6); data.radar.elevation.resolution_unit = 'deg'; 
    data.radar.range.resolution = rng_res; data.radar.range.resolution_unit = 'm';
    data.radar.azimuth.all = round(unique(data.azimuth),6); data.radar.azimuth.all_unit = 'deg'; 
    data.radar.range.all = unique(data.range); data.radar.range.all_unit = 'm'; 
    
    step_i = step_i + 1;
    psi_out_path = fullfile(path2store, '02_PSI.mat');
    fprintf("Step % 2d: Saving Final Output Matrix to: %s\n", step_i, psi_out_path);
    save(psi_out_path, 'data', '-v7.3');
    
    % =========================================================================
    % PASS 7: RENDERING DIAGNOSTIC SUMMARY VISUALIZATION PANELS
    % =========================================================================
    fprintf('Generating unified execution diagnostic dashboard...\n');
    fig = figure('units','normalized','outerposition',[0 0 1 1]);
    
    ylimits = [min(data.y_axis), max(data.y_axis)];
    ylimits = ylimits + [-1 1] * abs(diff(ylimits)) * 0.05;
    xlimits = [min(data.x_axis), max(data.x_axis)];
    xlimits = xlimits + [-1 1] * abs(diff(ylimits)) * 0.05;
    
    % Subplot 1: Cleaned Average Amplitude Map
    ax(1) = subplot(2,2,1); 
    ampl = log10(mean(data.ampl, 2));
    cutoff_noise = prctile(ampl, 15); 
    ampl_clean = ampl;
    ampl_clean(ampl_clean < cutoff_noise) = cutoff_noise; 
    
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis, data.x_axis, ampl_clean, ylimits, xlimits, 'scatter');
    hcb1 = colorbar; hcb1.Label.String = "Amplitude [log10(A)]";
    clim([prctile(ampl_clean,5), prctile(ampl_clean,95)]); box on; axis equal;
    
    % Subplot 2: Amplitude Stability Index Profile
    ax(2) = subplot(2,2,2);
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis, data.x_axis, data.asi, ylimits, xlimits, 'scatter');
    hcb2 = colorbar; hcb2.Label.String = "Amplitude Stability Index [-]";
    clim([floor(prctile(data.asi,50)*20)/20, 1]); box on; axis equal;
    
    % Subplot 3: Mean Spatial Coherence Layout
    ax(3) = subplot(2,2,3);
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis, data.x_axis, data.coh, ylimits, xlimits, 'scatter');
    hcb3 = colorbar; hcb3.Label.String = "Mean Coherence [0...1]";
    clim([prctile(data.coh,20), prctile(data.coh,98)]); box on; axis equal;
    
    % Subplot 4: Maximal Absolute Displacement in Time (Completed Fix)
    ax(4) = subplot(2,2,4);
    prc_tile_coh = prctile(data.coh, 95);
    valid_coh_mask = data.coh >= min([prc_tile_coh, 0.95]);
    
    if any(valid_coh_mask)
        max_abs_displ = max(abs(data.cumdispl(valid_coh_mask, :)), [], 1);
        idx_time_max = find(max_abs_displ == max(max_abs_displ), 1);
        displace = squeeze(data.cumdispl(:, idx_time_max));
    else
        displace = squeeze(data.cumdispl(:, end)); % Fallback to last frame
    end
    
    plot_polar_range_azimuth_2D_AB_preAX(data.y_axis, data.x_axis, displace, ylimits, xlimits, 'scatter');
    hcb4 = colorbar; hcb4.Label.String = "Maximal Displacement [mm]";
    clim_val = max(abs(prctile(displace, [5, 95]))); 
    if clim_val == 0 || isnan(clim_val), clim_val = 1; end
    clim([-clim_val, clim_val]); box on; axis equal;
    
    % Save out figure profile mapping matching your data location
    exportgraphics(fig, replace(psi_out_path, '.mat', '.png'), 'Resolution', 300);
    fprintf('Processing loop completely finalized.\n');
    %}
end