function [dS] = equivSurvivalLoss(Sfix, Efix, Sreg, Ereg)
%==========================================================================
%   Equivalent survival gain of a strategy over the fixed-cost curve [p.p.]
%
%   dS = Sreg - Sfix(Ereg), where Sfix(E) is the survival that a fixed cost
%   would have when delivering E packets, obtained by linear interpolation
%   on the descending branch of the fixed-cost curve (costs above the one
%   with the most deliveries). dS > 0: to deliver as much as the strategy,
%   the fixed cost would have to give up dS points of survival.
%   dS is NaN when Ereg is outside the deliveries of that branch.
%     Sfix, Efix: fixed-cost curve, one point per cost, ascending cost
%==========================================================================
    [~, i] = max(Efix);
    S = Sfix(i:end); E = Efix(i:end);
    [E, o] = unique(E); S = S(o);              % interp1 needs distinct, increasing abscissae
    dS = Sreg - interp1(E, S, Ereg, 'linear', NaN);
end
