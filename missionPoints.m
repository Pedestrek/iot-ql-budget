function [P] = missionPoints(cfg, phy, seed, costs, deltas, k_eval)
%==========================================================================
%   One seed of the fixed-cost sweep and of the budget rule, in the same
%   scenario. Columns: costs(1..nf), then deltas(1..nd).
%   Rows, for each evaluation frame k in k_eval:
%     survival at frame k [%]   and   packets delivered up to frame k
%   then one last row with the energy efficiency over the mission.
%==========================================================================
    nf = numel(costs); nd = numel(deltas);
    frames = max([k_eval cfg.H]);
    P = zeros(2*numel(k_eval) + 1, nf + nd);
    for i = 1:(nf + nd)
        if i <= nf
            cfg.budget = false; cfg.delta = 0; cfg.energy_cost = costs(i);
        else
            cfg.budget = true; cfg.delta = deltas(i-nf); cfg.energy_cost = cfg.cost0;
        end
        r = runMission(cfg, phy, seed, frames);
        for e = 1:numel(k_eval)
            P(2*e-1, i) = 100 * r.alive_frame(k_eval(e)) / cfg.M;
            P(2*e,   i) = sum(r.succ_frame(1:k_eval(e)));
        end
        P(end, i) = r.energy_efficiency;
    end
end
