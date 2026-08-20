clear;
clc;

%{
Open and read mat file containing Alpha and Beta band results from patient
EEG. Find average Peak Beta. Frequency across all EEG electrodes to
determine baseline Beta Freq. to be used as initial stimulation parameter. 

Prompts user to input stimulation intensities (amplitude) and factors of
which baseline beta freq will be multiplied (ie 10% enter 0.1). 

Connects to and employ Neuroelectrics Starstim 8 to cycle through each
calculated frequency and amplitude pair randomly. 

Records as an Array [Frequency, Amplitude, Timestamp of Start] and saves as
mat file to the patient folder
%}

% Load tACS Values
response1 = input('Enter the patient ID: ', "s");
response2 = input('Enter the trial: ', "s");

folderName = sprintf('PatientID_%s', response1);
addpath(folderName);

fileName = sprintf('eegdata_%s_trial_%s.mat', response1, response2);

data = load(fileName);

EEG_results = data.EEG_results;

peak_beta_EEG = table2array(EEG_results.beta(:, 2)); % 8x1 beta values
peak_beta_EEG = peak_beta_EEG(:); 

base_beta_freq = mean(peak_beta_EEG);

% Show the Initial Stimulation Conditions 
disp('Enter initial stimulation frequency as:')
disp(base_beta_freq);

% Initialize Freq. Factors
factors = [0.5 0.9 1 1.1 1.5];
factors = factors(:)';

% Initialize Amp. Factors
amp = [0.5 1 1.5 2];
amp = amp(:)';

% Create Random Storage for each Stimulation
[freq_rand, amp_rand] = ndgrid(factors, amp);

stimulation_vals = [base_beta_freq .* freq_rand(:), amp_rand(:)];

% Repeat Each x3
stimulation_vals = repelem(stimulation_vals, 3, 1);

% Add Sham
stimulation_vals = [stimulation_vals; base_beta_freq, 0];

% Randomize Order
stimulation_vals = stimulation_vals(randperm(size(stimulation_vals,1)), :);

rows = size(stimulation_vals,1);
timestamps = NaT(rows,1); 
impedance_check = NaT(rows,1);

stim_duration = 5; % seconds
numRounds = rows;

% Add Factor. Row

factor_value = zeros(rows,1);

for a = 1:rows;
    factor_value(a) = stimulation_vals(a,1) / base_beta_freq;
end 
stimulation_vals = [stimulation_vals'; factor_value'];
stimulation_vals = stimulation_vals';

for i = 1:numRounds
    freqArray = stimulation_vals(i, 1);
    amplitudeArray = stimulation_vals(i, 2);
    phaseArray = zeros(8, 1);
    transition = 100000; % Check this value

    timestamps(i) = datetime;
    timestamp(i).Format = 'yyyy-MM-dd HH:mm:ss.SSS';
    
    impendance_check(i) = 5.0;
    
    pause(stim_duration)

end 

% Save the Stimulation Values and Timestamps

stim_table = table(stimulation_vals(:,1), stimulation_vals(:,3), ...
    stimulation_vals(:,2), ...
    timestamps, ...
    'VariableNames', {'Frequency_Hz', 'Freq_Factor', 'Amplitude_mA', 'Start_Time'});

fileName = sprintf('stimstamps_%s_trial_%s.mat', response1, response2);
save(fullfile(folderName, fileName), 'stimulation_vals', 'timestamps', ...
    'stim_table');




    