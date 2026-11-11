function [h, dS] = plotTradeoff(ax, S, sv_fixed, dd_fixed, costs, sv_budget, dd_budget, deltas, show_gain)
%==========================================================================
%   Delivered packets x survival: the fixed-cost curve (label = cost) and
%   the budget rule as isolated points (marker = delta, as in plotStyle).
%   Costs whose points saturate at ~100% survival are labelled together.
%   Returns the handles [fixed curve, delta points] for the legend.
%   show_gain (optional): draws, for delta = 0.02, a dotted segment from the
%   point of the rule to the fixed-cost curve, with the equivalent survival
%   gain (equivSurvivalLoss) written below it; show_gain = 2 draws only the
%   segment and returns the gain dS, to be written elsewhere (e.g. the title).
%==========================================================================
    h = gobjects(1, 1 + numel(deltas));
    h(1) = plot(ax, sv_fixed, dd_fixed, '-o', 'Color', S.c_fixed, 'LineWidth', S.lw, ...
                'MarkerSize', S.ms, 'MarkerFaceColor', S.c_fixed);
    for d = 1:numel(deltas)
        k = find(abs(S.delta_ref - deltas(d)) < 1e-12, 1);
        if isempty(k), k = min(d, numel(S.mk_delta)); end
        h(1+d) = plot(ax, sv_budget(d), dd_budget(d), S.mk_delta{k}, 'MarkerSize', S.ms_point, ...
                      'MarkerFaceColor', S.c_delta(k,:), 'Color', 'k', 'LineWidth', 0.6);
    end
    d2 = find(abs(deltas - 0.02) < 1e-12, 1);           % reference step drawn on top of the others
    if ~isempty(d2), uistack(h(1+d2), 'top'); end
    xlim(ax, [0 105]);
    yl = ylim(ax); ylim(ax, [0 yl(2)]);

    % labels of the fixed costs (saturated ones grouped as "a-b")
    sat = sv_fixed >= 99.5;
    idx = find(~sat);
    labels = arrayfun(@(k) sprintf('%.1f', costs(k)), idx, 'UniformOutput', false);
    if any(sat)
        ks = find(sat);
        idx = [idx(:)' ks(end)];
        labels{end+1} = sprintf('%.1f a %.1f', costs(ks(1)), costs(ks(end)));
    end
    markers = [sv_fixed(:) dd_fixed(:); sv_budget(:) dd_budget(:)];
    lines = {[sv_fixed(:) dd_fixed(:)]};
    boxes = zeros(0,4);
    dS = NaN;
    if nargin >= 9 && show_gain
        d = find(abs(deltas - 0.02) < 1e-12, 1);
        if ~isempty(d)
            dS = equivSurvivalLoss(sv_fixed, dd_fixed, sv_budget(d), dd_budget(d));
            if isfinite(dS)
                xs = [sv_budget(d) - dS, sv_budget(d)]; ys = dd_budget(d)*[1 1];
                plot(ax, xs, ys, ':', 'Color', S.c_delta(2,:)*0.8, 'LineWidth', 1.2, 'HandleVisibility', 'off');
                lines{end+1} = [xs(:) ys(:)];
                if show_gain ~= 2
                    yl = ylim(ax);
                    tx = text(ax, mean(xs), ys(1) - 0.03*diff(yl), sprintf('\\DeltaS = %.1f p.p.', dS), ...
                              'FontSize', S.fs_point, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                              'Color', S.c_delta(2,:)*0.7);
                    e = tx.Extent; boxes = [e(1) e(2) e(1)+e(3) e(2)+e(4)];
                end
            end
        end
    end
    labelPoints(ax, sv_fixed(idx), dd_fixed(idx), labels, S.c_fixed*0.85, S.fs_point, ...
                boxes, markers, lines);
end
