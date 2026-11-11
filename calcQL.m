function [results] = calcQL(model, runs)
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

%==========================================================================
%   METRIC ACCUMULATORS (INITIALIZED PER RUN)
%==========================================================================
    % These vectors will store the final result of each simulation run.
    total_successful_users_per_run = zeros(1, runs);
    total_replicas_sent_per_run = zeros(1, runs);

%==========================================================================
%   INITIALIZE GRIDS
%==========================================================================
    % These grids accumulate data across all runs for heatmap-style metrics.
    choice_grid = zeros(C, num_slots);    
    collision_grid = zeros(C, num_slots); 
    slot_success_grid = zeros(C, num_slots);   
    success_per_user = zeros(M, 1);          % <-- ADD

    alpha = model.alpha;
    epsilon = model.epsilon;
    gamma=model.gamma;
    energy_cost = model.energy_cost;
    replica_actions = 1:model.n_replicas_max;
    Q_table_replicas = zeros(M, length(replica_actions));
    Q_table_tx = zeros(M, num_slots * C);
    
    for loop_runs = 1:runs
        frame_buffer = cell(C, num_slots);
        user_transmissions = cell(M, 1);
        chosen_replica_idx = zeros(M,1);
        n_replicas_used = zeros(M,1);

        % --- Step 1: Agent Actions (Transmission) ---
        for m = 1:M
            % Action 1: Choose number of replicas
            if rand < epsilon
                rep_idx = randi(length(replica_actions));
            else
                [~, rep_idx] = max(Q_table_replicas(m,:));
            end
            n_reps = replica_actions(rep_idx);
            chosen_replica_idx(m) = rep_idx;
            n_replicas_used(m) = n_reps;
            
            % Action 2: Choose slot/channel for each replica
            available_actions = 1:(num_slots*C);
            txs = zeros(n_reps,1);
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
                frame_buffer{chan_idx, slot_idx} = [frame_buffer{chan_idx, slot_idx}, m];
                choice_grid(chan_idx, slot_idx) = choice_grid(chan_idx, slot_idx) + 1;
            end
            user_transmissions{m} = txs;
        end

        % --- Step 2: SIC Process (same as CRDSA) ---
        decoded_users = false(M,1);
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
                            slot_success_grid(c, n) = slot_success_grid(c, n) + 1;
                            
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

        % --- Step 3: Q-table Updates ---
        for m = 1:M
            if decoded_users(m)
                reward = 1 - (n_replicas_used(m) * energy_cost);
                %reward = 1/(n_replicas_used(m)*energy_cost);
            else
                % reward = - (n_replicas_used(m) * energy_cost); % Small penalty for failure
                reward = -n_replicas_used(m)*energy_cost; % Small penalty for failure
            end
            % Update replica choice Q-table
            a_rep = chosen_replica_idx(m);
            CurrentQValue=Q_table_replicas(m, a_rep);
            Q_table_replicas(m, a_rep) = (1-alpha)*CurrentQValue + alpha*(reward+gamma*CurrentQValue);
                     
            % Update slot/channel choice Q-table
            for tx = user_transmissions{m}'
                CurrentQValue=Q_table_tx(m, tx);
                Q_table_tx(m, tx) = (1-alpha)*CurrentQValue + alpha*(reward+gamma*CurrentQValue);
            end
        end

        success_per_user = success_per_user + decoded_users;   % <-- ADD (logo após o while da SIC)
        
        % --- Step 4: Final Calculations for this Run ---
        total_successful_users_per_run(loop_runs) = sum(decoded_users);
        total_replicas_sent_per_run(loop_runs) = sum(n_replicas_used);

        [~, chosen_actions] = max(Q_table_replicas, [], 2);
        average_choice(loop_runs) = mean(chosen_actions);
        
        % Calculate residual collisions
        for c = 1:C
            for n = 1:num_slots
                if length(sic_frame_buffer{c,n}) > 1
                    collision_grid(c,n) = collision_grid(c,n) + length(sic_frame_buffer{c,n});
                end
            end
        end
    end
    %% ---------------- Final Metrics Calculation ----------------
    % Calculate system-wide totals by summing the results from each run
    total_users_decoded_system = sum(total_successful_users_per_run);
    total_replicas_sent_system = sum(total_replicas_sent_per_run);

    % --- Grid-based (heatmap) metrics ---
    usage_rate = choice_grid / runs;
    collision_rate = collision_grid / runs;
    slot_channel_success = slot_success_grid ./ max(choice_grid, 1); % Avoid 0/0 -> NaN

    % --- System-wide performance metrics ---

    % Success Rate (SR): Fraction of users who succeeded. [Higher is better]
    success_rate = total_users_decoded_system / (M * runs);
    
    % Throughput (TP): Successful rate per slot-channel, weighted by R. [Higher is better]
    throughput = R * (total_users_decoded_system / (C * num_slots * runs));
    
    % Energy Efficiency (EE): Successful rate per replica sent. [Higher is better]
    if total_replicas_sent_system > 0
        energy_efficiency = (R * total_users_decoded_system) / total_replicas_sent_system;
    else
        energy_efficiency = 0;
    end

    fprintf('Average Replicas:        %.4f\n', mean(average_choice));
    
    % --- Display Results ---
    % fprintf('\n================== Results for QL ==================\n');
    % fprintf('Goodput (User Success Rate):           %.4f\n', success_rate);
    % fprintf('Throughput (Bits/s):                   %.4f\n', throughput);
    % fprintf('Energy Efficiency (Bits/Joule):        %.4f\n', energy_efficiency);
    % fprintf('======================================================\n');

    p_m = success_per_user / runs;
    jain_index = (sum(p_m))^2 / (M * sum(p_m.^2));

    results.p_m = p_m;
    results.jain_index = jain_index;
    
    results.usage_rate=usage_rate;
    results.collision_rate=collision_rate;
    results.slot_channel_success=slot_channel_success;
    results.goodput=success_rate;
    results.throughput=throughput;
    results.energy_efficiency=energy_efficiency;
end