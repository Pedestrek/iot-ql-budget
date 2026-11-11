function [MEAN, n, hist] = convergeSeeds(fun, first, step, tol, cap)
%==========================================================================
%   Average fun(seed) over seeds until the mean converges.
%
%   Runs `first` seeds, then batches of `step` seeds, and stops when the
%   relative L2 change of every row of the mean between two batches is
%   below `tol` (e.g. 0.01 = 1%), or when `cap` seeds have been used.
%   With first = cap the number of seeds is simply fixed.
%
%   fun(seed) must return a numeric matrix (one row per curve/metric).
%   Seeds are 1001, 1002, ... so every configuration sees the same channel
%   and battery realizations. Uses parfor when a pool is available.
%==========================================================================
    SUM = 0; n = 0; prev = []; hist = zeros(0,2);
    batch = first;
    while true
        seeds = 1000 + ((n+1):(n+batch));
        acc = 0;
        parfor j = 1:numel(seeds)
            acc = acc + fun(seeds(j));
        end
        SUM = SUM + acc; n = n + batch;
        MEAN = SUM / n;
        if ~isempty(prev)
            change = 0;
            for row = 1:size(MEAN,1)
                a = MEAN(row,:); p = prev(row,:); ok = ~isnan(a) & ~isnan(p);
                change = max(change, norm(a(ok)-p(ok)) / max(norm(p(ok)), 1e-12));
            end
            hist(end+1,:) = [n change]; %#ok<AGROW>
            fprintf('    %3d seeds: largest change %.2f%%\n', n, 100*change);
            if change < tol, break; end
        end
        if n >= cap, break; end
        prev = MEAN; batch = step;
    end
end
