function varargout = manage_video_pipeline(action, varargin)
% MANAGE_VIDEO_PIPELINE Outsources the initialization, frame capture,
% and termination logic of the MPEG-4 video rendering suite.

switch lower(action)
    case 'init'
        export_dir = varargin{1};
        frame_rate = varargin{2};
        quality    = varargin{3};
        
        video_filename = fullfile(export_dir, 'shoreline_comparative_tracking.mp4');
        fprintf('Initializing Unified Comparative Video Compilation Stream...\n');
        
        v_writer = VideoWriter(video_filename, 'MPEG-4');
        v_writer.FrameRate = frame_rate; 
        v_writer.Quality = quality;
        open(v_writer);
        
        varargout{1} = v_writer;
        
    case 'write'
        v_writer   = varargin{1};
        fig_handle = varargin{2};
        
        % Guard Clause: If writer object is missing or empty, do nothing
        if isempty(v_writer) || ~isvalid(v_writer)
            return;
        end
        
        drawnow;
        current_frame = getframe(fig_handle);
        writeVideo(v_writer, current_frame);
        
    case 'close'
        v_writer = varargin{1};
        
        if isempty(v_writer) || ~isvalid(v_writer)
            return;
        end
        
        close(v_writer);
        fprintf('Video pipeline container closed successfully.\n');
end
end