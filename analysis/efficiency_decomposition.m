%==========================================================================
%   WHERE THE EFFICIENCY DIFFERENCE BETWEEN THE BUDGET RULE (delta = 0.02)
%   AND THE FIXED COST 0.3 COMES FROM, 28 seeds (1..28), by frame window:
%     alive, rep/fr   live devices and replicas per frame (per seed)
%     EE              decoded / replicas
%     xshare          share of the replicas whose count was drawn by exploration
%     EEexp, EEgrd    EE of the exploratory and of the greedy decisions
%     good|g, good|all  share of the replicas on slots whose link is decodable
%     P(d|g1)         decoding probability of a greedy decision with at least
%                     one replica on a decodable slot
%   and the decomposition of the EE difference over the mission (frames 31-1500).
%==========================================================================
clear; here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, '..'));
phy = phySetup(); base = baseConfig(); base.log_devices = true; H = base.H; nseed = 28;
cfgs = {struct('budget', false, 'c', 0.3), struct('budget', true, 'c', 0.3)};
lbl = {'fixed cost 0.3', 'budget rule, delta = 0.02'};
win = [101 400; 401 800; 801 1200; 1201 1400; 1401 1500; 31 1500];
X = zeros(2, 3);                      % mission window: xshare, EEexp, EEgrd of each strategy
for i = 1:2
    cfg = base; cfg.budget = cfgs{i}.budget; cfg.delta = 0.02; cfg.energy_cost = cfgs{i}.c;
    ACC = cell(nseed, 1);
    parfor sd = 1:nseed
        r = runMission(cfg, phy, sd);
        P = r.REPS; v = ~isnan(P); P(~v) = 0; D = r.DEC; D(isnan(D)) = 0; E = r.EXPL & v; G = r.GOOD;
        A = zeros(size(win,1), 13);
        for w = 1:size(win,1)
            k = win(w,1):win(w,2);
            p = P(:,k); dd = D(:,k); e = E(:,k); g = G(:,k); vv = v(:,k); tx = p > 0;
            A(w,:) = [sum(vv(:)), sum(p(:)), sum(dd(:)), ...
                      sum(p(e)), sum(dd(e & tx)), ...              % exploratory decisions
                      sum(p(~e & vv)), sum(dd(~e & tx)), ...       % greedy decisions
                      sum(g(~e & vv)), sum(g(:)), ...              % replicas on decodable slots
                      sum(~e(:) & tx(:)), sum(~e(:) & g(:) > 0), sum(dd(~e & g > 0)), numel(k)];
        end
        ACC{sd} = A;
    end
    S = zeros(size(ACC{1})); for sd = 1:nseed, S = S + ACC{sd}; end
    fprintf('\n== %s (%d seeds)\n', lbl{i}, nseed);
    fprintf('%10s %6s %7s %6s | %6s %6s %6s | %7s %7s | %7s\n', 'frames', 'alive', 'rep/fr', 'EE', 'xshare', 'EEexp', 'EEgrd', 'good|g', 'good|all', 'P(d|g1)');
    for w = 1:size(win,1)
        s = S(w,:); nf = s(13);                    % frames summed over the seeds
        fprintf('%4d-%5d %6.1f %7.1f %6.3f | %6.3f %6.3f %6.3f | %7.3f %7.3f | %7.3f\n', win(w,1), win(w,2), s(1)/nf, s(2)/nf, s(3)/s(2), ...
                s(4)/s(2), s(5)/max(s(4),1), s(7)/s(6), s(8)/s(6), s(9)/s(2), s(12)/s(11));
    end
    s = S(end,:); X(i,:) = [s(4)/s(2), s(5)/max(s(4),1), s(7)/s(6)];
end
% EE = x*EEexp + (1-x)*EEgrd; difference fixed - rule split in three terms
xf = X(1,1); xr = X(2,1);
EEf = xf*X(1,2) + (1-xf)*X(1,3); EEr = xr*X(2,2) + (1-xr)*X(2,3);
t = [(xr - xf)*(X(2,3) - X(2,2)), xf*(X(1,2) - X(2,2)), (1 - xf)*(X(1,3) - X(2,3))];
fprintf('\nEE over the mission: fixed %.3f, rule %.3f, difference %.3f\n', EEf, EEr, EEf - EEr);
fprintf('  share of exploratory replicas (%.3f -> %.3f): %.3f (%.0f%%)\n', xf, xr, t(1), 100*t(1)/sum(t));
fprintf('  EE of the exploratory replicas (%.3f -> %.3f): %.3f (%.0f%%)\n', X(1,2), X(2,2), t(2), 100*t(2)/sum(t));
fprintf('  EE of the greedy replicas (%.3f -> %.3f):      %.3f (%.0f%%)\n', X(1,3), X(2,3), t(3), 100*t(3)/sum(t));
