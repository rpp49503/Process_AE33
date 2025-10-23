%% MASTER AE33 PROCESSING SCRIPT
%{ 
In order to use this script seamlessly, keep all raw data, log, and AE 
setup files in the same folder as conventionally exported by the AE33, 
but separate from the folder containing this script and its relevant 
functions.

Simply click "Run" and the "Load_AE33" function will prompt the user to select the folder 
containing data files for import into MATLAB, reformatting variables for
easier indexing. If the AE33 has split up your data into seprate folders
for year, make sure to select the year folder containing the data you 
wish to process. You may want to copy all files from separate year 
folders into one before using this script. The output of this script, 
TT_AE, will be a concatenated timetable over the time range of all data 
files with new variables appended. The new variables to be calculated and 
appended are as follows: 

Attenuation on spot 1: ATN1 (unitless)
Background attenuation on spot 1: ATN1_0 (unitless)
Attenuation on spot 2: ATN2 (unitless)
Background attenuation on spot 2: ATN2_0 (unitless)
Weighted compensated BC concentrations on spot 2 (using k_weight): BCC2 (ng/m^3)
Weighted absorbance on spot 2: babs2_weight (Mm^-1)
Integrated compensation parameter: K_int (unitless)
Integrated compensated BC concentration on spot 1: BCC1_int (ng/m^3)
Integrated compensated absorbance on spot 1: babs1_int (Mm^-1)
Integrated compensated BC concentration on spot 2: BCC2_int (ng/m^3)
Integrated compensated absorbance on spot 2: babs2_int (Mm^-1)
Differential compensation parameter: K_diff (unitless)
Differentially compensated BC concentration: BCC_diff (ng/m^3)
Differentially compensated absorbance: babs_diff(Mm^-1)

If log files are not present, ATN2 cannot be calculated, and only the
properties independent of ATN2 will be calculated.

Contact Ryan Poland (rpp49503@uga.edu) or Geoffrey Smith (geosmith@uga.edu)
for any additional questions or help.

%}

%% Initialize instrument settings.
% Define parameters necessary for calculations below. Currently set to 
% default values, but can be changed as necessary. If any "AE_Setup" .XML 
% files containing these values are present, use them to verify correct 
% values or include them in the log folder and they will be read.

Settings.ATN_TA = 120; % Attenuation threshold for tape advance.
Settings.ATN_f2 = 30; % Attenuation at which k_weight begins to update.
Settings.C = 1.57; % Scattering correction for filter material.
Settings.Z = 0.01; % Leakage factor.
Settings.S = 0.785; % Area of sample spot (cm^2).
Settings.MAC = [18.47 14.54 13.14 11.58 10.35 7.77 7.19]; % MAC values (m^2/g) of BC in air, provided in the AE33 manual, for calculating absorbance from equivalent BC concentrations.
Settings.e_logs = 0; % Initialize flag for log files being present
Settings.e_setup = 0; % Initialize flag for setup files being present

%% Load AE33 data and log files and format for easier indexing.
% Select the folder containing all AE33 data, log, and setup files when the
% dialog box appears.

% Imports raw data from .DAT files into single timetable. Formats variables such that columns of each represent all 7 wavelengths in increasing order. 
[TT_AE_raw,TT_log,AE_setup,Settings] = LoadAE33(Settings); 

% Pull out tape advance times and FVRF values, storing as new timetable variables.
[TA_times,TT_AE] = TapeAdv(TT_AE_raw,TT_log,Settings); 

% If you are alerted that the "AE Setup" parameters do not match the
% settings specified above, make necessary changes to variable assignments
% in "Settings" structure before continuing.

%% Calculate ATN1 and ATN2, correcting for ATN_zeros from log files.
% Attenuation values in the output "TT_AE" timetable are automatically
% corrected for background "ATN_0" values, which are also appended to the 
% timetable. You may want to verify that ATN_0 values match those from 
% AE33 log files. IF log files are not present, ATN2 values cannot be
% calculated and only ATN1 values are derived from the k_weight equation
% (Equation 6 in Poland et al. (2025)).

TT_AE = CalcATN(TT_AE,TT_log,Settings);

%% Calculate all properties using Drinovec (2015) compensation parameters ("K_weight" and "K_int")
%{ 
This function applies k_weight to spot 2 to generate BCC2_weight and 
babs2_weight, as well as calculating babs1_weight.
Integrated absorbance values are also calculated on spot 1 following
calculation of k_int using one of the options described below.

"calc_method" (input 3): 
    0: Derives k_int from the k_weight equation (Equation 6 in Poland et al. (2025)). Note that when
       derived, k_int = k_weight when ATN1 < ATNf2. (DEFAULT)
    1: Solves for k_int following the modified form in Poland et al. (2025)
        where instantaneous rather than cumulative flows are used, and FVRF
        is always 1. This computation takes far longer than the default
        derived method, and requires the Symbolic Math Toolbox. Averaging
        the TT_AE timetable before running this function will significantly
        improve computation time.

If log files are not present, ATN2 cannot be calculated, and the only
non-"NaN" output will be k_int derived from k_weight ("calc_method"=0), and
BCC and absorbance values on spot 1.

%}

avg_time = 1; % Averaging interval for optional averaging in line below.
TT_AE = retime(TT_AE,'regular','mean','TimeStep',minutes(avg_time)); % Optional averaging to speed up integrated calculations.

TT_AE = CalcIntegratedProps(TT_AE,Settings,0);

%% Calculate all properties using, and including the differential loading compensation parameter.
% This function calculates the differential loading compensation parameter
% (Equation 6 in Poland et al. (2025)) and generates corresponding BCC_diff
% and babs_diff values. If logs aren't present, and ATN2 cannot
% be calculated, set all differential variables to NaN.

TT_AE = CalcDifferentialProps(TT_AE,Settings);
