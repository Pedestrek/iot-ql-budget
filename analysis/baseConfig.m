function cfg = baseConfig()
%==========================================================================
%   Base mission scenario, the same as the struct `mission` of main.m.
%==========================================================================
    cfg = struct('M', 80, 'C', 2, 'R', 0.5, 'alpha', 0.3, 'gamma', 0.7, 'epsilon', 0.1, ...
                 'H', 1500, 'e_s', 0.05, 'bat_mean', 1200, 's', 0.5, ...
                 'budget', false, 'delta', 0, 'energy_cost', 0.3, 'cost0', 0.3);
end
