function run_batch_pipeline()
    clear; clc; close all;
    
    % =========================================================================
    % 1. GLOBAL ENVIRONMENT CONFIGURATION
    % =========================================================================
    project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';
    
    projects_list = { 
        'MIMO_C77_GS_P1_001_20min_20260519_102536_01300000ms' 
        %'MIMO_C77_GS_P2_001_20min_20260519_113033_01300000ms', 
        'MIMO_C77_GS_P2_002_15min_20260519_121708_00910000ms' 
        'MIMO_C77_GS_P3_001_15min_20260519_130316_00910000ms'  
        'MIMO_C77_Pond_lowSlope_21min_ohneCR_20260513_121908'
        %'MIMO_C77_Pond_lowSlope_21min_20260513_115401' ...
    };
    
    num_projects = length(projects_list);
    fprintf('=================================================================\n');
    fprintf('STARTING BATCH RADAR TRACKING PIPELINE OVER %d PROJECTS\n', num_projects);
    fprintf('=================================================================\n');
    
    % =========================================================================
    % 2. AUTOMATED BATCH RUNTIME EXECUTION LOOP
    % =========================================================================
    for p = 1:num_projects
        name2proj = projects_list{p}; 
        export_dir = fullfile(project_root, 'D00_sample_data', 'real', name2proj, 'export_xxx');
        
        fprintf('\n---> Processing Dataset [%d/%d]: %s\n', p, num_projects, name2proj);
        
        % =====================================================================
        % METADATA ENGINE FACTORY: ASSIGN HYPERPARAMETERS BASED ON DESIGN PROFILE
        % =====================================================================
        config = struct();
        config.name2proj = name2proj;
        config.project_root = project_root;
        config.export_dir = export_dir;
        config.window_duration = seconds(15);
        config.step_duration   = seconds(15);
        config.radius_close    = 2; 
        config.radius_open     = 1;
        
        if contains(name2proj, 'Pond')
            % --- CONFIGURATION FOR CAMPUS SITE ---
            config.kernelfilter1 = [3,3];
            config.kernelfilter2 = [5,5];
            config.se1_radius = 2;   % Perimeter step
            config.se4_radius = 10;  % Thicker ribbon mask allocation
            
            % Environment-specific thresholds for Campus Pond [Nominal, Lower, Upper]
            config.thresh_nom = [0.55 0.45 0.65];
            config.thresh_det = [-0.1 -0.3 0.1];
            config.clim_nom = [0.35 0.75];
            config.clim_det = [-0.5 0.5];
            
            fprintf('   [Profile Found]: Campus Low-Slope Pond Configuration Loaded.\n');
            
        else
            % --- DEFAULT CONFIGURATION FOR ALPINE SITE ('GS') ---
            config.kernelfilter1 = [5,5];
            config.kernelfilter2 = [11,11];
            config.se1_radius = 2;   
            config.se4_radius = 20;   
            
            % Environment-specific thresholds for Alpine / Glacial Lake [Nominal, Lower, Upper]
            config.thresh_nom = [0.14, 0.13, 0.15];
            config.thresh_det = [-0.325, -0.4, -0.25];
            config.clim_nom = [0.12 0.16];
            config.clim_det = [-0.45 -0.2];
            
            fprintf('   [Profile Found]: Alpine / Glacial Lake Configuration Loaded.\n');
        end
        % =====================================================================
        % --- Core Step 00: Signal Conditioning ---
        fprintf('  Executing P00_condition_data...\n')
        %P00_condition_data(config);
        
        % --- Core Step 01: Morphological High-Stability Land Core Extraction ---
        fprintf('   Executing P01_cluster...\n');
        %P01_cluster(config);
        
        % --- Core Step 02: Unified Onshore Encroachment Tracking Dashboard ---
        fprintf('   Executing P02_water_tracking_unified...\n');
        %P02_water_tracking_unified(config);

        % --- Core Step 03: Shoreline Area Hydrological Dynamics Analysis ---
        fprintf('   Executing P03_water_area_dynamics...\n');
        %P03_water_area_dynamics(config);
        
        % --- Core Step 04: Sensitivity Analysis ---
        fprintf('   Executing P04_sensitivity_analysis...\n');
        P04_sensitivity_analysis(config);
        
        fprintf('✔ Successfully finalized processing and sensitivity for: %s\n', name2proj);
    end
end