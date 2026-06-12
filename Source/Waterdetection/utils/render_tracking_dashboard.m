function render_tracking_dashboard(fig, f, num_frames, frame_coh, narrow_tracking_zone, mask_nominal, ...
                                   calculated_thresholds, total_roi_area_m2, comp_xlim, comp_ylim, ...
                                   x_axis, y_axis, XQ, YQ, shifts, thresh_nominal)
% RENDER_TRACKING_DASHBOARD Outsources the massive visualization rendering block 
% from the main loop to maximize code execution readability.

clf(fig);

% --- SUBPLOT A: SPATIAL DISPLAY VIEW ---
ax1 = subplot(1, 2, 1);
scatter(ax1, y_axis, x_axis, 8, frame_coh, 'filled');
hold(ax1, 'on');
colormap(ax1, jet); clim(ax1, [0 1]);
h_cb = colorbar(ax1); h_cb.Label.String = 'Radar Coherence';

% Draw ribbon corridor geometry overlay
ribbon_x = y_axis; ribbon_y = x_axis;
ribbon_x(~narrow_tracking_zone) = NaN; ribbon_y(~narrow_tracking_zone) = NaN;
scatter(ax1, ribbon_x, ribbon_y, 10, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.05);

% Project the post-DBSCAN filtered nominal mask back down onto scatter point coordinates
vector_water_mask = interp2(XQ, YQ, double(mask_nominal), x_axis, y_axis, 'nearest') > 0.5;
active_x = y_axis; active_y = x_axis;
active_x(~vector_water_mask) = NaN; active_y(~vector_water_mask) = NaN;
h_water = scatter(ax1, active_x, active_y, 22, [1 0 0], 'filled');
if ~isempty(h_water)
    set(h_water, 'MarkerFaceAlpha', 0.1, 'MarkerEdgeAlpha', 0.5); 
    uistack(h_water, 'top'); 
end

title(ax1, sprintf('A. Shared Spatial Corridor View (Frame %02d / %d)', f, num_frames), 'FontSize', 12, 'FontWeight', 'bold');
subtitle(ax1, sprintf('Red Dots: DBSCAN-Cleaned Active Front (Threshold Baseline < %.2f)', thresh_nominal), 'FontSize', 9);
xlabel(ax1, 'Azimuth Y (m)'); ylabel(ax1, 'Range X (m)');
axis(ax1, 'equal'); xlim(ax1, comp_ylim); ylim(ax1, comp_xlim);
grid(ax1, 'on'); box(ax1, 'on');

% --- SUBPLOT B: COMPREHENSIVE ENGINE TREND COMPARISON VIEW ---
ax2 = subplot(1, 2, 2);
filter_span = max(1, min(5, f));

% Apply temporal smoothing filtering across tracking array dimensions
trend_nominal = medfilt1(shifts.nominal(1:f), filter_span);
trend_lower   = medfilt1(shifts.lower(1:f),   filter_span);
trend_upper   = medfilt1(shifts.upper(1:f),   filter_span);
trend_kmeans  = medfilt1(shifts.kmeans(1:f),  filter_span);

% Layer 1: Plot Threshold Method Confidence Envelope Patch
frames_x = 1:f;
x_patch  = [frames_x, fliplr(frames_x)];
y_patch  = [trend_lower', fliplr(trend_upper')];
fill(ax2, x_patch, y_patch, [0.1 0.5 0.8], ...
     'FaceAlpha', 0.12, 'EdgeColor', 'none', 'DisplayName', 'DBSCAN-Filtered Threshold Envelope');
hold(ax2, 'on');

% Layer 2: Plot Nominal Fixed Threshold Trend Line (Blue)
plot(ax2, 1:f, trend_nominal, '-o', 'LineWidth', 2.0, 'Color', [0.1 0.5 0.8], ...
     'MarkerFaceColor', [0.0 0.2 0.5], 'MarkerSize', 5, ...
     'DisplayName', sprintf('Fixed Threshold + DBSCAN (\\gamma = %.2f)', thresh_nominal));
 
% Layer 3: Plot Adaptive K-means Trend Line (Red)
plot(ax2, 1:f, trend_kmeans, '-^', 'LineWidth', 2.0, 'Color', [0.8 0.2 0.2], ...
     'MarkerFaceColor', [0.5 0.0 0.0], 'MarkerSize', 5, 'DisplayName', 'Adaptive K-means (Unsupervised)');
 
yline(ax2, 0, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off'); 

title(ax2, 'B. Quantitative Inundation Comparison Analysis', 'FontSize', 12, 'FontWeight', 'bold');
subtitle(ax2, sprintf('Current Adaptive K-means Classification Threshold Limit: \\gamma \\approx %.2f', calculated_thresholds(f)), 'FontSize', 9);
xlabel(ax2, 'Sequential Temporal Chronological Frames');
ylabel(ax2, 'Relative Surface Area Change Delta (m^2)');
grid(ax2, 'on'); box(ax2, 'on'); xlim(ax2, [1 num_frames]);

max_dev = max([60, max(abs(trend_upper))*1.3, max(abs(trend_kmeans))*1.3]);
ylim(ax2, [-max_dev, max_dev]);
legend(ax2, 'Location', 'northwest', 'FontSize', 9);

% Overlay Context Information Box
pct_roi_th = (abs(trend_nominal(end)) / total_roi_area_m2) * 100;
pct_roi_km = (abs(trend_kmeans(end))  / total_roi_area_m2) * 100;

comparison_str = {sprintf(' Total ROI Area:  %.1f m^2', total_roi_area_m2), ...
                  sprintf(' Threshold Delta: %.1f m^2 (%.2f%%)', trend_nominal(end), pct_roi_th), ...
                  sprintf(' K-means Delta:   %.1f m^2 (%.2f%%)', trend_kmeans(end), pct_roi_km)};
              
text(ax2, num_frames*0.04, -max_dev*0.78, comparison_str, ...
     'FontSize', 9.5, 'FontName', 'monospace', 'FontWeight', 'bold', 'Color', [1 1 1], ...                     
     'BackgroundColor', [0.15 0.17 0.20 0.85], 'EdgeColor', [0.4 0.4 0.4], 'Margin', 6);                             

sgtitle(fig, sprintf('MIMO-SAR Tracking Optimization Core | Frame %02d / %d', f, num_frames), ...
        'FontWeight', 'bold', 'FontSize', 14);
end