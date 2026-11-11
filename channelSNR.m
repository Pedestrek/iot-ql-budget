function SNRdB = channelSNR(phy, M)
%==========================================================================
%   SNR [dB] of each device in each slot of the pass (M x num_slots).
%   Same free-space path loss + Rician fading as the inline code of main.m;
%   phy carries the geometry and link parameters defined in its setup.
%==========================================================================
    L = (4*pi*phy.d./phy.lambda).^2;
    h_rician = sqrt(phy.Klin/(phy.Klin+1)) + sqrt(1/(2*(phy.Klin+1))) * (randn(length(phy.d), M) + 1i*randn(length(phy.d), M));
    power_fading = abs(h_rician)'.^2;
    SNR = (phy.Pt*phy.Gt*phy.Gr./(L.*phy.N0)) .* power_fading;
    SNRdB = 10*log10(SNR);
end
