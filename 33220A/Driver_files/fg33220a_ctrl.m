%  USAGE:
%  %     basic
%  fg0 = fg33220a_ctrl('192.168.1.92', 'open'); % open new connection
%  fg33220a_ctrl(fg0, 'flush-host-buffers'); % make sure the host buffers are empty (just as a precaution)
%  fg33220a_ctrl(fg0, 'reset') % reset the FG device (should display device ID)
%  fg33220a_ctrl(fg0, 'output', 'on/off');  % Turn output on or off
%  fg33220a_ctrl(fg0, 'set-freq', 1);  %set output frequency in Hz
%  fg33220a_ctrl(fg0, 'set-amp', 2);  %set output amplitude in Vpp
%  fg33220a_ctrl(fg0, 'set-offset', 0);  %set DC offset in V

%  fg33220a_ctrl(fg0, 'load-data', waveform);  %load arbitrary waveform
%  into device, "waveform" is the data as a vector

%  e5062a_ctrl(vna0, 'init'); % configure for measurements (HARDCODED; sorry, never had time to make a nice function)

%  %		measure ...
%  s11 = e5062a_ctrl(vna0, 'get', 's11');
%  s21 = e5062a_ctrl(vna0, 'get', 's21');
%  s12 = e5062a_ctrl(vna0, 'get', 's12');
%  s22 = e5062a_ctrl(vna0, 'get', 's22');
%  %		get error logs
%  e5062a_ctrl(vna0, 'error-log')


%  %		close connection
%  fg33220a_ctrl(fg0, 'close');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Changelog:
%%%



function out = fg33220a_ctrl(device, cmd, in)

out = device;

switch lower(cmd)
   % open, close, reset
   case 'open'
      out = tcpip(device, 5025, 'InputBufferSize', 10^6, 'Timeout', 5, ...
          'OutputBufferSize', 10^6);
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
   
   %toggle output of device on or off   
   case 'output'
       if strcmp(in,'ON')
           fprintf(device,'OUTPut ON');
       elseif strcmp(in,'OFF')
           fprintf(device,'OUTPut OFF');
       else
           fprintf(2,'Invalid parameter \n\n');
       end
       
       
   %set device output frequency in Hz   
   case 'set-freq'
        fprintf(device,sprintf('FREQ %E',in));
        
   %set device output amplitude in Vpp     
   case 'set-amp'
       fprintf(device,sprintf('VOLT %E',in));
       
   %set device DC offset frequency in V    
   case 'set-offset'
       fprintf(device,sprintf('VOLT:OFFS %E',in));
       
   %load waveform
   case 'load-data'
       %place data in correct format
       data_string = [num2str(in(1))];
       for i = 2:length(in)
           data_string = [data_string,',',num2str(in(i))];
       end
%        data_string = num2str(in);
%        data_string = strrep(data_string,'  ',',');
       fprintf(device, sprintf('DATA VOLATILE, %s',data_string));
       fprintf(device,'DATA:COPY wave1, VOLATILE');
       fprintf(device,'FUNCtion:USER wave1');
       fprintf(device,'FUNC USER');
       
   % initialize settings (quick and dirty for now)
   case 'init'
      % frequency and power
      fprintf(device, ':SENSe1:FREQuency:STARt 5E8');
      fprintf(device, ':SENSe1:FREQuency:STOP 15E8');
      fprintf(device, ':SENSe1:SWEep:POINts 1001');
      fprintf(device, ':SOUR1:POW 10')
      % sensing and calibration
      fprintf(device, ':SENS1:BAND 1E4'); % IF bandwidth
      fprintf(device, ':SENS1:CORR:CLE'); % clear calibration data
      fprintf(device, ':SENS1:CORR:STAT OFF'); % calibration mode: off
      fprintf(device, ':INIT1:CONT OFF'); % continuous mode: off
      % data transfer
      fprintf(device, ':FORM:DATA REAL'); % 64 bit float (IEEE)
      fprintf(device, ':FORM:BORD NORMal'); % MSB first
      fprintf(device, ':CALC1:FORM SCOMplex'); % complex data

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

   otherwise
      fprintf(2, 'Warning: Unsupported command "%s".\n', cmd);
end