
%{
Create Patient File before recording EEG. 
Input patient ID #, Trial #, and any addition information --> Record
electrodes used / corresponding channels. Save EEG data as text file via
Neuroelectrics interface to this file. 
%}

% Input Patient Information
patientID = input('Enter Patient ID: ', "s");
date = input('Enter Date (YYYY-MM-DD): ', "s");
patientInfo = input('Enter Additional Patient Information: ', "s");

% Name Folder
folderName = sprintf('PatientID_%s', patientID);

% Create Folder 
if ~exist(folderName, 'dir')
    mkdir(folderName);
end

% Store Input Information as a Text File
infoFilename = sprintf('PatientID_%s_Info.txt', patientID);
info = fullfile(folderName, infoFilename);

fid = fopen(info, 'w');

fprintf(fid, 'Patient Information\n');
fprintf(fid, '=============================\n\n');
fprintf(fid, 'Patient ID: %s\n', patientID);
fprintf(fid, 'Date: %s\n', date);
fprintf(fid, 'Additional Information:\n%s\n', patientInfo);

fclose(fid);

disp('Patient folder and information file created successfully.');

