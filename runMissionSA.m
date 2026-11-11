function [results] = runMissionSA(cfg, phy, seed, frames)
%==========================================================================
%   One mission (one seed) of calcSA_mission. The random stream is consumed
%   in the same order as in runMission (channel, then batteries), so SA and
%   QL see the same channel and the same batteries for a given seed.
%   cfg: the fields of runMission plus
%     p        transmission probability (fixed SA, cfg.budget = false)
%     budget   true for the budgeted SA
%==========================================================================
    if nargin < 4 || isempty(frames), frames = cfg.H; end
    rng(seed, 'twister');
    model = struct('M', cfg.M, 't', phy.t, 'R', cfg.R, 'C', cfg.C, 'SNRdB', channelSNR(phy, cfg.M));
    model.H = cfg.H;
    model.e_s = cfg.e_s;
    model.battery = cfg.bat_mean*(1 + cfg.s*(2*rand(cfg.M,1) - 1));
    model.budget = cfg.budget;
    if isfield(cfg, 'p'), model.p = cfg.p; end
    [results] = calcSA_mission(model, frames);
end
