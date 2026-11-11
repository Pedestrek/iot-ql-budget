function [results] = runMission(cfg, phy, seed, frames)
%==========================================================================
%   One independent mission (one seed) of calcQL_mission.
%
%   cfg fields:
%     M, C, R             devices, channels, rate threshold
%     alpha, gamma, epsilon
%     H, e_s              mission length [frames], standby per frame
%     bat_mean, s         battery = bat_mean*(1 + s*(2*rand - 1)),
%                         i.e. uniform in bat_mean*[1-s, 1+s]
%     budget, delta       budget rule on/off and its step
%     energy_cost         fixed cost (budget off) or initial cost (budget on)
%     log_devices         (optional) per-device matrices, see calcQL_mission
%   frames = frames simulated (default cfg.H)
%
%   The seed fixes channel, batteries and learning, so a fixed cost and the
%   budget rule are compared over the same realizations.
%==========================================================================
    if nargin < 4 || isempty(frames), frames = cfg.H; end
    rng(seed, 'twister');
    model = struct('M', cfg.M, 't', phy.t, 'R', cfg.R, 'C', cfg.C, 'SNRdB', channelSNR(phy, cfg.M));
    model.alpha = cfg.alpha;
    model.gamma = cfg.gamma;
    model.epsilon = cfg.epsilon;
    model.H = cfg.H;
    model.e_s = cfg.e_s;
    model.battery = cfg.bat_mean*(1 + cfg.s*(2*rand(cfg.M,1) - 1));
    model.budget = cfg.budget;
    model.delta = cfg.delta;
    model.energy_cost = cfg.energy_cost;
    if isfield(cfg, 'log_devices'), model.log_devices = cfg.log_devices; end
    [results] = calcQL_mission(model, frames);
end
