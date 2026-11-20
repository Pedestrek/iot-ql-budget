%==========================================================================
%   WHY A VERY SMALL STEP (delta = 0.0005) DELIVERS MORE AND SURVIVES LESS
%   THAN THE FIXED COST 0.3 IT STARTS FROM. 28 seeds (1..28), the same as
%   device_spending.m. For each initial-battery quartile: survival at H,
%   mean cost, replicas per frame while alive, replica budget
%   (battery/H - e_s) and median depletion frame of the devices that run
%   out; mean cost of the lowest and highest quartiles along the mission.
%==========================================================================
clear; here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, '..'));
phy = phySetup(); base = baseConfig(); base.log_devices = true; H = base.H; nseed = 28;
cases = {struct('budget', false, 'delta', 0), struct('budget', true, 'delta', 0.0005), struct('budget', true, 'delta', 0.02)};
kk = [50 200 400 600 800 1000 1200 1400];
for i = 1:numel(cases)
    cfg = base; cfg.budget = cases{i}.budget; cfg.delta = cases{i}.delta; cfg.energy_cost = 0.3;
    B0 = cell(nseed,1); ALIVE = cell(nseed,1); MC = cell(nseed,1); SP = cell(nseed,1); CK = cell(nseed,1); DF = cell(nseed,1);
    DEC = zeros(nseed,1);
    parfor sd = 1:nseed
        r = runMission(cfg, phy, sd);
        v = ~isnan(r.REPS);
        B0{sd} = r.battery0; ALIVE{sd} = r.battery_final(:) > 0; DF{sd} = r.death_frame(:);
        MC{sd} = sum(r.COST .* v, 2, 'omitnan') ./ max(sum(v, 2), 1);
        SP{sd} = sum(r.REPS .* v, 2, 'omitnan') ./ max(sum(v, 2), 1);
        CK{sd} = r.COST(:, kk); DEC(sd) = sum(r.DEC(:), 'omitnan');
    end
    b0 = cat(1, B0{:}); al = cat(1, ALIVE{:}); mc = cat(1, MC{:}); sp = cat(1, SP{:}); ck = cat(1, CK{:}); df = cat(1, DF{:});
    q = quantile(b0, [0.25 0.5 0.75]); g = 1 + (b0 > q(1)) + (b0 > q(2)) + (b0 > q(3));
    if cases{i}.budget, lbl = sprintf('budget rule, delta = %g', cases{i}.delta); else, lbl = 'fixed cost 0.3'; end
    fprintf('\n== %s: survival %.1f%%, packets per seed %.0f\n', lbl, 100*mean(al), mean(DEC));
    for k = 1:4
        s = g == k;
        fprintf('  quartile %d: battery %.0f, survival %.1f%%, mean cost %.3f, replicas/frame %.3f, budget %.3f, median depletion %.0f\n', ...
                k, mean(b0(s)), 100*mean(al(s)), mean(mc(s)), mean(sp(s)), mean(b0(s))/H - base.e_s, median(df(s & ~al), 'omitnan'));
    end
    for k = [1 4]
        fprintf('  quartile %d, mean cost at frames %s: %s\n', k, mat2str(kk), sprintf('%.3f ', mean(ck(g == k, :), 1, 'omitnan')));
    end
end
