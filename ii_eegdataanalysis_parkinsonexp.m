clear; 
close all;
clc;

%{
Open text file and read patient EEG data. Determine RAF at each electrode 
and apply a similar process to the beta band.

Saves a matlab file containing patientID, trial number, date of processing,
and results from the Alpha and Beta Bands (Peak Freq. Peak Power. Total
Power). 
%}

% Load Patient Data
response1 = input('Enter the patient ID: ', "s");
response2 = input('Enter the trial / round number: ', "s");

% Determine which Channels were used
    % Ideally use same channels across all patient eegs (in procedure) 
    % Record which channels were used in patient file?

response3 = input('Enter eeg electrode channels (e.g. [1 2 3 5 8]): ');
channels_used = unique(response3);

folderName = sprintf('PatientID_%s', response1);
addpath(folderName);

% Check File Exists
if ~exist(folderName, 'dir')
    error('Patient folder not found.');
end

% Import Data
datafilename = sprintf('eegrecording_%s_trial_%s.txt', response1, response2);
fs_EEG = 500; % Hz
fs_acc = 100; % Hz

data = readmatrix(datafilename, 'Delimiter', '\t');

condition_names = {'Eyes Closed'}; % Add eyes open, etc dep. on eeg process

channel_code = {'CH1','CH2','CH3','CH4','CH5','CH6','CH7','CH8'};

% Prep Alpha/Beta Storage
alpha_results = table('Size',[0 4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',{'Electrode','PeakAlphaFreq_Hz', ...
                     'PeakAlphaPower_uV2Hz','TotalAlphaPower_uV2'});

beta_results = table('Size',[0 4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',{'Electrode','PeakBetaFreq_Hz', ...
                     'PeakBetaPower_uV2Hz','TotalBetaPower_uV2'});

% Prepare Storage For Suggested tACS Values
stim_values = table('Size', [0, 3],'VariableTypes', {'string', 'double', 'double'}, ...
    'VariableNames', {'Electrode', 'SuggestedBetaFreq_Hz', 'SuggestedAmplitude_mA'});

% Notch Filter; Remove 60 Hz Noise
f0 = 60;
wn = [59 61] / (fs_EEG/2);
n = 300;

b = fir1(n, wn, 'stop');

% Bandpass Filter; 1-100 Hz
highpass = 1 / (fs_EEG/2); % Noise below 1 Hz (0.5?)
lowpass = 100 / (fs_EEG/2);  
n = 300;

c = fir1(n, [highpass lowpass], 'bandpass');

% Set PWelch Param.
wn = hamming(1024); % As suggested in Corcoran
noverlap = 1024/2;
nfft = 2048;

% Epoch Info
% Prep to Split Data into Segments (4-Second Epochs) 
epoch_length = 4; % in sec
n_per_epo = epoch_length * fs_EEG;
num_epochs = floor(length(data)/n_per_epo);

epochs = zeros(n_per_epo, num_epochs);

PSD = [];

% Analyze Data by Channel, Epoch 
for ch = 1:channels_used

    eeg_export = data(:, ch);

    % Split into 4s Epochs; Perform Pwelch
    for i = 1:num_epochs
    
        idx1 = (i-1)*n_per_epo + 1;
        idx2 = i*n_per_epo;
    
        eeg = eeg_export(idx1:idx2);
    
        uV_eeg = eeg/1000; % converts mA to uA
    
        % Define time
        time = (0:size(uV_eeg, 1) - 1) / fs_EEG;
    
        % Filter Signal
        filtered_eeg = detrend(uV_eeg, 'linear'); % Remove linear drift
        filtered_eeg = filtfilt(b, 1, filtered_eeg); % Zero phase Notch filter
        filtered_eeg = filtfilt(c, 1, filtered_eeg); % zero phase bandpass filter
    
        % Transform via PWelch Power Spectrum
        %{ 
        figure;
        tiledlayout(2,1);
    
        nexttile;
        plot(time, uV_eeg(:, ch), "Color", "r");
    
        nexttile;
        plot(time, filtered_eeg(:, ch), "Color", "b");
        %}

        % Apply PWelch 
        [pxx,freq] = pwelch(filtered_eeg,wn,noverlap,nfft,fs_EEG);

        if isempty(PSD)
            PSD = zeros(length(pxx),num_epochs,8);
        end
        
        PSD(:,i,ch) = pxx;
    end 

    % Reject Outlying Epochs by IQR
    PSD_avg = zeros(size(PSD,1),8);   % One averaged PSD per channel

    % PSDs for one channel
    PSD_ch = PSD(:,:,ch);

    % Normalize each epoch
    normalized_PSD = PSD_ch ./ sum(PSD_ch,1);

    % Mean PSD across epochs
    meanPSD = mean(normalized_PSD,2);

    % Euclidean distance of each epoch from the median
    distance = zeros(1,num_epochs);

    for i = 1:num_epochs
        distance(i) = norm(normalized_PSD(:,i) - meanPSD);
    end

    % IQR threshold
    Q1 = prctile(distance,25);
    Q3 = prctile(distance,75);
    IQR = Q3 - Q1;

    threshold = Q3 + 1.5*IQR;

    % Good epochs
    keep = distance <= threshold;

    % Average PSD using only good epochs
    PSD_avg(:,ch) = mean(PSD_ch(:,keep),2);

% Filter Remaining Data & Find Peaks

    % Apply Savitzky-Golay Filter
    k = 5;
    wn_sg = 9; % 11 Suggested in Paper, 7 Best capture of peak 
    filtered_pxx = sgolayfilt(PSD_avg(:,ch), k, wn_sg);

    % Plot PSD
    figure
    plot(freq,10*log10(filtered_pxx))
    hold on

    title(sprintf('Power Spectrum via PWelch : %s',channel_code{ch}))
    xlabel('Frequency (Hz)')
    ylabel('dB/Hz')

    xregion(7,14)
    xregion(15,30)
    xlim([1 50])

    % Determine Individual Alpha Freq. Values
    alpha_band = [7 14];
    alpha_idx = freq >= alpha_band(1) & freq <= alpha_band(2);

    alpha_freq = freq(alpha_idx);
    alpha_pxx = filtered_pxx(alpha_idx);

    [peak_alpha_power, max_u] = max(alpha_pxx);
    peak_alpha_freq = alpha_freq(max_u);

    alpha_total_power = trapz(alpha_freq, alpha_pxx);
    
    % Store Alpha Values @ Each Electrode
    add_row_alpha = table(string(channel_code{ch}), ...
    peak_alpha_freq, peak_alpha_power, alpha_total_power, ...
    'VariableNames', {'Channel of Electrode','PeakAlphaFreq_Hz', ...
                       'PeakAlphaPower_uV2Hz','TotalAlphaPower_uV2'});
    
    alpha_results = [alpha_results; add_row_alpha];

    % Determine Beta Freq. Values
    beta_band = [15 30];
    beta_idx = freq >= beta_band(1) & freq <= beta_band(2);

    beta_freq = freq(beta_idx);
    beta_pxx  = filtered_pxx(beta_idx);

    [peak_beta_power, max_i] = max(beta_pxx);
    peak_beta_freq = beta_freq(max_i);

    beta_total_power = trapz(beta_freq, beta_pxx);
    
    % Store Beta Values @ Each Electrode
    add_row_beta = table(string(channel_code{ch}), ...
    peak_beta_freq, peak_beta_power, beta_total_power, ...
    'VariableNames', {'Channel of Electrode','PeakBetaFreq_Hz', ...
                       'PeakBetaPower_uV2Hz','TotalBetaPower_uV2'});
    
    beta_results = [beta_results; add_row_beta];
end

% Save Beta & Alpha Results to Patient Folder
fileName = sprintf('eegdata_%s_trial_%s.mat', response1, response2);

EEG_results = struct();

EEG_results.patientID = response1;
EEG_results.trial = str2double(response2);
EEG_results.alpha = alpha_results;
EEG_results.beta = beta_results;
EEG_results.dateProcessed = datetime;
EEG_results.sourceFile = datafilename;   % data file 
EEG_results.savedFile = fileName;

save(fullfile(folderName, fileName), 'EEG_results');

disp('EEG results saved.');


