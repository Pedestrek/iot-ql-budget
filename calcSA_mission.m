function [results] = calcSA_mission(model, runs)
%==========================================================================
%   SLOTTED ALOHA OVER A MISSION OF H FRAMES WITH FINITE BATTERIES
%
%   Same frame, channel, battery and standby model as calcQL_mission, but
%   without learning: in each frame, every device with battery transmits
%   one packet (one replica) on a random slot/channel with probability p.
%     - fixed p:       model.budget = false, model.p in [0, 1]
%     - budgeted SA:   model.budget = true; p is chosen so that the expected
%                      spending follows the budget of the device,
%                      p = min(1, max(0, budget - e_s)),
%                      budget = battery / max(H - k + 1, 1)
%   A packet alone in its resource is decoded if log2(1 + SNR) > R
%   (with a single replica there is nothing to cancel by SIC).
%
%   runs = number of frames simulated (as in calcQL_mission).
%==========================================================================

%==========================================================================
%   MODEL PARAMETERS
%==========================================================================
    M = model.M;
    t = model.t;
    R = model.R;
    C = model.C;
    SNR_linear = 10.^(model.SNRdB / 10);
    num_slots = length(t);
    H = model.H;
    e_s = model.e_s;
    battery = model.battery(:);
    use_budget = model.budget;
    if ~use_budget, p_fixed = model.p; end

%==========================================================================
%   METRIC ACCUMULATORS (ONE ENTRY PER FRAME)
%==========================================================================
    alive_frame = zeros(1, runs);
    succ_frame = zeros(1, runs);
    reps_frame = zeros(1, runs);
    success_per_user = zeros(M, 1);

    for loop_runs = 1:runs
        alive = battery > 0;
        alive_frame(loop_runs) = sum(alive);
        if ~any(alive), break; end

        % --- Step 1: who transmits, and where ---
        if use_budget
            p = min(1, max(0, battery / max(H - loop_runs + 1, 1) - e_s));
        else
            p = p_fixed * ones(M, 1);
        end
        tx = alive & (rand(M, 1) < p) & (battery >= 1);
        resource = randi(num_slots * C, M, 1);           % slot/channel of each packet
        resource(~tx) = 0;

        % --- Step 2: decoding (packet alone in its resource and SNR above the threshold) ---
        decoded = false(M, 1);
        for m = find(tx)'
            if sum(resource == resource(m)) == 1
                n = mod(resource(m) - 1, num_slots) + 1;
                decoded(m) = log2(1 + SNR_linear(m, n)) > R;
            end
        end

        % --- Step 3: battery ---
        battery(alive) = max(battery(alive) - double(tx(alive)) - e_s, 0);

        success_per_user = success_per_user + decoded;
        succ_frame(loop_runs) = sum(decoded);
        reps_frame(loop_runs) = sum(tx);
    end

%==========================================================================
%   FINAL METRICS (SAME DEFINITIONS AS calcQL_mission)
%==========================================================================
    k_end = min(H, runs);
    results.survival = 100 * alive_frame(k_end) / M;
    results.delivered = sum(succ_frame(1:k_end));
    results.throughput = R * results.delivered / (C * num_slots * H);
    results.goodput = results.delivered / max(sum(alive_frame(1:k_end)), 1);
    results.energy_efficiency = results.delivered / max(sum(reps_frame(1:k_end)), 1);
    results.p_m = success_per_user / runs;
    results.alive_frame = alive_frame;
    results.succ_frame = succ_frame;
    results.reps_frame = reps_frame;
end
