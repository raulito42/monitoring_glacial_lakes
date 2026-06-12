clear; clc; close all;

% =========================================================================
% 1. PATH CONFIGURATION REGIME
% =========================================================================
project_root = '/Users/raul/projects-FS26/mimo-sar/monitoring_glacial_lakes/Source';
name2proj = 'MIMO_C77_Pond_lowSlope_21min_ohneCR_20260513_121908';
export_dir = fullfile(project_root, 'D00_sample_data', 'real', name2proj, 'export_xxx');
export_package = fullfile(export_dir, 'tuned_features.mat');

if ~isfile(export_package)
    error('Preprocessed tuning data package not found! Run your exporter script first.');
end

% Create export directory if it doesn't exist
if ~exist(export_dir, 'dir')
    mkdir(export_dir);
end

% =========================================================================
% 2. LIGHTWEIGHT DATAFRAME INGESTION & DYNAMIC TIGHT BOUNDS BOUNDING
% =========================================================================
fprintf('Ingesting preprocessed time-series dataframe...\n');
load(export_package);
num_frames = length(exported_time_axis);
fprintf('Successfully loaded %d processed timeframes.\n', num_frames);

% RE-CALCULATE TIGHT BOUNDS: Remove arbitrary padding percentage to maximize subplot space
ylimits = [min(y_axis), max(y_axis)];
xlimits = [min(x_axis), max(x_axis)];

% =========================================================================
% 3. GRAPHICAL USER INTERFACE & VIDEO WRITER INITIALIZATION
% =========================================================================
% Using absolute pixels for figure sizing to guarantee stable frame dimensions for the video encoding
dashboard_fig = figure('Name', 'Multi-Channel Signal Tuning Workspace (Custom Tool Layout)', ...
                       'Units', 'pixels', 'Position', [100, 100, 1440, 600], ...
                       'Color', 'w');

% Initialize Video Writer Engine
video_filename = fullfile(export_dir, 'signal_tuning_playback.mp4');
fprintf('Initializing Video Writer Engine: %s...\n', video_filename);
v_writer = VideoWriter(video_filename, 'MPEG-4');
v_writer.FrameRate = 5; % Frames per second during playback
v_writer.Quality = 95; % High visual compression quality
open(v_writer);

plot_style = 'scatter';
ax(1) = subplot(1,3,1);
ax(2) = subplot(1,3,2);
ax(3) = subplot(1,3,3);

% =========================================================================
% 4. DYNAMIC CHRONOLOGICAL PLAYBACK & RECORDING ENGINE
% =========================================================================
fprintf('Recording timeline loop to video file...\n');
for f = 1:num_frames
    % Isolate vectors for the current time frame slice
    current_time = exported_time_axis(f);
    coh_frame = exported_coherence(:, f); %exported_detrended_coh(:, f);
    amp_frame = exported_amplitude(:, f); %exported_detrended_amp(:, f);
    pvar_frame = exported_phase_var(:, f); %exported_detrended_pvar(:, f);
    
    % --- SUBPLOT 1: TUNED COHERENCE ---
    set(dashboard_fig, 'CurrentAxes', ax(1));
    cla(ax(1));
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, coh_frame, ylimits, xlimits, plot_style);
    title('1. Tuned Coherence (Boosted)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    colormap(ax(1), jet); colorbar; clim([0 1]); grid on;
    set(ax(1), 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.5 0.5 0.5]);
    
    % --- SUBPLOT 2: TUNED LOG-AMPLITUDE ---
    set(dashboard_fig, 'CurrentAxes', ax(2));
    cla(ax(2));
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, amp_frame, ylimits, xlimits, plot_style);
    title('2. Tuned Amplitude (\gamma - Normalized)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    colormap(ax(2), flipud(hot)); colorbar; clim([0, 0.4]); grid on;
    set(ax(2), 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.5 0.5 0.5]);
    
    % --- SUBPLOT 3: TUNED PHASE VARIANCE ---
    set(dashboard_fig, 'CurrentAxes', ax(3));
    cla(ax(3));
    plot_polar_range_azimuth_2D_AB_preAX(y_axis, x_axis, pvar_frame, ylimits, xlimits, plot_style);
    title('3. Tuned Phase Variance (\sigma_\phi^2)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    colormap(ax(3), parula); colorbar; clim([0 max(exported_phase_var(:))*0.5]); grid on;
    set(ax(3), 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.5 0.5 0.5]);
    
    % --- SUPER-TITLE DATETIME ANCHOR ---
    time_str = datestr(current_time, 'yyyy-mm-dd HH:MM:SS');
    sgtitle(sprintf('Radar Signal State Dashboard | Time-stamp: %s | Frame [%d/%d]', ...
            time_str, f, num_frames), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
    drawnow;
    
    % Capture current canvas frame state and record to file stream
    video_frame = getframe(dashboard_fig);
    writeVideo(v_writer, video_frame);
    
    % Control interactive streaming interface delay
    pause(0.05);
    
    % Break cleanly if user closes window mid-stream
    if ~ishandle(dashboard_fig)
        break;
    end
end

% Finalize video stream file writing operations
close(v_writer);
fprintf('=== Video recording complete! Saved file to: %s ===\n', video_filename);