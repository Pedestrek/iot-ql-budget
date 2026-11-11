%==========================================================================
%   VALIDATION: without the energy constraints (infinite battery, no
%   standby, fixed cost 0.2), the mission model (calcQL_mission) must
%   reproduce the scheme of the article (calcQL, unchanged) on the same
%   channels. 20 seeds of 3000 frames, M = 80, C = 2.
%==========================================================================
clear; here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, '..'));
phy = phySetup(); M = 80; C = 2; R = 0.5; frames = 3000; seeds = 20;
out = zeros(seeds, 6);
parfor k = 1:seeds
    rng(1000 + k, 'twister');
    SNRdB = channelSNR(phy, M);
    base = struct('M', M, 't', phy.t, 'R', R, 'C', C, 'SNRdB', SNRdB);
    a = base; a.n_replicas_max = 3; a.alpha = 0.3; a.gamma = 0.7; a.epsilon = 0.1; a.energy_cost = 0.2;
    r1 = calcQL(a, frames);                                 % article
    b = base; b.alpha = 0.3; b.gamma = 0.7; b.epsilon = 0.1; b.H = frames; b.e_s = 0;
    b.battery = inf(M, 1); b.budget = false; b.delta = 0; b.energy_cost = 0.2;
    r2 = calcQL_mission(b, frames);                         % mission model without the energy constraints
    out(k,:) = [r1.throughput, r1.energy_efficiency, r1.goodput, r2.throughput, R*r2.energy_efficiency, sum(r2.succ_frame)/(M*frames)];
end
m = mean(out); sd = std(out);
fprintf('\n%d seeds, %d frames, M = %d, C = %d, cost 0.2\n', seeds, frames, M, C);
fprintf('%22s %14s %14s %10s\n', '', 'article', 'mission model', 'difference');
nm = {'throughput', 'efficiency (R d/n)', 'delivered fraction'};
for i = 1:3
    fprintf('%22s %8.4f±%.3f %8.4f±%.3f %+9.1f%%\n', nm{i}, m(i), sd(i), m(i+3), sd(i+3), 100*(m(i+3)/m(i) - 1));
end
