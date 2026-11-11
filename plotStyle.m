function [S] = plotStyle()
%==========================================================================
%   Common style of the mission figures (simulations 1-7), so the same
%   quantity always has the same color, marker, line and font everywhere.
%
%   The color identifies the strategy:
%     fixed energy cost  -> blue, circles
%     budget rule        -> green (delta: marker and shade, light to dark)
%     Slotted ALOHA      -> grey
%   Anything else (two fixed costs, battery scenario, quartile) is told
%   apart by the line style, so the figures also read in greyscale.
%==========================================================================
    S.width = 16;                 % figure width [cm] (text width of an A4 page)
    S.height_row = 6.2;           % height of one row of panels [cm]
    S.font = 'Helvetica';
    S.fs = 9;                     % axes and tick labels
    S.fs_title = 10;
    S.fs_legend = 8;
    S.fs_point = 7.5;             % labels written next to the points
    S.lw = 1.5;                   % line width
    S.ms = 4.5;                   % marker size of the curves
    S.ms_point = 8;               % marker size of isolated points (delta)

    S.c_fixed  = [0.000 0.447 0.741];
    S.c_budget = [0.200 0.600 0.200];
    S.c_delta  = [0.550 0.800 0.450;      % delta = 0.005 (light green)
                  0.200 0.600 0.200;      % delta = 0.02
                  0.050 0.330 0.100];     % delta = 0.05  (dark green)
    S.mk_delta = {'s', 'p', 'd'};
    S.ls_delta = {':', '-', '--'};        % line style of each delta in curves along the mission
    S.delta_ref = [0.005 0.02 0.05];
    S.c_band = [0.200 0.600 0.200];       % percentile bands of the cost
    S.c_grey = [0.30 0.30 0.30];
end
