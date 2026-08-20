clear;
clc;

%{
Open and read mat file containing Alpha and Beta band results from patient
EEG. Find average Peak Beta. Frequency across all EEG electrodes to
determine baseline Beta Freq. to be used as initial stimulation parameter. 

Generates  experimental stimulation values by randomly generating amplitude
and frequency pairs. 

Amplitude run at 0.5, 1, 1.5, 2 uv. 
Frequency run as 0.5, 0.9, 1.1, 1.5 of Baseline (Factors of 50%, 10%). 

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

disp('Loading Stimulation Values')

% Initialize Freq. Factors
factors = [0.5 0.9 1 1.1 1.5];
factors = factors(:)';

% Initialize Amp. Factors
amp = [0.5 1 1.5 2];
amp = amp(:)';

% Create Random Storage for each Stimulation
[freq_rand, amp_rand] = ndgrid(factors, amp);

stimulation_vals = [base_beta_freq .* freq_rand(:), amp_rand(:)];

% Repeat Each Condition x3 
stimulation_vals = repelem(stimulation_vals, 3, 1);

% Add Sham
stimulation_vals = [stimulation_vals; base_beta_freq, 0];

% Randomize Order
stimulation_vals = stimulation_vals(randperm(size(stimulation_vals,1)), :);

timestamps = NaT(size(stimulation_vals, 1) , 1);  
impedance_check = NaT(size(stimulation_vals, 1) , 1); 
factor_values = zeros(size(stimulation_vals, 1));

% Record Factor 
for a = 1:size(stimulation_vals,1)
    factor_values(a) = stimulation_vals(a,1) / base_beta_freq;
end 

stimulation_vals = [stimulation_vals'; factor_values'];
stimulation_vals = stimulation_vals';

start = input('Input to Connect Device: ');

% Connect Device
patientName = response1;
stim_duration = 30; % In seconds, for each condition
numRounds = size(stimulation_vals,1);

[ret, status, socket] = MatNICConnect ('10.121.150.38'); 

disp('MatNICConnect returned:');
disp(ret);

disp('Status:');
disp(status);

if ret == 0

    disp('Connection successful');

    [ret, status] = MatNICQueryStatus (socket);
    
    if ret == 0 
    
        protocolName = input('Select the Protocol: ', "s");
        [ret] = MatNICLoadProtocol (protocolName, socket); % Load Protocol
    
        % Prepare to Save File by Patient Name
        [ret] = MatNICConfigureFileNameAndTypes (patientName, true, false, false, false, false, socket);
        
        % Start the Stimulation 
        [ret] = MatNICStartProtocol (socket); 
    
        disp('Starting the Protocol');
    
            for i = 1:numRounds
                freqArray = stimulation_vals(i, 1);
                amplitudeArray = stimulation_vals(i, 2);
                phaseArray = zeros(8, 1);
                transition = 1000; % Check this value, transition time in ms
    
               [ret] = MatNICOnlinetACSChange(amplitudeArray, freqArray, phaseArray, n_channels, transition, socket);
                              
               timestamps(i) = datetime;
               timestamps(i).Format = 'yyyy-MM-dd HH:mm:ss.SSS';
    
               [ret, status] = MatNICQueryStatus (socket);
    
                if ret ~= 0 
                    [ret] = MatNICAbortProtocol (socket);
                    disp('Protocol Aborted')
                    return 
                end
                
                [ret, impedance_set] = MatNICGetImpedance(socket);
                
                disp(impedance_set)
                impedance_check(i) = impedance_set;
    
                pause(stim_duration)
            end 
    
        % Stop the Protocol
        [ret] = MatNICAbortProtocol (socket);
    end
else
    fprintf('MatNICConnect FAILED. ret = %d\n', ret);
end

disp('Protocol Complete')    
   
% Save the Stimulation Values and Timestamps
stim_table = table(stimulation_vals(:,1), ...
    stimulation_vals(:,3), ...
    stimulation_vals(:,2), ...
    timestamps, ...
    'VariableNames', ...
    {'Frequency_Hz', 'Freq_Factor', 'Amplitude_mA', 'Start_Time'});

fileName = sprintf('stimstamps_%s_trial_%s.mat', response1, response2);
save(fullfile(folderName, fileName), 'stimulation_vals', 'timestamps', ...
    'stim_table');

          
 
    
   


