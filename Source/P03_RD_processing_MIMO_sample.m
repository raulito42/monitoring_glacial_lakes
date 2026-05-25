% %% The following script is a sample script for processing radar data acquired with a TIDEP-01012 system
% 
% %% Clear everything
% close all
% clearvars
% clc
% 
% %% Initalisation
% [file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
% addpath(genpath(fullfile(file_dir)));
% 
% % Define Project
% proj_list = {'MIMO_C77_Pond_lowSlope_21min_20260513_115401', 'MIMO_C77_Pond_lowSlope_21min_ohneCR_20260513_121908'}; % Project name consistent with <project_name>
% % 
% % filt_by_dist_list = {{1,10,50}}; % Distance Limitation {True/False, D_Min, D_Max}
% % 
% % filt_by_azi_list = {{1,-45,45}}; % Azimuth Limitation {True/False, Az_Min, Az_Max}
% % 
% % filt_by_asi_list = {{1,-inf}}; % Filter by Amplitude Stability Index {True/False, ASI_Min}
% % 
% % filt_by_lr_list = {{1,-500,500}}; % Cross Range Limitation {True/False, CR_Min, CR_Max}
% % 
% % filt_by_coh_list = {{1,0.7}}; % Filter by Coherence {True/False, COH_Min}
% % 
% % filt_by_maxDisp_list = {{1,-inf,inf}}; % Filter by Maximum Displacement {True/False, dDNeg_max, dDPos_max}
% % 
% % filt_by_aoi_list = {{0,0,0}}; % Filter by Area of Interest {True/False, Number of AoI, isCircle True/False}
% % 
% % time_select_list = {{0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,54)}}; % Filter by Time {True/False, T_Start, T_End}
% % 
% % time_select_zoom_list = {{0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,24)}}; % Filter by Time (Zoom for psi2timeseries function)
% % 
% % filt_by_aoi_zoom_list = {{0,1,0}}; % Filter by Area of Interest (Zoom for psi2timeseries function)
% filt_by_dist_list = {{1,10,50}, {1,10,50}}; 
% filt_by_azi_list  = {{1,-45,45}, {1,-45,45}}; 
% filt_by_asi_list  = {{1,-inf}, {1,-inf}}; 
% filt_by_lr_list   = {{1,-500,500}, {1,-500,500}}; 
% filt_by_coh_list  = {{1,0.7}, {1,0.7}}; 
% filt_by_maxDisp_list = {{1,-inf,inf}, {1,-inf,inf}}; 
% filt_by_aoi_list  = {{0,0,0}, {0,0,0}}; 
% 
% time_select_list      = {{0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,54)}, {0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,54)}}; 
% time_select_zoom_list = {{0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,24)}, {0, datetime(2026,04,23,11,03,54),datetime(2026,04,23,11,04,24)}}; 
% filt_by_aoi_zoom_list = {{0,1,0}, {0,1,0}};
%% The following script is a sample script for processing radar data acquired with a TIDEP-01012 system
%% Clear everything
close all
clearvars
clc

%% Initalisation
[file_dir,~,~] = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(file_dir)));

% 1. Define your projects in the list
proj_list = {'MIMO_C77_GS_P3_001_15min_20260519_130316_00910000ms'}; 
         
num_projects = length(proj_list); % Automatically counts how many projects are active

% 2. Define your base configuration settings (Just ONE copy here)
base_dist    = {1,1,180};       % Distance Limitation {True/False, D_Min, D_Max}
base_azi     = {1,-50,50};      % Azimuth Limitation {True/False, Az_Min, Az_Max}
base_asi     = {0,-inf};        % Filter by Amplitude Stability Index {True/False, ASI_Min}
base_lr      = {1,-500,500};    % Cross Range Limitation {True/False, CR_Min, CR_Max}
base_coh     = {1,-inf};         % Filter by Coherence {True/False, COH_Min}
base_maxDisp = {1,-inf,inf};    % Filter by Maximum Displacement {True/False, dDNeg_max, dDPos_max}
base_aoi     = {1,1,0};         % Filter by Area of Interest {True/False, Number of AoI, isCircle True/False}

base_time        = {0, datetime(2026,04,23,11,03,54), datetime(2026,04,23,11,04,54)};
base_time_zoom   = {0, datetime(2026,04,23,11,03,54), datetime(2026,04,23,11,04,24)};
base_aoi_zoom    = {1,1,0};

% 3. Automatically expand the lists to match the project count
filt_by_dist_list    = cell(1, num_projects);
filt_by_azi_list     = cell(1, num_projects);
filt_by_asi_list     = cell(1, num_projects);
filt_by_lr_list      = cell(1, num_projects);
filt_by_coh_list     = cell(1, num_projects);
filt_by_maxDisp_list = cell(1, num_projects);
filt_by_aoi_list     = cell(1, num_projects);
time_select_list      = cell(1, num_projects);
time_select_zoom_list = cell(1, num_projects);
filt_by_aoi_zoom_list = cell(1, num_projects);

for idx = 1:num_projects
    filt_by_dist_list{idx}    = base_dist;
    filt_by_azi_list{idx}     = base_azi;
    filt_by_asi_list{idx}     = base_asi;
    filt_by_lr_list{idx}      = base_lr;
    filt_by_coh_list{idx}     = base_coh;
    filt_by_maxDisp_list{idx} = base_maxDisp;
    filt_by_aoi_list{idx}     = base_aoi;
    time_select_list{idx}      = base_time;
    time_select_zoom_list{idx} = base_time_zoom;
    filt_by_aoi_zoom_list{idx} = base_aoi_zoom;
end

for p_i = 1:length(proj_list)

    name2proj = proj_list{p_i};
    path2proj = fullfile(file_dir,...
                         'D00_sample_data',...
                         'real',...
                         name2proj);
    
    % %% Processing: From Raw Data to SLC
    % filt_by_rng  = filt_by_dist_list{p_i};
    % filt_by_azi  = filt_by_azi_list{p_i};
    % filt_by_asi  = filt_by_asi_list{p_i};
    % 
    % cascade_MIMO_01_raw2slc(path2proj,...
    %                         filt_by_rng,...
    %                         filt_by_azi,...
    %                         filt_by_asi);

    %% Processing: From SLC Data to PSI
    % Settings for Geometrical Filtering
    filt_by_aoi = filt_by_aoi_list{p_i};
    filt_by_rng = filt_by_dist_list{p_i};
    filt_by_lr  = filt_by_lr_list{p_i};
    filt_by_azi = filt_by_azi_list{p_i};

    % Settings for Statistical Filtering
    filt_by_asi = filt_by_asi_list{p_i};
    filt_by_coh = filt_by_coh_list{p_i};
    filt_by_maxDisp = filt_by_maxDisp_list{p_i};

    % % Settings for Temporal Filtering
    filt_by_time = time_select_list{p_i};

    cascade_MIMO_02_slc2psi(path2proj,...
                               filt_by_rng,...
                               filt_by_lr,...
                               filt_by_azi,...
                               filt_by_asi,...
                               filt_by_coh,...
                               filt_by_maxDisp,...
                               filt_by_time,...
                               filt_by_aoi);


    % %% Processing: From PSI to Coordinate Components
    % % Settings for Temporal Filtering
    % filt_by_asi = filt_by_asi_list{p_i};
    % filt_by_time = time_select_zoom_list{p_i};
    % create_aoi = filt_by_aoi_zoom_list{p_i}{2};
    % 
    % cascade_MIMO_03_psi2timeseries(path2proj, ...
    %                                 filt_by_time, ...
    %                                 filt_by_asi, ...
    %                                 create_aoi);

end