function [TT_AE] = CalcDifferentialProps(TT_AE,Settings)
% This function calculates the differential loading compensation parameter
% (Equation 7 in Poland et al. (2025)) and generates corresponding BCC_diff
% and BCC_diff absorbance values. If logs aren't present, and ATN2 cannot
% be calculated, set all differential variables to NaN.

% Calculate k_diff if ATN_2 values are present (require log files in
% "CalcATN" funciton).
if Settings.e_logs == 1
    K_diff = (TT_AE.BC2-TT_AE.BC1)./((TT_AE.BC2.*TT_AE.ATN1)-(TT_AE.BC1.*TT_AE.ATN2)); % Calculate differential compensation parameter at each time step
    BCC_diff = TT_AE.BC1./(1-K_diff.*TT_AE.ATN1); % Compensate BC using k_diff method
    babs_diff = BCC_diff.*Settings.MAC*1E-3; % Calculate absorbance from BCC_diff
    
    TT_AE = addvars(TT_AE,K_diff,BCC_diff,babs_diff); % Add differential compensation parameter and properties to timetable

else % If logs aren't present, append differential variables as "NaN"
    K_diff = nan(height(TT_AE),7);
    BCC_diff = nan(height(TT_AE),7);
    babs_diff = nan(height(TT_AE),7);
    
    TT_AE = addvars(TT_AE,K_diff,BCC_diff,babs_diff); % Add differential compensation parameter and properties to timetable

end