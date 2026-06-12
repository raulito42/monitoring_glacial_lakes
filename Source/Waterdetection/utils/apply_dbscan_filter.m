function clean_mask = apply_dbscan_filter(raw_mask, XQ, YQ, dbscan_min_pts)
% APPLY_DBSCAN_FILTER Dynamic, distance-adaptive boundary extraction.

clean_mask = false(size(raw_mask));
if sum(raw_mask(:)) <= dbscan_min_pts, return; end

idx_linear = find(raw_mask);
pts = [XQ(idx_linear), YQ(idx_linear)]; % pts(:,1) = Range (X), pts(:,2) = Azimuth (Y)

% --- DISTANCE DEPENDENT EPSILON SCALING ---
min_range = min(XQ(:));
max_range = max(XQ(:));
eps_vector = 2.0 + (pts(:,1) - min_range) ./ (max_range - min_range) * 2.5;

% --- VECTORIZED RANGE-DEPENDENT DBSCAN ENGINE ---
idx_db = zeros(size(pts,1), 1);
cluster_id = 0;
visited = false(size(pts,1), 1);

for i = 1:size(pts,1)
    if visited(i), continue; end
    visited(i) = true;
    
    dists = sqrt((pts(:,1) - pts(i,1)).^2 + (pts(:,2) - pts(i,2)).^2);
    neighbors = find(dists <= eps_vector(i));
    
    if length(neighbors) >= dbscan_min_pts
        cluster_id = cluster_id + 1;
        idx_db(i) = cluster_id;
        
        k = 1;
        while k <= length(neighbors)
            curr_neighbor = neighbors(k);
            if ~visited(curr_neighbor)
                visited(curr_neighbor) = true;
                n_dists = sqrt((pts(:,1) - pts(curr_neighbor,1)).^2 + (pts(:,2) - pts(curr_neighbor,2)).^2);
                sub_neighbors = find(n_dists <= eps_vector(curr_neighbor));
                if length(sub_neighbors) >= dbscan_min_pts
                    neighbors = [neighbors; sub_neighbors(~ismember(sub_neighbors, neighbors))]; 
                end
            end
            if idx_db(curr_neighbor) == 0
                idx_db(curr_neighbor) = cluster_id;
            end
            k = k + 1;
        end
    end
end

% =========================================================================
% FIX: CHOOSE THE DOMINANT/LARGEST WATER CLUSTER IN THE TRACKING ZONE
% =========================================================================
unique_clusters = unique(idx_db(idx_db > 0));
if ~isempty(unique_clusters)
    cluster_sizes = zeros(size(unique_clusters));
    for c = 1:length(unique_clusters)
        cluster_sizes(c) = sum(idx_db == unique_clusters(c));
    end
    
    % Identify the largest contiguous cluster within the gridded ribbon
    [max_size, best_idx] = max(cluster_sizes);
    
    if max_size > 0
        clean_mask(idx_linear) = (idx_db == unique_clusters(best_idx));
    end
end