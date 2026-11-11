function [boxes] = labelPoints(ax, x, y, labels, color, fs, boxes, markers, lines)
%==========================================================================
%   Write each label as close as possible to its point without overlaps.
%
%   Preferred positions, in order: right, left, above, below (touching the
%   point); then slightly shifted; and only then farther away with a leader
%   line. A position is free when it covers no other label nor marker and
%   (almost) no line.
%     boxes   - labels already placed (normalized [x1 y1 x2 y2]), updated
%     markers - [x y] of every marker in the axes (data units)
%     lines   - cell of [x y] polylines to avoid (data units)
%   Call after xlim/ylim are final.
%==========================================================================
    if nargin < 9, lines = {}; end
    xl = xlim(ax); yl = ylim(ax);
    nx = @(v) (v - xl(1))/diff(xl);
    ny = @(v) (v - yl(1))/diff(yl);
    units = get(ax, 'Units'); set(ax, 'Units', 'centimeters'); pos = get(ax, 'Position'); set(ax, 'Units', units);
    cw = 0.58*fs*0.0353/pos(3);          % character width  (normalized)
    ch = 1.15*fs*0.0353/pos(4);          % character height (normalized)
    g  = 0.010;                          % gap between point and label
    mk = [nx(markers(:,1)) ny(markers(:,2))];

    % sample the lines
    LS = zeros(0,2);
    for L = 1:numel(lines)
        P = [nx(lines{L}(:,1)) ny(lines{L}(:,2))];
        for s = 1:size(P,1)-1
            n = max(2, ceil(norm(P(s+1,:)-P(s,:))/0.004)); t = linspace(0,1,n)';
            LS = [LS; P(s,:) + t.*(P(s+1,:)-P(s,:))]; %#ok<AGROW>
        end
    end

    % candidates: [dx dy side], side 1 right, 2 left, 3 above, 4 below
    C = [ g 0 1; -g 0 2; 0 g 3; 0 -g 4; ...
          g 0.6*ch 1; g -0.6*ch 1; -g 0.6*ch 2; -g -0.6*ch 2];
    for r = [2 3 4 6]
        C = [C; r*g 0 1; -r*g 0 2; 0 r*g 3; 0 -r*g 4; r*g ch 1; r*g -ch 1; -r*g ch 2; -r*g -ch 2]; %#ok<AGROW>
    end

    for i = 1:numel(x)
        w = numel(labels{i})*cw; h = ch; px = nx(x(i)); py = ny(y(i));
        best = Inf; chosen = 1; bb = [];
        for c = 1:size(C,1)
            dx = C(c,1); dy = C(c,2);
            switch C(c,3)
                case 1, b = [px+dx, py+dy-h/2, px+dx+w, py+dy+h/2];
                case 2, b = [px+dx-w, py+dy-h/2, px+dx, py+dy+h/2];
                case 3, b = [px-w/2, py+dy, px+w/2, py+dy+h];
                case 4, b = [px-w/2, py+dy-h, px+w/2, py+dy];
            end
            hard = 0;
            for k = 1:size(boxes,1), hard = hard + overlap(b, boxes(k,:)); end
            for k = 1:size(mk,1), hard = hard + overlap(b, [mk(k,1)-0.008 mk(k,2)-0.011 mk(k,1)+0.008 mk(k,2)+0.011]); end
            outside = max(0,-b(1)) + max(0,b(3)-1) + max(0,-b(2)) + max(0,b(4)-1);
            n_line = sum(LS(:,1) > b(1) & LS(:,1) < b(3) & LS(:,2) > b(2) & LS(:,2) < b(4));
            penalty = 1e3*hard + 1e3*outside + n_line;
            if penalty == 0, bb = b; chosen = c; break; end      % first free position
            if penalty < best, best = penalty; bb = b; chosen = c; end
        end
        dx = C(chosen,1); dy = C(chosen,2); side = C(chosen,3);
        if abs(dx) > 2.5*g || abs(dy) > 2.5*g                     % far away: leader line
            ex = bb(1) + (side == 2)*(bb(3)-bb(1)); ey = (bb(2)+bb(4))/2;
            if side >= 3, ex = (bb(1)+bb(3))/2; ey = bb(2) + (side == 4)*(bb(4)-bb(2)); end
            plot(ax, [x(i), xl(1)+diff(xl)*ex], [y(i), yl(1)+diff(yl)*ey], '-', 'Color', [color 0.6], ...
                 'LineWidth', 0.5, 'HandleVisibility', 'off');
        end
        text(ax, xl(1)+diff(xl)*(bb(1)+bb(3))/2, yl(1)+diff(yl)*(bb(2)+bb(4))/2, labels{i}, ...
             'FontSize', fs, 'Color', color, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'Interpreter', 'none');
        boxes(end+1,:) = bb; %#ok<AGROW>
    end
end

function a = overlap(p, q)
    a = max(0, min(p(3),q(3)) - max(p(1),q(1))) * max(0, min(p(4),q(4)) - max(p(2),q(2)));
end
