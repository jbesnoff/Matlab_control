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

%Reset VNA
e5062a_ctrl(vna0, 'reset','wait');

%Initialize and load calibration state
e5062a_ctrl(vna0, 'load-state', 'oct_loop_field_saline.sta');

%% User defined parameters

%Set desired frequency range
f_start = 300e3;
f_stop = 3e9;

%Number of points (maximum is 1601)
pts = 1601;

freq = linspace(f_start,f_stop,pts);

%Apply frequency range to VNA
e5062a_ctrl(vna0, 'set-f-vec', freq);

%Ask user for save location
disp(' ')
disp('Hit enter and then choose directory to save files.')
disp(' ')
pause
save_dir = uigetdir;


flag = true;
while(flag)

    filename = input('Enter filename (enter q to quit): ','s');
    disp(' ')
    
    if strcmp(filename,'q')
        flag = false;
        break
    end

    
%     %Pause before data capture
%     pause(10)
%     disp(' ')
%     disp('Capturing data now...')
%     disp(' ')

    %Set averaging factor
    e5062a_ctrl(vna0, 'avg-factor', 25);

    %Turn averaging on
    e5062a_ctrl(vna0, 'avg-on');
    
    %Capture data
    pause(1)
    e5062a_ctrl(vna0, 'avg-clear');
    pause(8)
    s11 = e5062a_ctrl(vna0, 'get', 's11');
    e5062a_ctrl(vna0, 'avg-clear');
    pause(8)
    s21 = e5062a_ctrl(vna0, 'get', 's21');
    e5062a_ctrl(vna0, 'avg-clear');
    pause(8)
    s12 = e5062a_ctrl(vna0, 'get', 's12');
    e5062a_ctrl(vna0, 'avg-clear');
    pause(8)
    s22 = e5062a_ctrl(vna0, 'get', 's22');
    pause(1)
    
    disp(' ')
    tmp = 20*log10(abs(s21(489)));
    disp(['Loss at 915 MHz is: ',num2str(tmp),' dB/cm'])
    disp(' ')

    %Save data as .mat file
    %Save string
%     pathname = '/Users/Jordan/Dropbox/Duke/Research/NF_segmented_loops_PL_test/';
%     filename = ['saline_large_small_feedpoint_',dist];
    full_path = [save_dir,'/',filename];

    %Save all data
    save(full_path,'s11','s12','s21','s22','freq')
    
end

%% Cleanup

%Close VNA connection
e5062a_ctrl(vna0, 'close');
