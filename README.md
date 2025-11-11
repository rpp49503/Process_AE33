# Process AE33 raw data for derivation and application of the differential loading compensation parameter
Use the "MASTER_PROCESSOR" script to read and process data from the original, raw AE33 files. In order to use the script seamlessly, keep all raw data (.DAT), log (.DAT), and AE setup (.XML) files in the same folder as conventionally exported by the AE33 but separate from the folder containing the functions and script provided here.

Simply click "Run" and the "Load_AE33" function will prompt the user to select the folder containing the files for import into MATLAB, reformatting variables foreasier indexing. If the AE33 has split up your data into seprate folders for different years, make sure to select the year folder containing the data you wish to process. You may want to copy all files from separate year folders into one before using this script. The output of this script, "TT_AE", will be a concatenated timetable over the time range of all data files with new variables appended. 

## The new variables to be calculated and appended are as follows: 
- Attenuation on spot 1: ATN1 (unitless)
- Background attenuation on spot 1: ATN1_0 (unitless)*
- Attenuation on spot 2: ATN2 (unitless)*
- Background attenuation on spot 2: ATN2_0 (unitless)*
- Weighted compensated BC concentrations on spot 2 (using k_weight): BCC2 (ng/m^3)*
- Weighted absorbance on spot 2: babs2_weight (Mm^-1)*
- Integrated compensation parameter: K_int (unitless)
- Integrated compensated BC concentration on spot 1: BCC1_int (ng/m^3)
- Integrated compensated absorbance on spot 1: babs1_int (Mm^-1)
- Integrated compensated BC concentration on spot 2: BCC2_int (ng/m^3)*
- Integrated compensated absorbance on spot 2: babs2_int (Mm^-1)* 
- Differential compensation parameter: K_diff (unitless)* 
- Differentially compensated BC concentration: BCC_diff (ng/m^3)* 
- Differentially compensated absorbance: babs_diff(Mm^-1)* 

If log files are not present, ATN2 cannot be calculated, and the variables denoted with "*" cannot be calculated. The integrated loading compensation parameter will be equivalent to the form derived using cumulative flows and default FVRF for speed. The "CalcIntegratedProps" function input can be changed to calculated the modified, improved form described in Poland et al. (2025), though the computation time will significantly increase. For more specific information regarding individual functions, see the comments within the code markdown for each.

Contact Ryan Poland (rpp49503@uga.edu) or Geoffrey Smith (geosmith@uga.edu)
for any additional questions or help.
