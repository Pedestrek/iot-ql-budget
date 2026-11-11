%==========================================================================
%   PER-DEVICE SPENDING x BATTERY (fixed costs 0.3 and 0.7, budget rule
%   delta = 0.02), 28 seeds (1..28). For each initial-battery quartile:
%   replica budget (battery/H - e_s), replicas per frame while alive,
%   devices alive at H, energy left, mean cost and fraction of frames at
%   zero cost; correlation between spending and battery; lengths of the
%   runs of silent and of transmitting frames.
%==========================================================================
clear; here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, '..'));
phy = phySetup(); base = baseConfig(); base.log_devices = true; H = base.H; nseed = 28;
cfgs = {struct('budget', false, 'c', 0.3), struct('budget', false, 'c', 0.7), struct('budget', true, 'c', 0.3)};
lbl = {'fixed cost 0.3', 'fixed cost 0.7', 'budget rule, delta = 0.02'};
for i = 1:3
    cfg = base; cfg.budget = cfgs{i}.budget; cfg.delta = 0.02; cfg.energy_cost = cfgs{i}.c;
    B0 = cell(nseed,1); SP = cell(nseed,1); LEFT = cell(nseed,1); DEAD = cell(nseed,1); ZF = cell(nseed,1);
    RUNS = cell(nseed,1); RUNT = cell(nseed,1); MC = cell(nseed,1);
    parfor sd = 1:nseed
        r = runMission(cfg, phy, sd);
        P = r.REPS; v = ~isnan(P);
        SP{sd} = sum(P .* v, 2, 'omitnan') ./ max(sum(v, 2), 1);       % replicas per frame while alive
        B0{sd} = r.battery0; LEFT{sd} = r.battery_final; DEAD{sd} = r.death_frame;
        ZF{sd} = mean(r.COST <= 0 & v, 2) ./ max(mean(v, 2), eps);
        MC{sd} = sum(r.COST .* v, 2, 'omitnan') ./ max(sum(v, 2), 1);
        % lengths of silent runs and of transmitting runs (alive frames only, after frame 30)
        ls = []; lt = [];
        for m = 1:cfg.M
            x = P(m, 31:end); x = x(~isnan(x)) > 0;
            if isempty(x), continue; end
            e = [true diff(x) ~= 0 true]; idx = find(e); len = diff(idx); val = x(idx(1:end-1));
            ls = [ls len(~val)]; lt = [lt len(val)];
        end
        RUNS{sd} = ls; RUNT{sd} = lt;
    end
    b0 = vertcat(B0{:}); sp = vertcat(SP{:}); left = vertcat(LEFT{:}); dead = vertcat(DEAD{:}); zf = vertcat(ZF{:}); mc = vertcat(MC{:});
    rs = [RUNS{:}]; rt = [RUNT{:}];
    target = b0/H - cfg.e_s;    % replicas per frame that would last exactly H frames
    fprintf('\n== %s\n', lbl{i});
    fprintf('energy: total %.0f per seed, left at H %.1f%%\n', sum(b0)/nseed, 100*sum(left)/sum(b0));
    fprintf('corr(battery, spending) = %.3f ; slope spending vs target = %.3f\n', corr(b0, sp), [0 1] * ([ones(size(target)) target] \ sp));
    q = quantile(b0, [0.25 0.5 0.75]);
    grp = {b0 < q(1), b0 >= q(1) & b0 < q(2), b0 >= q(2) & b0 < q(3), b0 >= q(3)};
    for g = 1:4
        fprintf('  battery quartile %d: target %.3f spend %.3f alive@H %.1f%% left %.1f%% mean cost %.3f zero-cost %.2f mean death %.0f\n', ...
                g, mean(target(grp{g})), mean(sp(grp{g})), 100*mean(isnan(dead(grp{g}))), 100*sum(left(grp{g}))/sum(b0(grp{g})), ...
                mean(mc(grp{g})), mean(zf(grp{g})), mean(dead(grp{g}), 'omitnan'));
    end
    fprintf('silent runs: mean %.1f, median %.0f, p90 %.0f | transmit runs: mean %.1f, median %.0f, p90 %.0f\n', ...
            mean(rs), median(rs), quantile(rs, 0.9), mean(rt), median(rt), quantile(rt, 0.9));
end
