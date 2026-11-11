function [C] = seriesCurves(SUM, n, M)
%==========================================================================
%   Mean curves from the summed series of missionSeries over n seeds.
%   Frames with less than 10% of the network alive are set to NaN: there
%   the mean is taken over a few devices and does not represent the system.
%==========================================================================
    alive = SUM(2,:) / n;
    valid = SUM(13,:);
    mask = alive < 0.10*M;

    C.survival = 100 * alive / M;                       % live devices [%]
    C.throughput = SUM(3,:) / n;                        % decoded per frame (scaled by caller)
    C.cost = SUM(1,:) ./ SUM(2,:);                      % mean cost of the live devices
    C.cost(SUM(2,:) == 0 | mask) = NaN;
    C.reps_per_alive = SUM(4,:) ./ max(SUM(2,:), eps);  % replicas per live device
    C.reps_per_alive(mask) = NaN;

    names = {'p10','p25','p50','p75','p90','low_bat','high_bat','std'};
    for q = 1:numel(names)
        x = SUM(4+q,:) ./ valid;
        x(valid == 0 | mask) = NaN;
        C.(names{q}) = x;
    end
end
