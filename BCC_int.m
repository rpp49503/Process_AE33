function [AE33_TT,K_inst,BCC1_inst,BCC1_inst_abs,BCC2_inst,BCC2_inst_abs] = BCC_inst(AE33_TT,TA_times,Settings)
% BCC_inst This function generates the instantaneous compensation
% parameter from the weighted K included in the original AE33 data file.

TAcycleStore{height(TA_times)+1,1} = nan;
for n = 0:height(TA_times)

    % Create new table for each individual tape cycle
    if n == 0
        TAcycle = AE33_TT(timerange(AE33_TT.Time(1),TA_times(1)),:);
    elseif n == height(TA_times)
        TAcycle = AE33_TT(timerange(TA_times(n),AE33_TT.Time(end)),:);
    else
        TAcycle = AE33_TT(timerange(TA_times(n),TA_times(n+1)),:);
    end

    % Pull out previous value of K, needed to solve for K_inst
    K_old_range = TAcycle(TAcycle.ATN1(:,1) < Settings.ATN_f2,:); % K values will be equivalent to previous spot k when ATN < ATN_f2 (30)
    
    % Loop to account for ranges where there is no ATN < ATN_f2
    if height(K_old_range)<1
        error("No data below ATN_f2 for cycle" + string(TAcycle.Time(1)) + "-" + string(TAcycle.Time(end)))
        K_inst = TAcycle.K.*1;
        K_inst(:,:) = nan;
        TAcycle = addvars(TAcycle,K_inst);
    else
        K_old = K_old_range.K(1,:); % Set equal to first row in new table
        i = 2; % Initialize starting point for while loop
        while isnan(sum(K_old)) % While loop to make sure there are no NaN K_old value.
            K_old = K_old_range.K(i,:); % Look to next row for k_old
            i = i+1; % Increase row number
        end
    
        % Rearrange weighting method to solve for instantaneous k.
        K_inst = (TAcycle.K.*(Settings.ATN_TA - Settings.ATN_f2) - K_old.*(Settings.ATN_TA-TAcycle.ATN1))./(TAcycle.ATN1-Settings.ATN_f2);
        TAcycle = addvars(TAcycle,K_inst);
        
        % Loop to set any K_inst below ATN_f2 = K_old
        for j = 1:height(K_old_range)
            TAcycle.K_inst(j,:) = K_old;
        end
    end

    % Calculate BCC_inst and BCC_inst absorbance on both spots
    BCC1_inst = TAcycle.BC1./(1-TAcycle.K_inst.*TAcycle.ATN1); % Calculate new BCC concentration
    BCC1_inst_abs = BCC1_inst.*Settings.MAC_air*1E-3; % Calculate absorbance from new BCC (Mm^-1)

    BCC2_inst = TAcycle.BC2./(1-TAcycle.K_inst.*TAcycle.ATN_2);
    BCC2_inst_abs = BCC_inst_2.*Settings.MAC_air*1E-3;


    TAcycle = addvars(TAcycle,BCC1_inst,BCC2_inst,BCC1_inst_abs,BCC2_inst_abs);
    TAcycleStore{n} = TAcycle;
end

AE33_TT = vertcat(TAcycleStore{:}); % Recompile timetables for each cycle into one timetable

end