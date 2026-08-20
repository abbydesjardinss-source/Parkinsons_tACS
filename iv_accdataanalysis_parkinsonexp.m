
clear;
clc;
close all; 

%{
Access patient file and load data table containing stimulation values.
From this table, read the start time of each condition and analyze
accelerometry data by 30 second epochs. 

Perform Principal Component Analysis on the data and analyze the PWelch 
Power Spectra of the first component.

Save a matlab data structure containing peak frequency (Hz), power (m^2/s^4 / Hz), and total
power (m^2/s) values along with corresponding figures. 
%}

% Open File 
response1 = input('Enter the patient ID: ', "s");
response2 = input('Enter the trial: ', "s");

folderName = sprintf('PatientID_%s', response1);
addpath(folderName);

% Create Folder for Figures
figureFolder = fullfile(folderName, ...
    sprintf('accFigures_Trial_%s', response2));

if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end

% Load Accelerometry Data
accfileName = sprintf('accdata_%s_trial_%s.csv', response1, response2);
opts = detectImportOptions(accfileName);
opts.DataLines = [101, Inf]; % Skip header/ info
importData = readtable(accfileName, opts);

accData = string(importData.Frequency_100);
accData = erase(accData,"'");
accData = split(accData,",");

% Match Time Format
accDate = string(importData.Measurement);
accClock = accData(:,1);
accTime = accDate + " " + accClock;
accTime = datetime(accTime,...
    'InputFormat','yyyy-MM-dd HH:mm:ss:SSS');

% Isolate X,Y,Z Components
x = str2double(accData(:,2));
y = str2double(accData(:,3));
z = str2double(accData(:,4));

xyzData = [x y z];

% Load Stimulation Data
stimfileName = sprintf('stimstamps_%s_trial_%s.mat', response1, response2);
load(stimfileName);

conditionStart = stim_table.Start_Time;

stimdata = [stim_table.Frequency_Hz stim_table.Amplitude_mA];

% Define Measurement Frequency 
fs = 100;

% Define Notch Filter; Remove 60 Hz Noise (NA)
f0 = 60;
wn = [59 61] / (fs/2);
r = 300;
c = fir1(r, wn, 'stop');

% Define FIR Bandpass of 250th Order from 1-20 Hz
n = 250;
w = [1 20] / (fs/2);  
b = fir1(n, w, 'bandpass');

% Filter Signals 
xyzData = filtfilt(c, 1, xyzData); % Zero phase filter
xyzData = detrend(xyzData, 'linear'); % Remove linear drift

xyzData = filtfilt(b, 1, xyzData); 

% Analyze Data by Condition Epochs

% Prep Storage
accresults = struct();
resultid = 1;

epochLength = 30; % seconds
N = fs*epochLength;

% Set PWelch Param.
wn = hamming(1024); % As suggested in Corcoran
noverlap = 1024/2;
nfft = 2048;

for i = 1:size(stimdata, 1)
    
    % Find closest timestamp in acc data
    [~, idx] = min(abs(accTime - conditionStart(i)));

    % Isolate Epoch
    xyzEpoch = xyzData(idx:idx+N-1, :);

    % PCA of Epoch
    [coeff, score, latent, ~, explained] = pca(xyzEpoch);
    
    pc1 = score(:,1); % Select First Component
    
    % Power Spectrum via PWelch
    [pxx, freq] = pwelch(pc1, wn, noverlap, nfft, fs);

    % Save Results
    accresults(resultid).pc1 = pc1;
    accresults(resultid).score = score;
    accresults(resultid).explained = explained;
    accresults(resultid).freq = freq;
    accresults(resultid).pxx = pxx;

    % Restrict freq. to 1-20 Hz (PT Range)
    int = freq >= 1 & freq <= 20;

    freqBand = freq(int);
    pxxBand = pxx(int);

    % Determine Peak Power & Frequency
    [peak_power, idx] = max(pxxBand);
    peak_freq = freqBand(idx);

    % Determine Total Power (Around PT Range)
    total_power = trapz(freqBand, pxxBand);

    % Save Power Spectrum results
    accresults(resultid).condition = i;
    accresults(resultid).peak_power = peak_power;
    accresults(resultid).peak_freq = peak_freq;
    accresults(resultid).total_power = total_power;

    % Plot PWelch Power Spect.
    fig = figure;
    plot(freq(int), pxx(int));
    xlim([1 20]);
    xlabel('Frequency (Hz)');
    ylabel('Power (m^2/s^4 /Hz)');
    title(sprintf('PWelch Power Spectrum of Stim Condition %d', i));

    % Save figure
    savefig(fig, fullfile(figureFolder, ...
    sprintf('PWelch_Condition_%d.fig', i)));

    resultid = resultid + 1;
end 

% PCA of Whole Signal 
[coeff, score, latent, ~, explained] = pca(xyzData);

wpc1 = score(:,1);

% Plot First Component of Motion
pcfig = figure;
plot(wpc1);
ylabel('PC1 (g)');
xlabel('Progression');
title('Proper Acceleration in the Dominant Axis');

% Save figure
savefig(pcfig, fullfile(figureFolder, ...
sprintf('Acceleration across Conditions_Trial_%d.fig', response2)));

% Save Recorded Results as .mat file
filename = sprintf('accresults_%s_trial_%s.mat', response1, response2);
save(fullfile(folderName, filename), 'accresults');