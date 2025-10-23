function [TT_AE] = CalcIntegratedProps(TT_AE,Settings,calc_method)
%{ 
This function applies k_weight to spot 2 to generate BCC2_weight and 
BCC2_weight absorbance, as well as calculating BCC1_weight absorbance.
Integrated absorbance values are also calculated on spot 1 following
calculation of k_int using one of the options described below.

"calc_method": 
    0: Derives k_int from the k_weight equation. Note that when
       derived, k_int = k_weight when ATN1 < ATNf2. (DEFAULT)
    1: Solves for k_int following the modified form in Poland et al. (2025)
        where instantaneous rather than cumulative flows are used, and FVRF
        is always 1. This computation takes far longer than the default
        derived method, and requires the Symbolic Math Toolbox. Averaging
        the TT_AE timetable before running this function may significantly
        improve computation time.
%}

if ~exist("calc_method","var") % If calc method is not specified in function input, set to default derived method
    calc_method = 0;
end

%% Derive or solve for instantaneous compensation factor and apply to spot 1 and 2
K_int = nan(height(TT_AE),7); % Initialize variable for easier/faster indexing.
K_old = nan; % Initialize to nan for generation of error message below.
check = 0; % Check to see if error message already thrown to avoid repeats.

% Condition for calculating the modified k_int from Poland et al. (2025).
if calc_method == 1
    if Settings.e_logs == 1 % Make sure ATN2 values are present before attempting to solve k_int numerically.
        w = waitbar(0,'Calculating k_int');
        s = waitbar(0,'at each wavelength');
        syms k % Initialize symbolic variable "k"
        for i = 1:7 % Loop through all seven wavelengths
            for n = 1:height(TT_AE) % Loop through all times in table.
                F_ratio = TT_AE.Flow2(n)/TT_AE.Flow1(n); % Initialize flow ratio at given time "n".
                FVRF = 1; % Can be modified if desired. FVRF values from log files (calculated using method described in Drinovec et al. (2015)) are present in timetable. If desired, use "TT_AE.FVRF(n)" as input here instead.
                if TT_AE.ATN1(n,i)>0 && TT_AE.ATN2(n,i)>0 && isfinite(TT_AE.ATN1(n,i)) && isfinite(TT_AE.ATN2(n,i)) && ~isnan(F_ratio) && ~isnan(FVRF) % Conditions to solve equation to prevent failure.
                    eqn = log(1-k*TT_AE.ATN2(n,i))/log(1-k*TT_AE.ATN1(n,i)) == F_ratio*FVRF; % Equation to solve
                    S = vpasolve(eqn,k); % Solve
                    S = eval(S); % Refine
                    if isempty(S) % If no solution, set equal to nan.
                        K_int(n,i) = nan;
                    else
                        K_int(n,i) = S; % If solution exists, store in variable array.
                    end  
                else % Set equal to nan when conditions for vpasolve function are not met.
                    K_int(n,i)=nan;
                end
                waitbar(n/height(TT_AE),w) % Update inner loop wait bar
            end % End inner loop for all times at one wavelength
                waitbar(i/width(TT_AE.ATN1),s) % Update outer loop wait bar for wavelength
        end % End outer loop for each wavelength
        K_int = real(K_int); % Take only the real part of the solution
        close(w) % Close inner loop waitbar
        close(s) % Close outer loop waitbar
    else % If ATN2 values are not present, cannot solve for k_int numerically, prompt user.
         fprintf(2,"modified k_int cannot be calculated because ATN2 values are not present.\n Change input for 'calc_method' to 0 for k_int derivation \n")
    end
else % Condition for solving for k_int by derivation from k_weight.
    w = waitbar(0,"Calculating k_int");
    for n = 1:height(TT_AE) % Loop through all times in timetable
        if TT_AE.ATN1(n,1) < Settings.ATN_f2 % Condition for where K_weight does not change
            K_int(n,:) = TT_AE.K_weight(n,:); % Set instantaneous K equal to weighted when ATN < ATN_f2.
            K_old = K_int(n,:); % Hold this value for calculation when ATN > ATN_f2 in statement below.
        else % Derive K_int for when K_weight begins to change (ATN1 > ATN_f2)
            K_int(n,:) = (TT_AE.K_weight(n,:).*(Settings.ATN_TA - Settings.ATN_f2) - K_old.*(Settings.ATN_TA-TT_AE.ATN1(n,:)))./(TT_AE.ATN1(n,:)-Settings.ATN_f2); % Calculate K_inst from weighting equation (Drinovec 2015).
            if sum(isnan(K_int(n,:))) == 7 && check == 0 % Condition to throw alert at times where K_int can't be calculated
                fprintf(2,"Derivation of k_int cannot be executed for tape cycles where ATN1 is never less than ATN_f2. \n This usually occurs in the first and/or last tape cycles of the time range. \n")
                check = check+1; % Update status of thrown error message above.
            end
        end
        waitbar(n/(height(TT_AE)),w) % Update waitbar based on loop iteration
    end % End loop for solving at each time in table.
    close(w)
end % End conditional sepecifying method by whcih to calculate k_int 

TT_AE = addvars(TT_AE,K_int); % Add K_int to input timetable.

% Calculate Integrated BCC concentrations (ng/m^3) and absorbance
% (Mm^-1) on each spot.
if Settings.e_logs == 1 % Make sure logs are present to ensure accuracy of ATN2 and resulting BCC2 values.
    BCC1_int = TT_AE.BC1./(1-TT_AE.K_int.*TT_AE.ATN1); % Compensated BC conc. on spot 1 using k_int.
    babs1_int = BCC1_int.*Settings.MAC*1E-3; % Compensated absorbance value on spot 1 using k_int (Mm^-1).
    BCC2_int = TT_AE.BC2./(1-TT_AE.K_int.*TT_AE.ATN2); % Compensated BC conc. on spot 2 using k_int.
    babs2_int = BCC2_int.*Settings.MAC*1E-3; % Compensated absorbance value on spot 2 using k_int (Mm^-1).
    
    TT_AE = addvars(TT_AE,BCC1_int,babs1_int,BCC2_int,babs2_int); % Add variables to timetable.
    
    % BCC and absorbance using k_weight
    BCC2_weight = TT_AE.BC2./(1-TT_AE.K_weight.*TT_AE.ATN2); % Calculate BCC2 using k_weight (BCC2_weight).
    babs2_weight = (BCC2_weight.*Settings.MAC)*1E-3; % Calculate BCC2_weight absorbance and convert to Mm^-1
    babs1_weight = TT_AE.BCC1.*Settings.MAC*1E-3; % Calculate BCC1_weight absorbance and convert to Mm^-1
    
    TT_AE = addvars(TT_AE,babs1_weight,BCC2_weight,babs2_weight); % Add new variables to timetable
    TT_AE = renamevars(TT_AE,"BCC1","BCC1_weight");

else % When logs aren't present, cannot calculate properties on spot 2, so add these variables as "NaN"
    BCC1_int = TT_AE.BC1./(1-TT_AE.K_int.*TT_AE.ATN1); % Calculate BCC values on spot 1 using k_int.
    babs1_int = BCC1_int.*Settings.MAC*1E-3; 
    babs1_weight = TT_AE.BCC1.*Settings.MAC*1E-3; % Calculate BCC1 absorbance and convert to Mm^-1
    BCC2_int = nan(height(TT_AE),7);
    babs2_int = nan(height(TT_AE),7);
    BCC2_weight = nan(height(TT_AE),7);
    babs2_weight = nan(height(TT_AE),7);
    TT_AE = addvars(TT_AE,BCC1_int,babs1_int,BCC2_int,babs2_int,babs1_weight,BCC2_weight,babs2_weight); % Add new variables to timetable
end

end