%Jordan Besnoff
%27 November 2012
%Duke University
%get_S_params.m
%
%This script will grab all the S-parameter data from the network analyzer
%and save it to a desired location with a user defined filename
%The e5062a_ctrl.m script will be used to communicate with the NA.
%
%Currently, the user will have to calibrate the NA as desired. Off-line
%calibration can be incorporated if desired.
%
%NETWORK SETTINGS:
%IP address: 192.168.1.x, where x is any open location (0-255)
%Subnet mask: 255.255.255.0
%Router: 192.168.1.1
%
%NOTE: State06.sta for small octagonal loops
%      State07.sta for large square segmented and small octagonal loops
%      State01.sta for return loss of octagonal loop antennas


clear all
close all
clc

%% Initialize NA

%Open connection to NA
vna0 = e5062a_ctrl('192.168.1.98', 'open','wait');

%Flush buffers
pause(1)
e5062a_ctrl(vna0, 'flush-host-buffers','wait');

      fprintf(vna0, ':INIT1:CONT ON'); % continuous mode: on
      fprintf(vna0, ':FORM:DATA REAL'); % 64 bit float (IEEE)
      fprintf(vna0, ':FORM:BORD NORMal'); % MSB first
      fprintf(vna0, ':CALC1:FORM SCOMplex'); % complex data

%Reset VNA
% e5062a_ctrl(vna0, 'reset','wait');

%Initialize and load calibration state
% e5062a_ctrl(vna0, 'load-state', 'State_singlewire_full2port.sta');

%% User defined parameters

%Set desired frequency range
% f_start = 300e3;
% f_stop = 3e9;

%Number of points (maximum is 1601)
% pts = 1601;

% freq = linspace(f_start,f_stop,pts);

%Apply frequency range to VNA
% e5062a_ctrl(vna0, 'set-f-vec', freq);

%Ask user for save location
disp(' ')
disp('Hit enter and then choose directory to save files.')
disp(' ')
pause
save_dir = uigetdir;


%Total iterations
iter = 100;

filename = input('Enter filename (enter q to quit): ','s');
disp(' ')

for i = 1:iter

    %Capture data
    pause(1)
    s11(:,i) = e5062a_ctrl(vna0, 'get', 's11');
    pause(4)
    i
    
    time(:,i) = clock';
%     s21 = e5062a_ctrl(vna0, 'get', 's21');
%     pause(1)
%     s12 = e5062a_ctrl(vna0, 'get', 's12');
%     pause(1)
%     s22 = e5062a_ctrl(vna0, 'get', 's22');
%     pause(1)




    
end

f = e5062a_ctrl(vna0, 'get-f-vec');

    %Save data as .mat file
    %Save string
%     pathname = '/Users/Jordan/Dropbox/Duke/Research/NF_segmented_loops_PL_test/';
%     filename = ['saline_large_small_feedpoint_',dist];
    full_path = [save_dir,'/',filename];

    %Save all data
    save(full_path,'s11','time','f')

%% Cleanup

%Close VNA connection
% e5062a_ctrl(vna0, 'close');
