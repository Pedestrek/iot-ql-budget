function phy = phySetup()
%==========================================================================
%   Geometry and link of the base scenario, the same as the setup of
%   main.m (LEO pass at 500 km, 60 slots, 868 MHz, 125 kHz, Rician K = 10 dB).
%==========================================================================
    Re = 6371e3; h = 500e3; mu = 3.986004418e14; a = Re + h;
    omega = sqrt(mu/a^3); t_max = acos(Re/a)/omega;
    t = linspace(-t_max, t_max, 60); psi = omega*t;
    theta = atan2(cos(psi) - Re/a, sin(psi));
    d = sqrt((Re+h).^2 - (Re*cos(theta)).^2) - Re.*sin(theta);
    phy = struct('t', t, 'd', d, 'lambda', 3e8/868e6, 'Pt', 1, 'Gt', 1, 'Gr', 1, ...
                 'N0', 1e-20*125e3, 'Klin', 10^(10/10));
end
