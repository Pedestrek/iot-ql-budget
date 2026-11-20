clc; clear; close all; tic;
%==========================================================================
% CHOOSE SIMULATION:
% 1: Fixed Energy Cost under the Mission Rules
% 2: Network Dynamics along the Mission (fixed cost x budget rule)
% 3: Budget Rule x Fixed Cost (delivered x survival)
% 4: Energy Cost Distribution between Devices (mechanism)
% 5: Experiment - Dispersion of the Initial Battery
% 6: Experiment - Network Load (number of devices)
% 7: Comparison with Slotted ALOHA (fixed probability and budgeted)
SIMUL_choice = 3;
% the choice can also be given from the command line, e.g.
%   SIMUL_CHOICE=3 matlab -batch main
if ~isempty(getenv('SIMUL_CHOICE')), SIMUL_choice = str2double(getenv('SIMUL_CHOICE')); end
%==========================================================================
%% Physical Parameters & Simulation Setup
Re = 6371e3;     % Earth's radius (m)
h = 500e3; 

T = 60; 
dt = 1; 
channels = 2;
% theta = pi/2 * sin(pi * t / T);

mu = 3.986004418e14;
a  = Re + h;
omega = sqrt(mu/a^3);
psi_max = acos(Re/a);        % [rad]
t_max   = psi_max/omega;     % [s]
t = linspace(-t_max, t_max, T/dt); 
psi = omega * t;
theta = atan2( cos(psi) - Re/a , sin(psi) );
d = sqrt((Re+h).^2 - (Re*cos(theta)).^2) - Re.*sin(theta);


Pt = 1;        % Tx power [W]
Gt = 1; Gr = 1;  % Tx/Rx gains
f  = 868e6;      % Frequency (Hz)
lambda = 3e8/f;  % Wavelength (m)
N0_density = 1e-20; % Noise power spectral density [W/Hz]
B = 125e3;       % Channel bandwidth [Hz]
N0 = N0_density * B; % Total noise power in the channel [W]
K = 10;          % Rician factor [dB]
Klin = 10^(K/10);
R = 0.5;         % Achievable rate [bits/s/Hz]
%==========================================================================
%% Mission Parameters
%==========================================================================
% Base scenario. Each experiment changes one factor at a time.
mission = struct('M', 80, 'C', channels, 'R', R, ...
                 'alpha', 0.3, 'gamma', 0.7, 'epsilon', 0.1, ...
                 'H', 1500, ...           % mission length [frames]
                 'e_s', 0.05, ...         % standby consumption per frame [replicas]
                 'bat_mean', 1200, ...    % mean initial battery [replicas]
                 's', 0.5, ...            % battery dispersion: uniform in bat_mean*[1-s, 1+s]
                 'budget', false, 'delta', 0, 'energy_cost', 0.3, ...
                 'cost0', 0.3);           % initial cost of the budget rule
costs  = [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0 1.2];   % fixed energy costs
deltas = [0.005 0.02 0.05];                          % steps of the budget rule
seeds  = 60;            % seeds of each delivered x survival point
seed_conv = struct('first', 20, 'step', 10, 'tol', 0.01, 'cap', 400);   % per-frame curves
k_early = 1300;         % second evaluation frame (before the end of the mission)
phy = struct('t', t, 'd', d, 'lambda', lambda, 'Pt', Pt, 'Gt', Gt, 'Gr', Gr, 'N0', N0, 'Klin', Klin);
S = plotStyle();
%==========================================================================
%% SIMULATION 1: FIXED ENERGY COST UNDER THE MISSION RULES
%==========================================================================
if(SIMUL_choice == 1)
    disp('--- Running Simulation 1: Fixed Energy Cost under the Mission Rules ---');
    % Rows: survival [%], throughput, goodput, replicas per live device, silent frames [%],
    %       network energy spent within the mission [%]
    fixed_metrics = @(r) [r.survival; r.throughput; r.goodput; r.mean_replicas; 100*r.frac_silent; ...
                          100*(1 - sum(r.battery_final)/sum(r.battery0))];
    one_seed = @(seed) cell2mat(arrayfun(@(c) fixed_metrics(runMission(setfield(mission, 'energy_cost', c), phy, seed)), ...
                                         costs, 'UniformOutput', false));
    res = convergeSeeds(one_seed, seeds, seeds, 0, seeds);

    fprintf('%8s %12s %11s %9s %10s %9s %9s\n', 'cost', 'survival', 'throughput', 'goodput', 'replicas', 'silent', 'energy');
    for i = 1:numel(costs)
        fprintf('%8.1f %11.1f%% %11.4f %9.4f %10.3f %8.1f%% %8.1f%%\n', costs(i), res(:,i));
    end

    % Plotting: one quantity per axis (no double y axis); the dotted line
    % marks the fixed cost that delivers the most (c = 0.3)
    %%
    saveData('sim1', costs, res);
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 0.6]);
    tl = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    c_best = 0.3; ct = [0 0.3 0.6 0.9 1.2];
    best = @(ax, yl) plot(ax, [c_best c_best], yl, ':', 'Color', S.c_grey, 'LineWidth', 1);
    ax1 = nexttile(tl); ax = ax1;
    styleAxes(ax, S, 'Sobrevivência e energia', 'custo de energia c', 'porcentagem [%]');
    hb = best(ax, [0 105]);
    hs = plot(ax, costs, res(1,:), '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
    he = plot(ax, costs, res(6,:), '--o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', 'w');
    xticks(ax, ct); xlim(ax, [0 1.25]); ylim(ax, [0 105]); ax.XTickLabelRotation = 0;
    ax = nexttile(tl);
    styleAxes(ax, S, 'Réplicas', 'custo de energia c', 'réplicas por dispositivo ativo');
    best(ax, [0 1.6]);
    plot(ax, [0 1.25], [0.75 0.75], '--', 'Color', S.c_grey, 'LineWidth', 1);
    text(ax, 1.22, 0.77, {'orçamento da', 'bateria média'}, 'FontSize', S.fs_point, 'Color', S.c_grey, ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
    plot(ax, costs, res(4,:), '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
    xticks(ax, ct); xlim(ax, [0 1.25]); ylim(ax, [0 1.6]); ax.XTickLabelRotation = 0;
    ax = nexttile(tl);
    styleAxes(ax, S, 'Silêncio', 'custo de energia c', 'dispositivos ativos em silêncio [%]');
    best(ax, [0 105]);
    plot(ax, costs, res(5,:), '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
    xticks(ax, ct); xlim(ax, [0 1.25]); ylim(ax, [0 105]); ax.XTickLabelRotation = 0;
    lg = legend(ax1, [hs he hb], {'sobrevivência ao fim da missão', 'energia da rede gasta na missão', 'c = 0.3 (máximo de entregas)'}, ...
                'NumColumns', 3, 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    exportFigure(gcf, 'sim1_custo_fixo');
end

%==========================================================================
%% SIMULATION 2: NETWORK DYNAMICS ALONG THE MISSION
%==========================================================================
if(SIMUL_choice == 2)
    disp('--- Running Simulation 2: Network Dynamics along the Mission ---');
    H = mission.H; frames = 2*H;                % follow the network after the mission
    cfgs = {mission, mission, mission};
    cfgs{1}.energy_cost = 0.3;
    cfgs{2}.energy_cost = 0.7;
    cfgs{3}.budget = true; cfgs{3}.delta = 0.02; cfgs{3}.energy_cost = mission.cost0;
    names = {'custo fixo 0.3', 'custo fixo 0.7', 'regra de orçamento, \delta = 0.02'};
    colors = {S.c_fixed, S.c_fixed, S.c_budget};
    styles = {'--', '-.', '-'};

    curves = cell(1, numel(cfgs));
    for i = 1:numel(cfgs)
        fprintf('  %s\n', names{i});
        cfg = cfgs{i};
        MEAN = convergeSeeds(@(seed) missionSeries(cfg, phy, seed, frames), ...
                             seed_conv.first, seed_conv.step, seed_conv.tol, seed_conv.cap);
        curves{i} = seriesCurves(MEAN, 1, mission.M);
        curves{i}.throughput = R * curves{i}.throughput / (channels * length(t));
        % energy spent within the mission (replicas + standby of the live devices up to frame H),
        % as a fraction of the nominal energy of the network, M * bat_mean
        used = sum(MEAN(4,1:H) + cfg.e_s * MEAN(2,1:H));
        fprintf('    energy spent in the mission: %.0f (%.1f%% of %.0f)\n', used, 100*used/(cfg.M*cfg.bat_mean), cfg.M*cfg.bat_mean);
    end

    % Plotting
    %%
    saveData('sim2', curves, names);
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 1]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    field = {'survival', 'throughput'};
    ttl   = {'Dispositivos ativos', 'Vazão por quadro'};
    ylab  = {'dispositivos ativos [%]', 'vazão [bit/s/Hz]'};
    h = gobjects(1, numel(cfgs));
    for p = 1:2
        ax = nexttile(tl);
        styleAxes(ax, S, ttl{p}, 'quadro k', ylab{p});
        for i = 1:numel(cfgs)
            y = curves{i}.(field{p});
            if p == 2                                % per-frame rate: 21-frame moving average
                y = movmean(y, 21, 'omitnan'); y(isnan(curves{i}.(field{p}))) = NaN;
            end
            h(i) = plot(ax, 1:frames, y, styles{i}, 'Color', colors{i}, 'LineWidth', S.lw);
        end
        xlim(ax, [1 frames]);
        if p == 1
            ylim(ax, [0 105]);
        else
            yl = ylim(ax); yl = [0 1.15*yl(2)]; ylim(ax, yl);       % room for the label
            yyaxis(ax, 'right');                                    % same curves read in packets per frame
            ylim(ax, yl * channels * length(t) / R);
            yyaxis(ax, 'left'); tk = yticks(ax); yyaxis(ax, 'right'); yticks(ax, tk * channels * length(t) / R);   % ticks on the grid
            ylabel(ax, 'entregas por quadro [pacotes]', 'FontSize', S.fs);
            ax.YAxis(1).Color = 'k'; ax.YAxis(2).Color = 'k';
            yyaxis(ax, 'left');
        end
        xline(ax, H, 'k:', 'fim da missão', 'FontSize', S.fs_point, 'LabelVerticalAlignment', 'middle', ...
              'LabelOrientation', 'horizontal', 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    lg = legend(h, names, 'Orientation', 'horizontal', 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    exportFigure(gcf, 'sim2_dinamica');
end

%==========================================================================
%% SIMULATION 3: BUDGET RULE x FIXED COST (DELIVERED x SURVIVAL)
%==========================================================================
if(SIMUL_choice == 3)
    disp('--- Running Simulation 3: Budget Rule x Fixed Cost ---');
    H = mission.H;
    deltas_curve = [0.0005 0.001 0.002 0.003 0.005 0.1];   % budget-rule curve (delta = 0 is the fixed initial cost)
    deltas_all = unique([deltas_curve deltas]);
    one_seed = @(seed) missionPoints(mission, phy, seed, costs, deltas_all, [k_early H]);
    P = convergeSeeds(one_seed, seeds, seeds, 0, seeds);
    % rows of P: 1-2 survival/delivered at k_early, 3-4 at H, 5 energy efficiency
    nf = numel(costs);
    i0 = find(abs(costs - mission.cost0) < 1e-9);          % fixed cost = initial cost of the rule
    ic = nf + arrayfun(@(x) find(abs(deltas_all - x) < 1e-12), deltas_curve);
    ip = nf + arrayfun(@(x) find(abs(deltas_all - x) < 1e-12), deltas);

    fprintf('fixed cost %.1f: frame %d -> %.1f%% / %.0f packets ; frame %d -> %.1f%% / %.0f packets\n', ...
            mission.cost0, H, P(3,i0), P(4,i0), k_early, P(1,i0), P(2,i0));
    fprintf('%9s | %9s %10s %8s | %9s %10s %8s\n', 'delta', 'surv H', 'deliv H', 'vs fixed', 'surv k', 'deliv k', 'vs fixed');
    for j = nf+1:size(P,2)
        fprintf('%9g | %8.1f%% %10.0f %+7.1f%% | %8.1f%% %10.0f %+7.1f%%\n', deltas_all(j-nf), P(3,j), P(4,j), ...
                100*(P(4,j)/P(4,i0) - 1), P(1,j), P(2,j), 100*(P(2,j)/P(2,i0) - 1));
    end

    % Plotting: budget-rule curve over delta, evaluated at H and at k_early
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 1.8]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    rows = {[3 4], [1 2]};
    ttl  = {sprintf('Fim da missão (quadro %d)', H), sprintf('Quadro %d', k_early)};
    kk   = [H k_early];
    for p = 1:2
        ax = nexttile(tl);
        styleAxes(ax, S, ttl{p}, sprintf('sobrevivência no quadro %d [%%]', kk(p)), ...
                  sprintf('entregues até o quadro %d [mil pacotes]', kk(p)));
        F = [P(rows{p}(1), 1:nf)' P(rows{p}(2), 1:nf)'/1e3];             % fixed-cost curve
        B = [F(i0,:); P(rows{p}(1), ic)' P(rows{p}(2), ic)'/1e3];        % budget curve, from delta = 0
        yline(ax, F(i0,2), ':', 'Color', S.c_fixed, 'LineWidth', 1.2, 'HandleVisibility', 'off');
        h1 = plot(ax, F(:,1), F(:,2), '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
        h2 = plot(ax, B(:,1), B(:,2), '-s', 'Color', S.c_budget, 'LineWidth', S.lw, 'MarkerSize', S.ms+0.5, 'MarkerFaceColor', S.c_budget);
        xlim(ax, [0 105]); ylim(ax, [0 1.12*max([F(:,2); B(:,2)])]);

        sat = F(:,1) >= 99.5; idx = find(~sat)';
        lab = arrayfun(@(k) sprintf('%.1f', costs(k)), idx, 'UniformOutput', false);
        if any(idx == i0), lab{idx == i0} = sprintf('%.1f (δ=0)', costs(i0)); end
        if any(sat), ks = find(sat); idx = [idx ks(end)]; lab{end+1} = sprintf('%.1f-%.1f', costs(ks(1)), costs(ks(end))); end %#ok<AGROW>
        markers = [F; B];
        lines = {F, B, [0 F(i0,2); 105 F(i0,2)]};
        dlab = arrayfun(@(x) sprintf('%g', x), deltas_curve, 'UniformOutput', false);
        boxes = labelPoints(ax, B(2:end,1), B(2:end,2), dlab, S.c_budget*0.75, S.fs_point, zeros(0,4), markers, lines);
        labelPoints(ax, F(idx,1), F(idx,2), lab, S.c_fixed*0.85, S.fs_point, boxes, markers, lines);
    end
    lg = legend(ax, [h1 h2], {'custo fixo (rótulo = custo)', 'regra de orçamento (rótulo = \delta)'}, ...
                'NumColumns', 2, 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    exportFigure(gcf, 'sim3_orcamento_vs_fixo');

    % Plotting: delivered and energy efficiency for the reference deltas
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 1]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(tl);
    styleAxes(ax, S, 'Entregas', 'sobrevivência ao fim da missão [%]', 'entregas [mil pacotes]');
    h = plotTradeoff(ax, S, P(3,1:nf), P(4,1:nf)/1e3, costs, P(3,ip), P(4,ip)/1e3, deltas, true);
    ax = nexttile(tl);
    styleAxes(ax, S, 'Eficiência energética', 'sobrevivência ao fim da missão [%]', 'eficiência energética [pacotes/réplica]');
    plotTradeoff(ax, S, P(3,1:nf), P(5,1:nf), costs, P(3,ip), P(5,ip), deltas);
    lg = legend(h, [{'custo fixo (rótulo = custo)'}, arrayfun(@(x) sprintf('regra, \\delta = %g', x), deltas, 'UniformOutput', false)], ...
                'NumColumns', 4, 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    saveData('sim3', P, costs, deltas_all, deltas);
    exportFigure(gcf, 'sim3_entregas_ee');
end

%==========================================================================
%% SIMULATION 4: ENERGY COST DISTRIBUTION BETWEEN DEVICES
%==========================================================================
if(SIMUL_choice == 4)
    disp('--- Running Simulation 4: Energy Cost Distribution between Devices ---');
    H = mission.H;
    % budget rule with the three deltas (s = 0.5), and delta = 0.02 with identical batteries (s = 0)
    cfgs = cell(1, numel(deltas) + 1);
    for i = 1:numel(deltas)
        cfgs{i} = mission; cfgs{i}.budget = true; cfgs{i}.delta = deltas(i); cfgs{i}.energy_cost = mission.cost0;
    end
    cfgs{end} = cfgs{2}; cfgs{end}.s = 0;
    i_base = 2; i_equal = numel(cfgs);

    curves = cell(1, numel(cfgs));
    for i = 1:numel(cfgs)
        fprintf('  delta = %g, s = %g\n', cfgs{i}.delta, cfgs{i}.s);
        cfg = cfgs{i};
        MEAN = convergeSeeds(@(seed) missionSeries(cfg, phy, seed, H), ...
                             seed_conv.first, seed_conv.step, seed_conv.tol, seed_conv.cap);
        curves{i} = seriesCurves(MEAN, 1, mission.M);
    end
    x = 1:H;
    saveData('sim4', curves, cfgs);
    fprintf('cost std at frames 500/1000/1400: identical %.3f %.3f %.3f | heterogeneous %.3f %.3f %.3f\n', ...
            curves{i_equal}.std([500 1000 1400]), curves{i_base}.std([500 1000 1400]));

    % Plotting: mean regulated cost
    %%
    figure('Units', 'centimeters', 'Position', [2 2 0.6*S.width S.height_row]);
    ax = gca; styleAxes(ax, S, '', 'quadro k', 'custo de energia médio (ativos)');
    for i = 1:numel(deltas)
        plot(ax, x, curves{i}.cost, S.ls_delta{i}, 'Color', S.c_delta(i,:), 'LineWidth', S.lw, 'Marker', S.mk_delta{i}, 'MarkerIndices', 75:150:H, 'MarkerFaceColor', S.c_delta(i,:), 'MarkerSize', S.ms);
    end
    yline(ax, mission.cost0, '-', 'custo inicial', 'Color', [0.6 0.6 0.6], 'FontSize', S.fs_point, 'LabelHorizontalAlignment', 'center', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    legend(ax, arrayfun(@(x) sprintf('\\delta = %g', x), deltas, 'UniformOutput', false), ...
           'Location', 'southwest', 'FontSize', S.fs_legend);
    xlim(ax, [1 H]);
    exportFigure(gcf, 'sim4_custo_regulado');

    % Plotting: cost spread between devices (batteries in [600, 1800])
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 0.4]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    Cv = curves{i_base};
    ax = nexttile(tl);
    styleAxes(ax, S, 'Distribuição do custo', 'quadro k', 'custo de energia c_m(k)');
    band(ax, x, Cv.p10, Cv.p90, S.c_band, 0.18);
    band(ax, x, Cv.p25, Cv.p75, S.c_band, 0.33);
    plot(ax, x, Cv.p50, 'Color', S.c_band*0.6, 'LineWidth', S.lw);
    yline(ax, mission.cost0, '-', 'custo inicial', 'Color', [0.6 0.6 0.6], 'FontSize', S.fs_point, 'LabelHorizontalAlignment', 'right', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    xlim(ax, [1 H]); ylim(ax, [0 1.1]); yticks(ax, 0:0.2:0.8);
    legend(ax, {'percentis 10 a 90', 'percentis 25 a 75', 'mediana'}, 'Location', 'north', 'Orientation', 'horizontal', 'NumColumns', 2, 'FontSize', S.fs_legend);
    ax = nexttile(tl);
    styleAxes(ax, S, 'Custo por faixa de bateria atual', 'quadro k', 'custo de energia c_m(k)');
    plot(ax, x, Cv.low_bat,  '--', 'Color', 'k',               'LineWidth', S.lw);
    plot(ax, x, Cv.cost,     '-',  'Color', S.c_delta(2,:),     'LineWidth', S.lw);
    plot(ax, x, Cv.high_bat, '-.', 'Color', S.c_grey,           'LineWidth', S.lw);
    yline(ax, mission.cost0, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, 'HandleVisibility', 'off');   % initial cost, labelled in the left panel
    xlim(ax, [1 H]); ylim(ax, [0 1.1]); yticks(ax, 0:0.2:0.8);
    legend(ax, {'25% menor bateria', 'média dos ativos', '25% maior bateria'}, 'Location', 'north', 'Orientation', 'horizontal', 'NumColumns', 2, 'FontSize', S.fs_legend);
    exportFigure(gcf, 'sim4_mecanismo');
end

%==========================================================================
%% SIMULATION 5: EXPERIMENT - DISPERSION OF THE INITIAL BATTERY
%==========================================================================
if(SIMUL_choice == 5)
    disp('--- Running Simulation 5: Dispersion of the Initial Battery ---');
    s_values = [0 0.25 0.5 0.9];      % battery uniform in bat_mean*[1-s, 1+s], same mean
    nf = numel(costs);
    P = cell(1, numel(s_values));
    for k = 1:numel(s_values)
        fprintf('  s = %.2f\n', s_values(k));
        cfg = mission; cfg.s = s_values(k);
        P{k} = convergeSeeds(@(seed) missionPoints(cfg, phy, seed, costs, deltas, cfg.H), seeds, seeds, 0, seeds);
    end

    % Plotting: one panel per dispersion level, a single legend below
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width 2*S.height_row + 1]);
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ymax = 1.08 * max(cellfun(@(x) max(x(2,:)), P)) / 1e3;
    for k = 1:numel(s_values)
        ax = nexttile(tl);
        s_k = s_values(k);
        ttl = sprintf('s = %g: baterias em [%g, %g]', s_k, (1-s_k)*mission.bat_mean, (1+s_k)*mission.bat_mean);
        if s_k == 0, ttl = sprintf('s = 0: baterias idênticas (%g)', mission.bat_mean); end
        if s_k == mission.s, ttl = [ttl ' (base)']; end %#ok<AGROW>
        xl = ''; if k >= 3, xl = 'sobrevivência ao fim da missão [%]'; end
        yl = ''; if mod(k, 2) == 1, yl = 'entregas [mil pacotes]'; end
        styleAxes(ax, S, ttl, xl, yl);
        ylim(ax, [0 ymax]);
        d2 = find(abs(deltas - 0.02) < 1e-12);                     % only the reference step, with its gain
        h = plotTradeoff(ax, S, P{k}(1,1:nf), P{k}(2,1:nf)/1e3, costs, P{k}(1,nf+d2), P{k}(2,nf+d2)/1e3, deltas(d2), true);
    end
    lg = legend(h, {'custo fixo (rótulo = custo)', 'regra de orçamento, \delta = 0,02'}, ...
                'NumColumns', 2, 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    fprintf('%6s %8s | %9s %9s %10s\n', 's', 'delta', 'survival', 'delivered', 'gain [p.p.]');
    for k = 1:numel(s_values)
        for d = 1:numel(deltas)
            fprintf('%6g %8g | %8.1f%% %9.0f %+10.1f\n', s_values(k), deltas(d), P{k}(1,nf+d), P{k}(2,nf+d), ...
                    equivSurvivalLoss(P{k}(1,1:nf), P{k}(2,1:nf), P{k}(1,nf+d), P{k}(2,nf+d)));
        end
    end
    exportFigure(gcf, 'sim5_dispersao');
end

%==========================================================================
%% SIMULATION 6: EXPERIMENT - NETWORK LOAD
%==========================================================================
if(SIMUL_choice == 6)
    disp('--- Running Simulation 6: Network Load ---');
    M_values = [80 150 200];          % same number of channels (C = 2)
    nf = numel(costs);
    P = cell(1, numel(M_values));
    for k = 1:numel(M_values)
        fprintf('  M = %d\n', M_values(k));
        cfg = mission; cfg.M = M_values(k);
        P{k} = convergeSeeds(@(seed) missionPoints(cfg, phy, seed, costs, deltas, cfg.H), seeds, seeds, 0, seeds);
    end

    % Plotting
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 1]);
    tl = tiledlayout(1, numel(M_values), 'TileSpacing', 'compact', 'Padding', 'compact');
    ymax = 1.08 * max(cellfun(@(x) max(x(2,:)), P)) / 1e3;
    for k = 1:numel(M_values)
        ax = nexttile(tl);
        if M_values(k) == mission.M, ttl = sprintf('M = %d (base)', M_values(k)); else, ttl = sprintf('M = %d', M_values(k)); end
        xl = ''; if k == 2, xl = 'sobrevivência ao fim da missão [%]'; end   % x label only on the middle panel
        yl = ''; if k == 1, yl = 'entregas [mil pacotes]'; end
        styleAxes(ax, S, ttl, xl, yl);
        ylim(ax, [0 ymax]);
        d2 = find(abs(deltas - 0.02) < 1e-12);                     % only the reference step, with its gain in the title
        [h, dS] = plotTradeoff(ax, S, P{k}(1,1:nf), P{k}(2,1:nf)/1e3, costs, P{k}(1,nf+d2), P{k}(2,nf+d2)/1e3, deltas(d2), 2);
        title(ax, {ttl, sprintf('\\DeltaS = %.1f p.p.', dS)}, 'FontSize', S.fs_title);
    end
    lg = legend(h, {'custo fixo (rótulo = custo)', 'regra de orçamento, \delta = 0,02'}, ...
                'NumColumns', 2, 'FontSize', S.fs_legend);
    lg.Layout.Tile = 'south';
    for k = 1:numel(M_values)
        for d = 1:numel(deltas)
            fprintf('M = %3d, delta = %g: %.1f%% / %.0f, gain %+.1f p.p.\n', M_values(k), deltas(d), P{k}(1,nf+d), P{k}(2,nf+d), ...
                    equivSurvivalLoss(P{k}(1,1:nf), P{k}(2,1:nf), P{k}(1,nf+d), P{k}(2,nf+d)));
        end
        fprintf('M = %3d, fixed costs (cost: survival / delivered):', M_values(k));
        fprintf(' %.1f: %.1f%% / %.0f;', [costs; P{k}(1,1:nf); P{k}(2,1:nf)]);
        fprintf('\n');
    end
    saveData('sim6', P, M_values, costs, deltas);
    exportFigure(gcf, 'sim6_carga');
end

%==========================================================================
%% SIMULATION 7: COMPARISON WITH SLOTTED ALOHA
%==========================================================================
if(SIMUL_choice == 7)
    disp('--- Running Simulation 7: Comparison with Slotted ALOHA ---');
    H = mission.H;
    p_values = [0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.8 1.0];   % transmission probabilities of the fixed SA
    point = @(r) [r.survival; r.delivered; r.energy_efficiency];
    Q = convergeSeeds(@(seed) missionPoints(mission, phy, seed, costs, deltas, H), seeds, seeds, 0, seeds);
    nf = numel(costs);
    SA = zeros(3, numel(p_values));
    for i = 1:numel(p_values)
        c = mission; c.budget = false; c.p = p_values(i);
        SA(:,i) = convergeSeeds(@(seed) point(runMissionSA(c, phy, seed)), seeds, seeds, 0, seeds);
    end
    c = mission; c.budget = true;
    SAB = convergeSeeds(@(seed) point(runMissionSA(c, phy, seed)), seeds, seeds, 0, seeds);

    fprintf('%24s | %9s %9s %6s\n', '', 'survival', 'delivered', 'EE');
    for i = 1:numel(p_values), fprintf('%24s | %8.1f%% %9.0f %6.3f\n', sprintf('SA p = %g', p_values(i)), SA(:,i)); end
    fprintf('%24s | %8.1f%% %9.0f %6.3f\n', 'SA com orçamento', SAB);
    [~, ib] = max(Q(2,1:nf));
    fprintf('%24s | %8.1f%% %9.0f %6.3f\n', sprintf('QL custo fixo %.1f', costs(ib)), Q(1:3,ib));
    for d = 1:numel(deltas), fprintf('%24s | %8.1f%% %9.0f %6.3f\n', sprintf('QL orçamento %g', deltas(d)), Q(1:3,nf+d)); end

    % Plotting
    %%
    figure('Units', 'centimeters', 'Position', [2 2 S.width S.height_row + 4]);
    ax = gca; styleAxes(ax, S, '', 'sobrevivência ao fim da missão [%]', 'entregas [mil pacotes]');
    % SA first, so the QL curve stays on top; only the reference step of the rule
    hs = plot(ax, SA(1,:), SA(2,:)/1e3, '-^', 'Color', S.c_grey, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_grey);
    hb = plot(ax, SAB(1), SAB(2)/1e3, 'v', 'MarkerSize', S.ms_point, 'MarkerFaceColor', 'w', 'Color', S.c_grey, 'LineWidth', 1.2);
    h1 = plot(ax, Q(1,1:nf), Q(2,1:nf)/1e3, '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, 'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
    d2 = find(abs(deltas - 0.02) < 1e-12); kd = find(abs(S.delta_ref - 0.02) < 1e-12, 1);
    h2 = plot(ax, Q(1,nf+d2), Q(2,nf+d2)/1e3, S.mk_delta{kd}, 'MarkerSize', S.ms_point, 'MarkerFaceColor', S.c_delta(kd,:), 'Color', 'k', 'LineWidth', 0.6);
    xlim(ax, [0 105]); ylim(ax, [0 70]);
    % the two fixed costs discussed in the text
    for cc = [0.3 0.7]
        ic = find(abs(costs - cc) < 1e-9);
        text(ax, Q(1,ic) + 1.2, Q(2,ic)/1e3 + 1.2, sprintf('c = %.1f', cc), 'FontSize', S.fs_point, ...
             'Color', S.c_fixed*0.85, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
    end
    % labels of p: centred below each point of the descending part; the points stacked at
    % 100% survival get a single label, to the left of a bracket
    stacked = SA(1,:) >= 99.5;
    [~, last] = max(SA(1,:) .* ~stacked);                % the one next to the stack: aligned to the right of the point
    for i = find(~stacked)
        if i == last, xa = SA(1,i) - 1; ha = 'right'; else, xa = SA(1,i); ha = 'center'; end
        text(ax, xa, SA(2,i)/1e3 - 1.6, sprintf('p = %g', p_values(i)), 'FontSize', S.fs_point, ...
             'Color', S.c_grey, 'HorizontalAlignment', ha, 'VerticalAlignment', 'top');
    end
    if any(stacked)
        ys = SA(2,stacked)/1e3; xb = 98.6;
        plot(ax, [xb xb], [min(ys) max(ys)], '-', 'Color', S.c_grey, 'LineWidth', 0.8, 'HandleVisibility', 'off');
        plot(ax, [xb xb+0.6; xb xb+0.6]', [min(ys) min(ys); max(ys) max(ys)]', '-', 'Color', S.c_grey, 'LineWidth', 0.8, 'HandleVisibility', 'off');
        text(ax, xb - 1.5, mean([min(ys) max(ys)]), sprintf('p = %g a %g', min(p_values(stacked)), max(p_values(stacked))), ...
             'FontSize', S.fs_point, 'Color', S.c_grey, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    end
    legend(ax, [h1 h2 hs hb], {'QL, custo fixo', 'QL, regra de orçamento, \delta = 0,02', ...
           'SA, probabilidade fixa (rótulo = p)', 'SA com orçamento'}, 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', S.fs_legend);
    saveData('sim7', Q, SA, SAB, p_values, costs, deltas);
    exportFigure(gcf, 'sim7_sa');
end
toc;

function band(ax, x, lo, hi, color, alpha)
    % shaded area between lo and hi, skipping frames without data
    ok = ~isnan(lo) & ~isnan(hi);
    fill(ax, [x(ok) fliplr(x(ok))], [lo(ok) fliplr(hi(ok))], color, 'FaceAlpha', alpha, 'EdgeColor', 'none');
end

function saveData(name, varargin)
% Save the results behind a figure as plots/data/<name>.mat, so the figure can be redrawn without simulating again.
    folder = fullfile(fileparts(mfilename('fullpath')), 'plots', 'data');
    if ~exist(folder, 'dir'), mkdir(folder); end
    vars = struct();
    for i = 1:numel(varargin), vars.(inputname(i+1)) = varargin{i}; end
    save(fullfile(folder, [name '.mat']), '-struct', 'vars');
    fprintf('data: plots/data/%s.mat\n', name);
end
