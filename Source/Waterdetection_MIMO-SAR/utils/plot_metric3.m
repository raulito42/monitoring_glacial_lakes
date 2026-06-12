function plot_metric3(TP_A, FN_A, FP_A, TN_A, Acc_A, ...
                      TP_B, FN_B, FP_B, TN_B, Acc_B, ...
                      export_dir, showfigs, name2proj)
    vis_setting = 'on'; if ~showfigs, vis_setting = 'off'; end
    
    fig3 = figure('Name', 'Metric 3 - Comparative Confusion Dashboards', ...
                  'Units', 'pixels', 'Position', [100 100 950 500], ...
                  'Color', 'w', 'Visible', vis_setting);
              
    matrix_data_A = [TP_A, FN_A; FP_A, TN_A];
    matrix_data_B = [TP_B, FN_B; FP_B, TN_B];

    % ---------------------------------------------------------------------
    % Subplot 1: Fixed Threshold Matrix
    % ---------------------------------------------------------------------
    subplot(1,2,1); 
    imagesc(matrix_data_A); 
    colormap(flipud(bone)); 
    axis square; 
    
    set(gca, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0]);
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Pred Water', 'Pred Land'}, ...
             'YTick', 1:2, 'YTickLabel', {'True Water', 'True Land'}, ...
             'FontWeight', 'bold');
         
    title(sprintf('Fixed Threshold Matrix\nOverall Accuracy: %.1f%%', Acc_A), ...
          'Color', [0 0 0], 'FontWeight', 'bold');
      
    % Functional coloring inside the matrix quadrants
    text(1,1,sprintf('TP\n%d',TP_A),'Horiz','center','Color',[0.0 0.6 0.0],'FontWeight','bold');
    text(2,1,sprintf('FN\n%d',FN_A),'Horiz','center','Color',[0.8 0.1 0.1],'FontWeight','bold');
    text(1,2,sprintf('FP\n%d',FP_A),'Horiz','center','Color',[0.8 0.1 0.1],'FontWeight','bold');
    text(2,2,sprintf('TN\n%d',TN_A),'Horiz','center','Color',[0.0 0.6 0.0],'FontWeight','bold');

    % ---------------------------------------------------------------------
    % Subplot 2: Adaptive K-means Matrix
    % ---------------------------------------------------------------------
    subplot(1,2,2); 
    imagesc(matrix_data_B); 
    colormap(flipud(bone)); 
    axis square; 
    
    set(gca, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0]);
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Pred Water', 'Pred Land'}, ...
             'YTick', 1:2, 'YTickLabel', {'True Water', 'True Land'}, ...
             'FontWeight', 'bold');
         
    title(sprintf('Adaptive K-means Matrix\nOverall Accuracy: %.1f%%', Acc_B), ...
          'Color', [0 0 0], 'FontWeight', 'bold');
      
    text(1,1,sprintf('TP\n%d',TP_B),'Horiz','center','Color',[0.0 0.6 0.0],'FontWeight','bold');
    text(2,1,sprintf('FN\n%d',FN_B),'Horiz','center','Color',[0.8 0.1 0.1],'FontWeight','bold');
    text(1,2,sprintf('FP\n%d',FP_B),'Horiz','center','Color',[0.8 0.1 0.1],'FontWeight','bold');
    text(2,2,sprintf('TN\n%d',TN_B),'Horiz','center','Color',[0.0 0.6 0.0],'FontWeight','bold');

    % --- Global Super Title (Project File Name) ---
    if nargin >= 13 && ~isempty(name2proj)
        clean_title = strrep(name2proj, '_', '\_'); 
        sgtitle(clean_title, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0], 'Interpreter', 'tex');
    end

    % Export setup
    exportgraphics(fig3, fullfile(export_dir, 'metric_3_confusion_matrices.png'), 'Resolution', 300, 'BackgroundColor', 'w');
    if ~showfigs, close(fig3); end
end