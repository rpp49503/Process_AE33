function TT_AE = CalcATN(TT_AE,TT_log,Settings)
% This function calculates attenuation values on spot 1 and 2, and corrects
% them for their corresponding background values (ATN_0) from the AE33 log
% files. If log files are not present, or do not contain ATN_zeros, ATN2
% cannot be calculated and only ATN1 values are derived from the k_weight
% equation (Equation 6 in Poland et al. (2025)).

% Pulling out ATN_0 from log data for backgrounding
if Settings.e_logs == 1 % Loop to make sure logs exist. If not, only calculate ATN1 from BCC and BC1.
    ATN_0 = timetable(); % Initialize timetable for appending in loop.
    for n = 1:height(TT_log) % Loop through all entries in log file.
        holder = string(TT_log.Message(n)); % Pull out message from log file at given time "n".
        if length(holder{1}) < 11 % Checking the first entry in the log file (could be corrupted).
        else
            if length(holder{:}) >= 11 && strcmp(holder{1}(1:11),'ATN1zero(1)') == 1 % Condition for message containing ATN_0 value, with others in subsequent messages.
                holder = strjoin(TT_log.Message(n:n+6)); % Re-formatting log messages containing ATN_0 for storing in timetable.
                new = strsplit(holder);
                ATN1_0 = str2double(new(2:4:26));
                ATN2_0 = str2double(new(4:4:end));
                tt = timetable(ATN1_0,ATN2_0,'RowTimes',TT_log.Time(n));
                ATN_0 = [ATN_0;tt]; % Append to previous stored values
            end % End loop for second check that message is an ATN_0 value.
        end % End loop for potential corrupted log file.
    end % End loop for all entries in log file.

    if isempty(ATN_0) % Check to make sure log files actually contained ATN_0 values.
        Settings.e_logs = 0; % If not, change flag to zero for loop below.
    end
end % End loop for extracting ATN_0 from log files

if Settings.e_logs == 1 % Make sure that ATN_0 values are actually present.
    ATN_0 = sortrows(ATN_0,"Time","ascend"); % Make sure rows are ordered to increase in time.
    
    TT_AE = synchronize(TT_AE,ATN_0,'union','previous'); % Synchronize ATN zero and data timetables to union of timeranges, and maintaining previous ATN_0 values between tape advances.
    if sum(isnan(sum(TT_AE.ATN1_0,1))) == 7 || sum(isnan(sum(TT_AE.ATN2_0,1))) == 7 % Alert if there are mismatched ATN and ATN_0 times/values.
        fprintf(2,"Not all ATN values have been corrected for background due to missing ATN_0 from logs. \n Consider removing rows with '0' to avoid negative/inaccurate ATN values, or manually correct for these time periods. \n")
        TT_AE.ATN1_0(isnan(TT_AE.ATN1_0)) = 0; % Replace Nan with 0 for subtraction of missing background values
        TT_AE.ATN2_0(isnan(TT_AE.ATN2_0)) = 0;
    end
    
    % Calculate ATN1 and ATN2 from respective channel singals and references and subtract background ATN.
    ATN1 = -100*log(TT_AE.Sensor1./TT_AE.Ref); % Calculate attenuation on spot 1
    ATN2 = -100*log(TT_AE.Sensor2./TT_AE.Ref); % Calculate attenuation on spot 2
    TT_AE = addvars(TT_AE,ATN1,ATN2); % Add attenuations to timetable
    
    TT_AE.ATN1 = TT_AE.ATN1 - TT_AE.ATN1_0; % Subtract background ATN_0 from total ATN_1 values.
    TT_AE.ATN2 = TT_AE.ATN2 - TT_AE.ATN2_0; % Subtract background ATN_0 from total ATN_2 values.

else % ATN2 cannot be calculated. Derive ATN1 and set other variables to NaN.
    ATN1 = (1-(TT_AE.BC1./TT_AE.BCC1))./TT_AE.K_weight; % Calculate attenuation on spot 1 from BCC and BC1. Already corrected for ATN_0 on spot 1.
    % Set remaining ATN values that cannot be found or calculated to NaN.
    ATN2 = nan(height(TT_AE),7);
    ATN1_0 = nan(height(TT_AE),7);
    ATN2_0 = nan(height(TT_AE),7);
    TT_AE = addvars(TT_AE,ATN1,ATN2,ATN1_0,ATN2_0); % Add attenuation on spot 1 and variables of zeros for properties unable to extract or calculate.
end

end
