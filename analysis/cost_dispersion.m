%==========================================================================
%   IS THERE A PERSISTENT DIFFERENTIATION OF THE COST BETWEEN DEVICES?
%   Budget rule, delta = 0.02, identical (s = 0) and heterogeneous (s = 0.5)
%   batteries, 28 seeds (1..28), frames 31-1500: spread across devices of the
%   time-averaged cost, share of the cost variance that is between devices
%   (the rest is the oscillation of each device), and correlation of the
%   mean cost with the initial battery and with the decodable slots.
%==========================================================================
clear; here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, '..'));
phy = phySetup(); base = baseConfig(); base.log_devices = true; H = base.H; nseed = 28;
base.budget = true; base.delta = 0.02; base.energy_cost = base.cost0;
for s = [0 0.5]
    cfg = base; cfg.s = s;
    MC = cell(nseed,1); SDW = cell(nseed,1); B0 = cell(nseed,1); NG = cell(nseed,1); SP = cell(nseed,1);
    VB = zeros(nseed,1); VT = zeros(nseed,1);
    parfor sd = 1:nseed
        r = runMission(cfg, phy, sd);
        rng(sd, 'twister'); snr = channelSNR(phy, cfg.M);              % the channel runMission drew for this seed
        C = r.COST(:, 31:H); v = ~isnan(C);
        mc = sum(C.*v, 2, 'omitnan') ./ max(sum(v,2), 1);            % time-averaged cost of each device
        dev = C - mc; dev(~v) = NaN;
        sdw = sqrt(mean(dev.^2, 2, 'omitnan'));                       % within-device spread (oscillation)
        VT(sd) = var(C(v), 1);                                        % total variance of the cost (device-frames)
        w = sum(v,2) / sum(v(:));
        VB(sd) = sum(w .* (mc - sum(w.*mc)).^2);                      % between-device variance
        P = r.REPS; pv = ~isnan(P);
        SP{sd} = sum(P.*pv, 2, 'omitnan') ./ max(sum(pv,2), 1);
        MC{sd} = mc; SDW{sd} = sdw; B0{sd} = r.battery0;
        NG{sd} = sum(log2(1 + 10.^(snr/10)) > cfg.R, 2);              % decodable slots of each device
    end
    mc = vertcat(MC{:}); sdw = vertcat(SDW{:}); b0 = vertcat(B0{:}); ng = vertcat(NG{:}); sp = vertcat(SP{:});
    fprintf('\n== s = %g (%d seeds, delta = 0.02, frames 31-%d)\n', s, nseed, H);
    fprintf('time-averaged cost per device: mean %.3f, std across devices %.3f, p10 %.3f, p90 %.3f\n', mean(mc), std(mc), quantile(mc, 0.1), quantile(mc, 0.9));
    fprintf('within-device spread (oscillation), mean std %.3f\n', mean(sdw));
    fprintf('share of cost variance between devices: %.1f%%\n', 100*mean(VB ./ VT));
    if s > 0, fprintf('corr(mean cost, initial battery) = %.3f\n', corr(mc, b0)); end
    fprintf('corr(mean cost, decodable slots) = %.3f ; corr(mean cost, replicas per frame) = %.3f\n', corr(mc, ng), corr(mc, sp));
    q = quantile(ng, [0.25 0.75]);
    fprintf('mean cost: fewest decodable slots (<%g) %.3f ; most (>%g) %.3f\n', q(1), mean(mc(ng < q(1))), q(2), mean(mc(ng > q(2))));
end
