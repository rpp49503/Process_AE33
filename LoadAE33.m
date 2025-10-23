function [TT_AE,TT_log,AE_setup,Settings] = LoadAE33(Settings)
% This function performs all initial loading functions of raw, AE33 .DAT
% data and log files. Specify location of each separate folder in dialog
% boxes.

% First, determine whether operating system is Mac or PC.
if ismac
    buffer = "/";
else
    buffer = "\";
end

path = uigetdir(); % Map location of AE33 data and log file folder

%% Loading raw data files
d = dir(path); % List directory of data file folder

TT_AE=timetable(); % Set final timetable as empty for appending in the loop.
TT_log = timetable(); % Set log timetable as empty for appending in the loop.
AE_setup = {}; % Initialize structure for storing AE33 settings from AE_setup file.
w = waitbar(0,'Importing your data'); % Waitbar for loading
holder = 0; % For indexing AE_setup structure if mulitple are present
for n =  1:height(d) % Loop for each file within folder directory.
    if d(n).isdir == 1 % Ignore blank entries or extra folders.
    elseif strcmp(d(n).name(end-3:end),'.XML') == 1 % See if there is an AE33 setup file containing instrument settings, which will be a .XML file.
        holder = holder + 1; % Increase for indexing
        file = string(d(n).folder) + buffer + string(d(n).name); % Combine folder path and file name for full path.
        AE_setup{holder} = readstruct(file); % Store AE setup as a strucutre of variables
        Settings.e_setup = 1;
    elseif strcmp(d(n).name(end-3:end),'.dat') == 1 % Make sure file is .DAT
        if strcmp(d(n).name(1:8),'AE33_log') == 1 % Loop to pull out log file data into timetable
            file = string(d(n).folder) + buffer + string(d(n).name); % Combine folder path and file name for full path.
            opts = detectImportOptions(file,'ConsecutiveDelimitersRule','join'); % Information about file being loaded.
            % opts = detectImportOptions(file,'Delimiter','\t'); % Information about file being loaded.
            opts.Delimiter = '\t';
            opts.DataLines = [1,inf]; % Specify where data is loacted in .DAT file.
            opts.SelectedVariableNames = {'Var1','Var2'}; % Make sure to only get two variables if more exist
            opts.VariableTypes{1} = 'datetime'; % Specify variable types of log data for consistency
            opts.VariableTypes{2} = 'char';
            opts.VariableOptions(1,1).DatetimeFormat = 'yyyy/MM/dd HH:mm:ss'; % Specify datetime format for consistency
            TT_log = [TT_log ; readtimetable(file,opts)]; % Load AE33 log file as timetable and append
            Settings.e_logs = 1;
        elseif  strcmp(d(n).name(1:9),'AE33_AE33') == 1 % Loop to pull out data from correct files
            file = string(d(n).folder) + buffer + string(d(n).name); % combine folder path and file name for full path.
            opts = detectImportOptions(file,'VariableNamesLine',6,'Delimiter',' '); % Get .DAT file info and specify where variable names are.
            opts.DataLines = [13,inf]; % Define what line in .DAT file data begins.
            warning('off','MATLAB:table:ModifiedAndSavedVarnames') % Turn column header command line warning off.
            T_raw = readtable(file,opts); % Load AE33 data into table.
            dates = string(T_raw.Date_yyyy_MM_dd__); % Convert dates and times to strings.
            times = string(T_raw.Time_hh_mm_ss__);
            date_time = dates + times; % Merge dates and times.
            date_time = datetime(date_time,InputFormat="yyyy/MM/ddHH:mm:ss",Format="yyyy/MM/dd HH:mm:ss"); % Convert time string to datetimes for timetable.
            TT_hold = table2timetable(T_raw(:,3:end),'RowTimes',date_time); % Create timetable from raw data and datetimes.
            TT_AE = [TT_AE;TT_hold]; % Append data from this loop to timetable.
        end
    end % End loop for ignoring extra entries or folders in directory
    waitbar(n/height(d),w) % Update wait bar based on loop iteration
end % End loop for all entries in directory.

TT_AE =  sortrows(TT_AE,"Time","ascend"); % Make sure all data is ascending in time

%% Formattting raw, concatenated timetable. Columns for each variable are ordered as: 370, 470, 520, 590, 660, 880, and 950 nm.
TT_AE = mergevars(TT_AE,["RefCh1_","RefCh2_","RefCh3_","RefCh4_","RefCh5_","RefCh6_","RefCh7_"],"NewVariableName",'Ref'); % Reference signal for each channel
TT_AE = mergevars(TT_AE,["Sen1Ch1_","Sen1Ch2_","Sen1Ch3_","Sen1Ch4_","Sen1Ch5_","Sen1Ch6_","Sen1Ch7_"],"NewVariableName","Sensor1"); % Intensities for spot 1 at all wavelengths
TT_AE = mergevars(TT_AE,["Sen2Ch1_","Sen2Ch2_","Sen2Ch3_","Sen2Ch4_","Sen2Ch5_","Sen2Ch6_","Sen2Ch7_"],"NewVariableName","Sensor2"); % Intensities for spot2 at all wavelengths.
TT_AE = mergevars(TT_AE,["BC11_","BC21_","BC31_","BC41_","BC51_","BC61_","BC71_"],"NewVariableName","BC1"); % BC1 (spot one) uncompensated concentrations
TT_AE = mergevars(TT_AE,["BC12_","BC22_","BC32_","BC42_","BC52_","BC62_","BC72_"],"NewVariableName","BC2"); % BC2 (spot two) uncompensated concentrations
TT_AE = mergevars(TT_AE,["BC1_","BC2_","BC3_","BC4_","BC5_","BC6_","BC7_"],"NewVariableName","BCC1"); % Compensated BC1 concentrations
TT_AE = mergevars(TT_AE,["K1_","K2_","K3_","K4_","K5_","K6_","K7_"],"NewVariableName","K_weight"); % Weighted compensation parameter
TT_AE = renamevars(TT_AE,["Timebase_","Flow1_","Flow2_","TapeAdvCount_"],["Timebase","Flow1","Flow2","TapeCount"]); % Remove underscores to avoid confusion

if Settings.e_logs == 1 && height(TT_log) >= 7 % Make sure log file exists and actually contains ATN zeros
    TT_log.Properties.DimensionNames{1}='Time'; % Rename "Var1" to "Time".
    TT_log = renamevars(TT_log,"Var2","Message"); % Rename variable
else
    fprintf(2,"Log files not present. ATN on spot 2 cannot be calculated. All other properties that do not depend on ATN 2 will be calculated. \n")
    TT_log=timetable();
    Settings.e_logs = 0;
end

% For rows with missing times, fill with previous time in log file.
for n = 1:height(TT_log)
    if ismissing(TT_log.Time(n))
        TT_log.Time(n) = TT_log.Time(n-1);
    end
end

%% Compare defined settings and settings from AE setup file

if Settings.e_setup == 1 % Make sure setup file exists
    for n = 1:length(AE_setup)
        if AE_setup{n}.C ~= Settings.C  
            Settings.C = AE_setup{n}.C;
            fprintf(2,"Scattering correction (C) value from AE33 setup value does not match input above. Verify correct input value before proceeding")
        elseif AE_setup{n}.Zeta ~= Settings.Z
            Settings.Z = AE_setup{n}.Zeta;
            fprintf(2,"Leakage correction (Z) value from AE33 setup value does not match input above. Verify correct input value before proceeding")
        elseif AE_setup{n}.AtnMAX ~= Settings.ATN_TA
            Settings.ATN_TA = AE_setup{n}.AtnMAX;
            fprintf(2,"Attenuation threshold (ATN_TA) value from AE33 setup value does not match input above. Verify correct input value before proceeding")
        elseif AE_setup{n}.ATNf2 ~= Settings.ATN_f2
            Settings.ATN_f2 = AE_setup{n}.ATNf2;
            fprintf(2,"ATN_f2 value from AE33 setup value does not match input above. Verify correct input value before proceeding")
        elseif AE_setup{n}.Area ~= Settings.S
            Settings.S = AE_setup{n}.Area;
            fprintf(2,"Spot area (S) value from AE33 setup value does not match input above. Verify correct input value before proceeding")
        elseif AE_setup{n}.TAtype ~= 1
            fprintf(2,"Tape advance not set to threshold value. Parameters for ATN_TA changed.")
        end
    end
end

close(w) % Close waitbar

end