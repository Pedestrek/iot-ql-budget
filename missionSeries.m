function [S] = missionSeries(cfg, phy, seed, frames)
%==========================================================================
%   Per-frame series of one mission, stored as SUMS so that they can be
%   accumulated over seeds without bias (divide by the right row later):
%     1      sum of the cost of the live devices   (mean cost = row1/row2)
%     2      live devices
%     3      decoded devices
%     4      replicas transmitted
%     5-9    p10, p25, p50, p75, p90 of the cost       (x valid)
%     10-11  mean cost of the 25% lowest / highest battery (x valid)
%     12     standard deviation of the cost            (x valid)
%     13     valid = more than 3 live devices (dispersion statistics)
%==========================================================================
    r = runMission(cfg, phy, seed, frames);
    v = double(r.alive_frame > 3);
    zz = @(x) nan2zero(x) .* v;              % invalid frames contribute 0
    cost = nan2zero(r.cost_frame);
    S = [ cost .* r.alive_frame;
          r.alive_frame;
          r.succ_frame;
          r.reps_frame;
          zz(r.cost_prctile(1,:)); zz(r.cost_prctile(2,:)); zz(r.cost_prctile(3,:));
          zz(r.cost_prctile(4,:)); zz(r.cost_prctile(5,:));
          zz(r.cost_low_bat); zz(r.cost_high_bat);
          zz(r.cost_std);
          v ];
end

function x = nan2zero(x)
    x(isnan(x)) = 0;
end
