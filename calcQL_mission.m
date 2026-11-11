function [results] = calcQL_mission(model, runs)
%==========================================================================
%   Q-LEARNING OVER A MISSION OF H FRAMES WITH FINITE BATTERIES
%
%   Same two Q-tables, update rule and geometry as calcQL. Differences:
%     - each device has a battery measured in replicas (1 replica = 1 unit)
%       and spends a standby cost e_s every frame, even when silent;
%     - replica actions are 0..n_replicas_max (0 = skip this pass);
%     - Q-tables start at 1e-6*randn instead of zeros;
%     - each device has its own energy cost. With model.budget = true it is
%       regulated towards the per-frame budget that would make the battery
%       last until the end of the mission (frame H):
%           spent  = n + e_s
%           budget = battery / max(H - k, 1)
%           cost   = min(cost_max, max(0, cost + delta*(spent - budget)))
%       With model.budget = false the cost stays fixed (the article model).
%
%   runs = number of frames simulated (as in calcQL, each run is one frame
%          and the Q-tables persist between runs). Use runs > H to follow
%          the network after the end of the mission.
%
%   model.log_devices = true (optional) also returns per-device, per-frame
%   matrices (M x runs) for the analyses of the folder analysis/:
%       COST  energy cost used in the frame       REPS  replicas sent
%       DEC   decoded (1) or not (0)              EXPL  replica count drawn by exploration
%       GOOD  replicas on slots whose link is decodable (log2(1+SNR) > R)
%   (NaN or 0 for devices without battery).
%==========================================================================

%==========================================================================
%   MODEL PARAMETERS
%==========================================================================
    M = model.M;
    t = model.t;
    R = model.R;
    C = model.C;
    SNR = model.SNRdB;
    SNR_linear = 10.^(SNR / 10);
    num_slots = length(t);

    alpha = model.alpha;              % learning rate
    epsilon = model.epsilon;
    gamma = model.gamma;
    H = model.H;                      % mission length [frames]
    e_s = model.e_s;                  % standby consumption per frame
    battery = model.battery(:);       % initial battery of each device [replicas]
    battery0 = battery;
    use_budget = model.budget;
    log_devices = isfield(model, 'log_devices') && model.log_devices;
    delta = model.delta;              % budget rule step
    cost_max = 1.5;
    if isfield(model, 'n_replicas_max'), n_max = model.n_replicas_max; else, n_max = 3; end

    replica_actions = 0:n_max;        % index 1 -> 0 replicas (skip the pass)
    energy_cost_m = model.energy_cost * ones(M, 1);   % initial (or fixed) cost
    Q_table_replicas = 1e-6*randn(M, length(replica_actions));
    Q_table_tx = 1e-6*randn(M, num_slots * C);

%==========================================================================
%   METRIC ACCUMULATORS (ONE ENTRY PER FRAME)
%==========================================================================
    alive_frame = zeros(1, runs);     % devices with battery at the start of the frame
    succ_frame = zeros(1, runs);      % devices decoded in the frame
    reps_frame = zeros(1, runs);      % replicas transmitted in the frame
    silent_frame = zeros(1, runs);    % fraction of live devices that skipped the pass
    cost_frame = zeros(1, runs);      % mean energy cost of the live devices
    cost_prctile = nan(5, runs);      % p10, p25, p50, p75, p90 of the cost
    cost_std = nan(1, runs);          % spread of the cost between devices
    cost_low_bat = nan(1, runs);      % mean cost of the 25% with the lowest battery
    cost_high_bat = nan(1, runs);     % mean cost of the 25% with the highest battery
    success_per_user = zeros(M, 1);
    death_frame = nan(M, 1);
    chosen_replica_idx = zeros(M, 1);
    if log_devices
        COST = nan(M, runs); REPS = nan(M, runs); DEC = nan(M, runs);
        EXPL = false(M, runs); GOOD = zeros(M, runs);
    end

    for loop_runs = 1:runs
        alive = battery > 0;
        alive_frame(loop_runs) = sum(alive);
        if ~any(alive), break; end    % network extinct

        frame_buffer = cell(C, num_slots);
        user_transmissions = cell(M, 1);
        n_replicas_used = zeros(M, 1);

        % --- Step 1: Agent Actions (only devices with battery) ---
        for m = find(alive)'
            % Action 1: Choose number of replicas (0 = skip the pass)
            if rand < epsilon
                rep_idx = randi(length(replica_actions));
                if log_devices, EXPL(m, loop_runs) = true; end
            else
                [~, rep_idx] = max(Q_table_replicas(m,:));
            end
            n_reps = min(replica_actions(rep_idx), floor(battery(m)));   % cannot spend what it does not have
            chosen_replica_idx(m) = find(replica_actions == n_reps, 1);  % action actually taken
            n_replicas_used(m) = n_reps;

            % Action 2: Choose slot/channel for each replica
            available_actions = 1:(num_slots*C);
            txs = zeros(n_reps, 1);
            for r_i = 1:n_reps
                if rand < epsilon % Explore
                    idx = randi(length(available_actions));
                    tx = available_actions(idx);
                    available_actions(idx) = [];
                else % Exploit
                    [~, best_idx] = max(Q_table_tx(m, available_actions));
                    tx = available_actions(best_idx);
                    available_actions(best_idx) = [];
                end
                txs(r_i) = tx;

                slot_idx = mod(tx-1, num_slots) + 1;
                chan_idx = floor((tx-1)/num_slots) + 1;
                if log_devices, GOOD(m, loop_runs) = GOOD(m, loop_runs) + (log2(1 + SNR_linear(m, slot_idx)) > R); end
                frame_buffer{chan_idx, slot_idx} = [frame_buffer{chan_idx, slot_idx}, m];
            end
            user_transmissions{m} = txs;
        end
        if log_devices
            COST(alive, loop_runs) = energy_cost_m(alive); REPS(alive, loop_runs) = n_replicas_used(alive);
        end

        % --- Step 2: SIC Process (same as calcQL) ---
        decoded_users = false(M, 1);
        sic_frame_buffer = frame_buffer;
        while true
            newly_decoded = false;
            for c = 1:C
                for n = 1:num_slots
                    slot_content = sic_frame_buffer{c,n};
                    undecoded = slot_content(~decoded_users(slot_content));
                    if length(undecoded) == 1
                        u = undecoded(1);
                        if log2(1 + SNR_linear(u, n)) > R
                            decoded_users(u) = true;
                            newly_decoded = true;

                            reps = user_transmissions{u};
                            for rep = 1:length(reps)
                                tx = reps(rep);
                                rep_slot = mod(tx-1,num_slots)+1;
                                rep_chan = floor((tx-1)/num_slots)+1;
                                current_slot_users = sic_frame_buffer{rep_chan,rep_slot};
                                sic_frame_buffer{rep_chan,rep_slot} = current_slot_users(current_slot_users ~= u);
                            end
                        end
                    end
                end
            end
            if ~newly_decoded, break; end
        end

        % --- Step 3: Q-table Updates, Battery and Energy Cost ---
        for m = find(alive)'
            n_reps = n_replicas_used(m);
            if decoded_users(m)
                reward = 1 - n_reps*energy_cost_m(m);
            else
                reward = -n_reps*energy_cost_m(m);
            end
            % Update replica choice Q-table
            a_rep = chosen_replica_idx(m);
            CurrentQValue = Q_table_replicas(m, a_rep);
            Q_table_replicas(m, a_rep) = (1-alpha)*CurrentQValue + alpha*(reward+gamma*CurrentQValue);

            % Update slot/channel choice Q-table
            for tx = user_transmissions{m}'
                CurrentQValue = Q_table_tx(m, tx);
                Q_table_tx(m, tx) = (1-alpha)*CurrentQValue + alpha*(reward+gamma*CurrentQValue);
            end

            % Battery and budget rule
            spent = n_reps + e_s;
            battery(m) = max(battery(m) - spent, 0);
            if battery(m) <= 0, death_frame(m) = loop_runs; end
            if use_budget
                budget = battery(m) / max(H - loop_runs, 1);   % what it may spend per frame from now on
                energy_cost_m(m) = min(cost_max, max(0, energy_cost_m(m) + delta*(spent - budget)));
            end
        end
        if log_devices, DEC(alive, loop_runs) = decoded_users(alive); end

        % --- Step 4: Per-frame Metrics ---
        success_per_user = success_per_user + decoded_users;
        succ_frame(loop_runs) = sum(decoded_users);
        reps_frame(loop_runs) = sum(n_replicas_used);
        silent_frame(loop_runs) = sum(alive & n_replicas_used == 0) / sum(alive);

        live = battery > 0;
        cost_frame(loop_runs) = mean(energy_cost_m(live));
        if sum(live) > 3
            cost_live = energy_cost_m(live);
            [~, order] = sort(battery(live));                 % lowest to highest battery
            nq = max(1, round(sum(live)/4));
            cost_prctile(:, loop_runs) = prctile(cost_live, [10 25 50 75 90])';
            cost_std(loop_runs) = std(cost_live);
            cost_low_bat(loop_runs) = mean(cost_live(order(1:nq)));
            cost_high_bat(loop_runs) = mean(cost_live(order(end-nq+1:end)));
        end
    end

%==========================================================================
%   FINAL METRICS (MEASURED AT THE END OF THE MISSION, FRAME H)
%==========================================================================
    k_end = min(H, runs);

    % Survival: % of the M devices that still have battery at frame H
    survival = 100 * alive_frame(k_end) / M;
    % Delivered: packets decoded during the mission
    delivered = sum(succ_frame(1:k_end));
    % Throughput: decoded packets per slot-channel, weighted by R
    throughput = R * delivered / (C * num_slots * H);
    % Goodput: successes per live device per frame
    goodput = sum(succ_frame(1:k_end)) / max(sum(alive_frame(1:k_end)), 1);
    % Energy Efficiency: successes per replica sent
    energy_efficiency = sum(succ_frame(1:k_end)) / max(sum(reps_frame(1:k_end)), 1);

    p_m = success_per_user / runs;

    results.survival = survival;
    results.delivered = delivered;
    results.throughput = throughput;
    results.goodput = goodput;
    results.energy_efficiency = energy_efficiency;
    results.p_m = p_m;                                     % deliveries per frame of each device
    results.mean_replicas = mean(reps_frame(1:k_end) ./ max(alive_frame(1:k_end), 1));
    results.frac_silent = mean(silent_frame(1:k_end));

    results.alive_frame = alive_frame;
    results.succ_frame = succ_frame;
    results.reps_frame = reps_frame;
    results.silent_frame = silent_frame;
    results.cost_frame = cost_frame;
    results.cost_prctile = cost_prctile;
    results.cost_std = cost_std;
    results.cost_low_bat = cost_low_bat;
    results.cost_high_bat = cost_high_bat;
    results.death_frame = death_frame;
    results.battery_final = battery;
    results.battery0 = battery0;
    if log_devices
        results.COST = COST; results.REPS = REPS; results.DEC = DEC;
        results.EXPL = EXPL; results.GOOD = GOOD;
    end
end
