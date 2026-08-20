# Method & Processes 
Code to store data, analyze EEG data to generate experimental parameters, run Neuroelectrics Starstim 8 tACS stimulation and analyze effect of stimulation on physical tremor via power spectra analysis of geneActive accelerometry data.

In order of use, 

1. onboarding_parkinsonexp.m
 - Creates a folder distinguished by patient ID #
 - Inputs date and any additional patient information and stores as a TXT file. 
 - **Complete EEG process via. Neuroelectrics interface and save data file to this folder, name formatted as 'eegrecording_ID_trial_#'**

2. eegdataanalysis_parkinsonexp.m
 - Reads eeg data. Determines Resting Alpha Frequency at each electrode and applies identical process to the beta band.
 - Saves a matlab file containing patientID, trial number, date of processing, and results from the Alpha and Beta Bands (Peak Freq. Peak Power. Total Power).
  
3. stimulationprocedure_parkinsonexp.m
 - Open and read mat file containing Alpha and Beta band results from patient EEG.
 - Determines average Peak Beta Frequency across all EEG electrodes to determine baseline Beta Freq. to be used as initial stimulation parameter.
 - Generates experimental stimulation values as randomized frequency amplitude pairs. Amplitude values range from 0.5, 1, 1.5, 2 uV and frequencies as peak beta frequency evalauted at factors of 0.5, 0.9, 1, 1.1, 1.5. Each experimental condition is then randomly repeated 3 times throughout the stimulation for a duration of 30 seconds. Condition arrays are inclusive of one round of sham stimulation (amplitude 0).
 - **Total stimulation duration is 30 m 30s.**
 - Connects to Neuroelectrics device and guides device through stimulation at each condition.
 - **Verify input transition; time to transition between stimulation parameters (entered in ms, currently at 1 second)** 
 - Tracks progress as an Array [Frequency, Amplitude, Timestamp of Start] and saves as mat file to the patient folder once stimulation is fully complete.

4. accdataanalysis_parkinsonexp.m
  - **Operate geneActiv wrist watch via. interface and save data to file of the form 'accdata_ID_trial_#'.**
  - Open and read stimulation parameters to extract timestamps. Matches to wrist watch timestamps to determine condition epochs of XYZ acceleration.
  - Filter data with FIR Bandpass of 250th Order from 1-20 Hz.
  - Filter with Notch Filter at 60 Hz (North America Value)
  - Segment data into each Condition Epoch and
      - Perform Principal Component Analysis on XYZ data to determine most variant points.
      - Use PC1 to maximize variance and determine dominant directional motion at each sampling point.
      - Extract Power Spectra of PC1 using PWelch (Built in Mat Function)
      - Determine Peak Power and Freq. of Power Spectra and Total Power around Parkinsonian Tremor Band (1-20 Hz)
      - Save Figure of Spectra and Store Peak Values

Opts. stimulationmethods_noconnect.m
- generates sample experimental stimulation values without connecting to neuroelectrics technology. 

# Example Figure / Tables
- Example stimulation conditions derived from peak beta-frequency collected from rough resting-state EEG
- Accelerometry data depicts subtle motion of the right hand (not tremor accurate)
accdata_000_trial_1.csv is of the format returned by the geneActiv wristwatch program
- (5) example figs of power spectra of stimulation epochs, from which peak freq and relative power is to be determined (for quick analysis)
- tremormotion depicts PC1; dominant acceleration across total stimulation duration
  


