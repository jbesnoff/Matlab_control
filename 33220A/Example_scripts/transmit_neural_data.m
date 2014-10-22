%Jordan Besnoff
%Duke University
%11 April 2013
%transmit_neural_data.m
%
%This script communicates with the Agilent 33220A Arbitrary Function
%Generator to send neural data to the Bug3 chip.

clear all
close all
clc


%% Open and initialize 33220A

fg0 = fg33220a_ctrl('192.168.1.92', 'open'); % open new connection
pause(1)
fg33220a_ctrl(fg0, 'flush-host-buffers'); % make sure the host buffers are empty (just as a precaution)
pause(1)
fg33220a_ctrl(fg0, 'reset') % reset the FG device (should display device ID)
pause(1)


%% Load neural data

%Load prepared neural data
%Loads: spike_train - neural data, fs - sampling frequency, ts - sample
%period, t - time vector
load('monkey_neural_data.mat')

%Cast neural data as double precision, to avoid errors when normalizing
spike_train = double(spike_train);


%Since the 33220A increases the length of any loaded data to its maximum
%number of points, 65536, we pad the neural data with 0's to reach the max
% max_pts = 65536;  %internal to 33220A
% max_pts = 64e3;
% nd_length = length(spike_train);
% add_pts = max_pts-nd_length;
% spike_train = [spike_train; zeros(add_pts,1)];

%Fix time vector to take new padded zeros into account
t = ts*(0:length(spike_train)-1);
 
%Determine frequency setting for function generator, based on length and
%sampling frequency of data to load
fg = fs/length(spike_train);

%IMPORTANT: scale data to between -1.0 and 1.0 for scaling within the
%33220A
maxval = max(spike_train);
minval = min(spike_train);
boundary_min = -1;
boundary_max = 1;
a = boundary_max - boundary_min;
b = boundary_min;
c = a / (maxval - minval);
spike_train_norm = c * (spike_train - minval) + b;


%Set frequency and voltage range
fg33220a_ctrl(fg0, 'set-freq', fg);  %set output frequency in Hz
pause(1)
fg33220a_ctrl(fg0, 'set-amp', 10e-3);  %set output amplitude in Vpp
pause(1)
fg33220a_ctrl(fg0, 'set-offset', 0);  %set DC offset in V
pause(1)

%Load data into function generator
fg33220a_ctrl(fg0, 'load-data', spike_train_norm);

fg33220a_ctrl(fg0, 'error-log')

 
%Turn the output on 
fg33220a_ctrl(fg0, 'output', 'ON');  % Turn output on or off
 
%% Cleanup
%Close device
% fg33220a_ctrl(fg0, 'close');

