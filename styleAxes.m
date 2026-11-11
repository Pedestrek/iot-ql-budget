function styleAxes(ax, S, ttl, xlab, ylab)
%==========================================================================
%   Apply the common style (plotStyle) to one axes.
%==========================================================================
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontName', S.font, 'FontSize', S.fs, 'LineWidth', 0.6);
    if ~isempty(ttl),  title(ax, ttl, 'FontSize', S.fs_title, 'FontWeight', 'bold'); end
    if ~isempty(xlab), xlabel(ax, xlab, 'FontSize', S.fs); end
    if ~isempty(ylab), ylabel(ax, ylab, 'FontSize', S.fs); end
end
