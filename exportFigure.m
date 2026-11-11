function exportFigure(fig, name)
%==========================================================================
%   Save a figure as plots/<name>.png (300 dpi) and plots/<name>.pdf (vector).
%   Before saving, every decimal point between digits (ticks, titles, axis
%   labels, legends, point labels) is replaced by a decimal comma, as used
%   in the text of the monograph (Portuguese).
%==========================================================================
    decimalComma(fig);
    folder = fullfile(fileparts(mfilename('fullpath')), 'plots');
    if ~exist(folder, 'dir'), mkdir(folder); end
    exportgraphics(fig, fullfile(folder, [name '.png']), 'Resolution', 300);
    exportgraphics(fig, fullfile(folder, [name '.pdf']), 'ContentType', 'vector');
    fprintf('figure: plots/%s.png / .pdf\n', name);
end

function decimalComma(fig)
    comma = @(s) regexprep(s, '(\d)\.(\d)', '$1,$2');
    drawnow;
    for ax = findall(fig, 'Type', 'axes')'
        rulers = [ax.XAxis(:); ax.YAxis(:)];
        for r = rulers'
            if r.Exponent ~= 0, continue; end            % keep the x10^n multiplier of the axis
            lim = r.Limits;
            vals = r.TickValues;
            vals = vals(vals >= lim(1) & vals <= lim(2));   % only ticks inside the axis
            r.TickValues = vals;                             % freezes the current ticks
            labels = r.TickLabels;
            if numel(labels) == numel(vals), r.TickLabels = comma(labels); end
        end
    end
    for h = findall(fig, 'Type', 'text')', h.String = comma(h.String); end
    for h = findall(fig, 'Type', 'legend')', h.String = comma(h.String); end
    for h = findall(fig, 'Type', 'constantline')', h.Label = comma(h.Label); end
end
