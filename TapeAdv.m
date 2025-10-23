function [TA_times,TT_AE]=TapeAdv(TT_AE,TT_log,Settings)
% This function finds when tape advances occurr on AE33, using the log
% files (if present) or changes in 'TapeCount' variable. FVRF values are
% also extracted from log files and appended to original timetable. Note
% that a delay between tape advance time and changes in FVRF values is
% expected due to the 10 ATN_1 period required for FVRF calculation.

if Settings.e_logs == 1 % Condition to extract TA times from log files if present
    holder = 1; % Initialize for indexing.
    FVRF = timetable;
    TA_times = datetime;
    for n = 1:height(TT_log)
        if strcmp(TT_log.Message{n}(1:end),'TapeAdvance procedure started.') % Condition if message is for tape advance.
            TA_times(holder) = TT_log.Time(n); % Store time of tape advance
            holder = holder + 1;
        elseif length(TT_log.Message{n}) >= 14 && strcmp(TT_log.Message{n}(1:14),'FVRF value is:') % Find log messages reporting FVRF values.
            FVRF_hold = TT_log(n,:); % Pull out row of log file
            FVRF_hold.Message = str2double(FVRF_hold.Message{1}(16:end)); % Set variable in new timetable to FVRF value
            FVRF = [FVRF;FVRF_hold]; % Append to new timetable
        end
    end
    TA_times = TA_times';

    % Condition to add FVRF to timetable if they exist in log file.
    if isempty(FVRF)
    else
        FVRF = renamevars(FVRF,"Message","FVRF"); % Change variable name to FVRF.
        TT_AE = synchronize(TT_AE,FVRF,'union','previous'); % Add FVRF values to original timetable and maintain value throuhgout tape cycle.
    end

    % This condition finds TA times from datafile if log files are present, but
    % do not actually contain tape advances.
    if isempty(TA_times)
        change_val = zeros(height(TT_AE),1); % Initialize vairable for easier indexing/speed.
        for n = 1: height(TT_AE)-1 % Loop through all times
            change_val(n) = TT_AE.TapeCount(n+1) - TT_AE.TapeCount(n); % Find difference in tape count between time(n) and next time(n+1).
        end
        
        tape_adv_idx = find(change_val ~= 0); % Find where changes in tape count are non-zero
        TA_times = [TT_AE.Time(tape_adv_idx)]; % Pull out times where changes in tape count are non-zero (tape advances).
    end

else % If log files are not present, find tape advances using original variable in AE33 data. 
    fprintf('Log files not present or do not contain tape advance times. Advance times extracted manually. Be aware of potential time differences. FVRF values missing.')
    change_val = zeros(height(TT_AE),1); % Initialize vairable for easier indexing/speed.
    for n = 1: height(TT_AE)-1 % Loop through all times
        change_val(n) = TT_AE.TapeCount(n+1) - TT_AE.TapeCount(n); % Find difference in tape count between time(n) and next time(n+1).
    end
    
    tape_adv_idx = find(change_val ~= 0); % Find where changes in tape count are non-zero
    TA_times = [TT_AE.Time(tape_adv_idx)]; % Pull out times where changes in tape count are non-zero (tape advances).

end

end

