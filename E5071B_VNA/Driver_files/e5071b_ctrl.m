%  USAGE:
%  %     basic
%  vna0 = e5062a_ctrl('192.168.1.98', 'open'); % open new connection
%  e5062a_ctrl(vna0, 'flush-host-buffers'); % make sure the host buffers are empty (just as a precaution)
%  e5062a_ctrl(vna0, 'reset') % reset the VNA device (should display device ID)
%  e5062a_ctrl(vna0, 'init'); % configure for measurements (HARDCODED; sorry, never had time to make a nice function)
%  %     initialize with stored calibration settings
%  e5062a_ctrl(vna0, 'load-state', 'STATE-NAME.sta');
%  %     frequency setup
%  e5062a_ctrl(vna0, 'set-f-vec', [100e6 : 2e6 : 3000e6]); % set frequency sweep
%  f = e5062a_ctrl(vna0, 'get-f-vec'); % return frequency sweep settings (quick&dirty way to check if the setup is OK)
%  e5062a_ctrl(vna0, 'set-power', -45); % Set power level to -45 dBm
%  %		measure ...
%  s11 = e5062a_ctrl(vna0, 'get', 's11');
%  s21 = e5062a_ctrl(vna0, 'get', 's21');
%  s12 = e5062a_ctrl(vna0, 'get', 's12');
%  s22 = e5062a_ctrl(vna0, 'get', 's22');
%  e5062a_ctrl(vna0, 'avg-on'); % Turn averaging on
%  e5062a_ctrl(vna0, 'avg-off); % Turn averaging off
%  e5062a_ctrl(vna0, 'avg-factor', 16); % Set averaging factor 1-999
%  [default = 16]
%  e5062a_ctrl(vna0, 'avg-clear'); % Clear averaging
%  %		get error logs
%  e5062a_ctrl(vna0, 'error-log')
%  %		close connection
%  e5062a_ctrl(vna0, 'close');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Changelog:
%%%
%%% 2012-nov-1 ::: Stewart Thomas
%%% %%% Added a set-power function. Will check and change the power
%%% attenuator setting and change if required. TODO: It would be
%%% nice if you set a power vector to set the VNA to sweep the
%%% power for a given frequency, however, you might as well set a
%%% power and sweep frequency and get a nice 3D surface anyways.
%%%
%%%
%%% 2012-nov-27 ::: Jordan Besnoff
%%% %%% Added a calibration load function. This allows you to 
%%% recall a stored calibration state if desired. Measurements are
%%% otherwise captured just the same. The VNA is initialized only 
%%% with the necessary data transfer settings, so you will have to 
%%% set the frequency range with the 'set-f-vec' option. Ensure that
%%% the calibration state exists in the D: partition of the VNA's
%%% internal memory.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Application Notes:
%%%
%%% 2012-nov-27 ::: Jordan Besnoff
%%% %%% If taking multiple traces from the VNA, make sure to
%%% place pauses between the 'get' commands, otherwise 
%%% Matlab will throw an error (probably due to a stack problem).
%%% Pauses of 1 second should do the trick.


function out = e5062a_ctrl(device, cmd, in)

out = device;

switch lower(cmd)
   % open, close, reset
   case 'open'
      out = tcpip(device, 5025, 'InputBufferSize', 10^6, 'Timeout', 5);
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

   % initialize settings (quick and dirty for now)
   case 'init'
      % frequency and power
      fprintf(device, ':SENSe1:FREQuency:STARt 800E6');
      fprintf(device, ':SENSe1:FREQuency:STOP 1E9');
      fprintf(device, ':SENSe1:SWEep:POINts 1001');
%       fprintf(device, ':SOUR1:POW 10')
      % sensing and calibration
      fprintf(device, ':SENS1:BAND 1E4'); % IF bandwidth
      fprintf(device, ':SENS1:CORR:CLE'); % clear calibration data
      fprintf(device, ':SENS1:CORR:STAT OFF'); % calibration mode: off
      fprintf(device, ':INIT1:CONT ON'); % continuous mode: on
      % data transfer
      fprintf(device, ':FORM:DATA REAL'); % 64 bit float (IEEE)
      fprintf(device, ':FORM:BORD NORMal'); % MSB first
      fprintf(device, ':CALC1:FORM SCOMplex'); % complex data
      
   % settings for pre-calibration, so cal is not cleared   
    case 'load-state'
      if nargin ~= 3
          fprintf(2,'Warning: Incorrect number of arguments');
          return
      end
      % load state
      fprintf(device, sprintf(':MMEM:LOAD %s', upper(['"',in,'"'])));
      % initialize for data transfer
      fprintf(device, ':INIT1:CONT ON'); % continuous mode: on
      fprintf(device, ':FORM:DATA REAL'); % 64 bit float (IEEE)
      fprintf(device, ':FORM:BORD NORMal'); % MSB first
      fprintf(device, ':CALC1:FORM SCOMplex'); % complex data

   % set frequency range
   case 'set-f-vec'
      if length(in) > 1601
         fprintf(2, 'Warning: 1601 points maximum.\n');
      end
      fprintf(device, sprintf(':SENSe1:FREQuency:STARt %E', in(1)));
      fprintf(device, sprintf(':SENSe1:FREQuency:STOP %E', in(end)));
      fprintf(device, sprintf(':SENSe1:SWEep:POINts %d', length(in)));

   % transfer data from the device
   case 'get'
      % safety-check
      if ~any(strcmpi(in, {'S11','S12','S21','S22'}))
         fprintf(2, 'Warning: Only S11, S12, S21, S22 supported.');
         out = []; return
      end
      % set parameter
      fprintf(device, sprintf(':CALCulate1:PARameter1:DEFine %s', upper(in))); % [TODO] why does't fprintf('%s', in) work?
      % get sweep time
      fprintf(device, ':SENS1:SWE:TIME?'); pause(0.1);
      sweeptime = fscanf(device, '%f');
      % trigger measurement and wait
      fprintf(device, ':INIT1:CONT?'); pause(0.1);
      iscont = fscanf(device, '%f');
      if iscont
      else
          fprintf(device, ':INIT1');
      end
      pause(2*sweeptime);
      % get data
      fprintf(device, ':CALCulate1:DATA:SDATa?'); pause(0.1);
      out = binblockread(device, 'float64');
      out = complex(out(1:2:end-1), out(2:2:end));

   % generate frequency vector from settings
   case 'get-f-vec'
      fprintf(device, ':SENSe1:FREQuency:STARt?');
      sta = fscanf(device, '%f');
      fprintf(device, ':SENSe1:FREQuency:STOP?');
      sto = fscanf(device, '%f');
      fprintf(device, ':SENSe1:SWEep:POINts?');
      pts = fscanf(device, '%f');
      % get sweep data
      out = linspace(sta, sto, pts);

   % read entire error log
   case 'error-log'
      clear('out');
      for i = 1 : 100 % maximum error log length
         fprintf(device, ':SYST:ERR?'); pause(0.1);
         out{i} = strtrim( fgets(device) );
         if strcmpi(out{i}, '+0,"No error"'); break; end
      end
      
   % set device power level (dBm)
  case 'set-power'
    % Determine power attenuator value based on desired power setting
     if in < -30
         powatt = 40;
     elseif in < -20
         powatt = 30;
     elseif in < -10
         powatt = 20;
     elseif in < 0
         powatt = 10;
     elseif in <= 10
         powatt = 0;
     else
         fprintf(2, 'Warning: Invalid power level');
         powatt = 0;
     end
     % Read current power setting and decide if we need to change
     % the attenuator setting
     fprintf(device, 'SOUR1:POW:ATT?');
     current_att = strtrim( fscanf( device ) );
     if powatt ~= str2num( current_att )
         % Attenuator settings are different, need to change
         fprintf(device, sprintf('SOUR1:POW:ATT %g', powatt) );
     end
     % Now, set to the desired power level
     fprintf(device, sprintf('SOUR1:POW %g', in) );
     % And return it
     fprintf(device, 'SOUR1:POW?');
     out = fscanf( device, '%f' );
     if out ~= in
         warning( ['Could not set output power. Current setting is: ' ...
                   '%.1f dBm'], out);
     end
     
    %Turn averaging on
    case 'avg-on'
        fprintf(device, 'SENSe1:AVERage ON');
        
    %Turn averaging off
    case 'avg-off'
        fprintf(device, 'SENSe1:AVERage OFF');
        
    %Set averaging factor (1-999)
    case 'avg-factor'
        %Check factor range and verify an integer
        if mod(in,1) ~= 0
            warning('Averaging factor must be an integer between 1 and 999')
            return
        end
        
        if in < 1 || in > 999
            warning('Averaging factor must be an integer between 1 and 999')
            return
        end
        
        %Set factor
        fprintf(device, sprintf('SENSe1:AVERage:COUNt %f',in));
        
    %Clear averaging
    case 'avg-clear'
        fprintf(device, 'SENSe1:AVERage:CLEar');

   otherwise
      fprintf(2, 'Warning: Unsupported command "%s".\n', cmd);
end