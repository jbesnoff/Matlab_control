%  USAGE:
%  %     basic
%  sa0 = n9320b_ctrl('192.168.1.90', 'open'); % open new connection
%  n9320b_ctrl(sa0, 'flush-host-buffers'); % make sure the host buffers are empty (just as a precaution)
%  n9320b_ctrl(sa0, 'reset'); % reset the SA device (should display device ID)
%  %     frequency setup
%  n9320b_ctrl(sa0, 'set-f-cent', 915e6);                                     % set center frequency
%  n9320b_ctrl(sa0, 'set-f-span', 50e6);                                      % set frequency span
%  f = n9320b_ctrl(sa0, 'get-f-vec');                                         % return frequency sweep settings (quick&dirty way to check if the setup is OK)
%  %     resolution bandwidth setup
%  n9320b_ctrl(sa0, 'set-rbw', 10e3);                                         % set resolution BW
%  RBW = n9320b_ctrl(sa0, 'get-rbw');                                         % get resolution BW
%  %     reference level and attenuation
%  n9320b_ctrl(sa0, 'set-ref-lvl', 15);                                       % set reference level (dB)
%  n9320b_ctrl(sa0, 'set-atten', 0);                                          % set input attenuation (dB)
%  %     average state and count
%  n9320b_ctrl(sa0, 'set-avg-state', 'on/off');                               % set averaging on or off
%  n9320b_ctrl(sa0, 'set-avg-count', 25);                                     % set # averaging points
%  %     set marker location & grab value
%  n9320b_ctrl(sa0, 'set-mark', [1, 915e6]);                                  % set marker # and location
%  mark_val = n9320b_ctrl(sa0, 'get-mark', 1);                                % get value of given marker
%  %     trace setup
%  n9320b_ctrl(sa0, 'set-trace-state', 'Write/MaxHold/MinHold/View/Blank');   % set trace state
%  %		measure ...
%  data = n9320b_ctrl(sa0, 'get');                                            % grab trace data as vector of values
%  %		close connection
%  n9320b_ctrl(sa0, 'close');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Changelog:
%%%
%%% 2013-jan-31 ::: Jordan Besnoff
%%% %%% Created the original control file. Unfortunately, in its current
%%% state, the N9320B must be controlled by a Windows machine with the
%%% Agilent IO tools installed. The N9320B can only be accessed as a
%%% VISA-TCPIP object and not as a regular TCPIP object, although the
%%% control works the same. Functionality for initializing the device,
%%% setting frequency parameters, setting RBW, setting reference level and
%%% attenuation, setting averaging, changing the trace state, and recording
%%% the trace waveform along with a frequency vector have been created.
%%%
%%% Please add any needed functionality to this control file and document
%%% the changes here. Thanks :)
%%%
%%%
%%% 2013-feb-6 ::: Jordan Besnoff
%%% %%% Added a pause equivalent to double the current sweeptime for the
%%% 'get' command to allow the data to settle before capturing it. Also
%%% added a 'get-rbw' command that allows one to grab the current RBW.





function out = n9320b_ctrl(device, cmd, in)

out = device;

switch lower(cmd)
   % open, close, reset
   case 'open'
      visa_obj = ['TCPIP0::',device,'::inst0::INSTR'];
      out = visa('AGILENT', visa_obj, 'InputBufferSize', 10^6, 'Timeout', 5);
      if nargin > 2
          pause(2); % <-- SJT: Wait included so we dont' have to
                    % step-by-step execute all of the instructions
      end % if nargin > 2
      fopen(out);
   case 'close'
      fprintf(device, '*RST');
      fclose(device);
   case 'reset'
      fprintf(device, '*RST');
      if nargin > 2
          pause(1); % <-- SJT: Wait included so we dont' have to
                    % step-by-step execute all of the instructions
      end % if nargin > 2
      fprintf(device, '*CLS');
      if nargin > 2
          pause(4); % <-- SJT: Wait included so we dont' have to
                    % step-by-step execute all of the instructions
      end % if nargin > 2
      fprintf(device, '*IDN?');
      out = strtrim(fscanf(device));
   case 'flush-host-buffers'
      flushinput(device);
      flushoutput(device);
      if nargin > 2
          pause(1); % <-- SJT: Wait included so we dont' have to
                    % step-by-step execute all of the instructions
      end % if nargin > 2
   case 'flush-device-buffers'
      clrdevice(device)
      
    % set center frequency
    case 'set-f-cent'
      if length(in) > 1601
         fprintf(2, 'Warning: 1601 points maximum.\n');
      end
      fprintf(device, sprintf(':SENSe:FREQuency:CENTer %E', in));
      
    % set frequency span  
    case 'set-f-span'
      fprintf(device, sprintf(':SENSe:FREQuency:SPAN %E', in));
      
    % set resolution bandwidth  
    case 'set-rbw'
        fprintf(device, sprintf(':SENSe:BANDwidth:RESolution %E', in));
        
    % get resolution bandwidth
    case 'get-rbw'
        out = query(device, ':SENSe:BANDwidth:RESolution?', '%s', '%f');
        
    % set reference level    
    case 'set-ref-lvl'
        fprintf(device, sprintf(':DISPlay:WINDow:TRACe:Y:SCALe:RLEVel %E', in));
        
    % set input attenuation    
    case 'set-atten'
        fprintf(device, sprintf(':SENSe:POWer:RF:ATTenuation %E', in));
      
    % set averaging state (on or off)  
    case 'set-avg-state'
        if ~strcmp(in, {'on','off'})
            fprintf(2, 'Warning: Invalid entry, must be string "on" or "off"\n');
            out = []; return
        end
        if strcmp(in, 'on')
            state = 1;
        else
            state = 0;
        end
        % set state
        fprintf(device, sprintf(':SENSe:AVERage:STATe %d', state));
        
    % set # averaging points    
    case 'set-avg-count'
        fprintf(device, sprintf(':SENSe:AVERage:COUNt %d', in));
        
    % set marker # and location    
    case 'set-mark'
        %Check marker range
        if in(1) < 1 || in(1) > 12 || ~(mod(in(1),1)==0)
            fprintf(2, 'Warning: Invalid entry, marker number must be between 1 and 12\n');
            out = []; return
        end
        %Check marker state - if off, turn on
        mstate = query(device, sprintf(':CALCulate:MARKer%d:STATe?',in(1)), '%s', '%f');
        if mstate==0
            fprintf(device, sprintf(':CALCulate:MARKer%d:STATe 1',in(1)));
        end
        fprintf(device, sprintf(':CALCulate:MARKer%d:X %E',in(1),in(2)));
        
    % get specified marker value    
    case 'get-mark'
        %Check marker range
        if in < 1 || in > 12 || ~(mod(in,1)==0)
            fprintf(2, 'Warning: Invalid entry, marker number must be between 1 and 12\n');
            out = []; return
        end
        out = query(device, sprintf(':CALCulate:MARKer%d:Y?',in), '%s', '%f');
        
    % set trace state    
    case 'set-trace-state'
        if ~strcmp(in, {'Write','MaxHold','MinHold','View','Blank'})
            fprintf(2, 'Warning: Invalid trace state entry\n');
            out = []; return
        end
        
        if strcmp(in,'Write')
            fprintf(device,':TRACe1:MODE WRITe');
        elseif strcmp(in,'MaxHold')
            fprintf(device,':TRACe1:MODE MAXHold');
        elseif strcmp(in,'MinHold')
            fprintf(device,':TRACe1:MODE MINHold');
        elseif strcmp(in,'View')
            fprintf(device,':TRACe1:MODE VIEW');
        else
            fprintf(device,':TRACe1:MODE BLANk');
        end

   % transfer data from the device
   case 'get'
      % get sweep time
      fprintf(device, ':SENSe:SWEep:TIME?'); pause(0.1);
      sweeptime = fscanf(device, '%f');
      % get data
      pause(2*sweeptime);  %Wait a couple sweeps for data to settle
      fprintf(device, ':TRACe:DATA? TRACE1'); pause(0.1);
      out = str2num(fscanf(device));

   % generate frequency vector from settings
   case 'get-f-vec'
      f_start = query(device,':SENSe:FREQuency:STARt?', '%s', '%f');
      f_stop = query(device,':SENSe:FREQuency:STOP?', '%s', '%f');
      % get sweep data - NOTE: The N9320B only utilizes 461 freq. points
      pts = 461;
      out = linspace(f_start, f_stop, pts);
      
   otherwise
      fprintf(2, 'Warning: Unsupported command "%s".\n', cmd);
end