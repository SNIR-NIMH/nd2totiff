classdef ProgressBar < matlab.System
%PROGRESSBAR A class to provide a convenient and useful progress bar
% -------------------------------------------------------------------------
% This class mimics the design and some features of the TQDM
% (https://github.com/tqdm/tqdm) progress bar in python. All optional
% functionalities are set via name-value pairs in the constructor after the
% argument of the total numbers of iterations used in the progress (which
% can also be empty if unknown or even neglected if no name-value pairs are
% passed). The central class' method is 'step()' to increment the
% progress state of the object.
%
% Usage:  pbar = ProgressBar()
%         pbar = ProgressBar(total)
%         pbar = ProgressBar(total, Name, Value)
%
% where 'total' is the total number of iterations.
%
%
% ProgressBar Properties:
%   Total - the total number of iterations [default: []]
%   Title - the progress bar's title shown in front [default: 'Processing']
%   Unit - the unit of the update process. Can either be 'Iterations' or
%          'Bytes' [default: 'Iterations']
%   UpdateRate - the progress bar's update rate in Hz. Defines the printing
%                update interval [default: 5 Hz]
%
%
% ProgressBar Methods:
%   ProgressBar - class constructor
%   release - clean up and finish the progress bar's internal state
%   printMessage - print some infos during the iterations. Messages get
%                  printed above the bar and the latter shifts one row down
%   setup - not needed in a common application. Tiny helper function when
%           setting up nested loops to print a parent bar before the first
%           update occured. When the inner loop takes long, a nasty white
%           space is shown in place of the parent bar until the first
%           update takes place. This function can be used as a remedy.
%   step - the central update method to increment the internal progress
%          state
%
% Author :  J.-A. Adrian (JA) <jensalrik.adrian AT gmail.com>
% Date   :  17-Jun-2016 16:08:45
%

% History:  v1.0    working ProgressBar with and without knowledge of total
%                   number of iterations, 21-Jun-2016 (JA)
%           v2.0    support for update rate, 21-Jun-2016 (JA)
%           v2.1    colored progress bar, 22-Jun-2016 (JA)
%           v2.2    support custom step size, 22-Jun-2016 (JA)
%           v2.3    nested bars, 22-Jun-2016 (JA)
%           v2.4    printMessage() and info when iteration was not
%                   successful, 23-Jun-2016 (JA)
%           v2.5    support 'Bytes' as unit, 23-Jun-2016 (JA)
%           v2.5.1  bug fixing, 23-Jun-2016 (JA)
%           v2.6    timer stops when no updates arrive, 23-Jun-2016 (JA)
%           v2.7    introduce progress loop via wrapper class,
%                   23- Jun-2016 (JA)
%           v2.7.1  bug fixing, 25-Jun-2016 (JA)
%           v2.8    support ASCII symbols, 25-Jun-2016 (JA)
%           v2.8.1  consider isdeployed
%           v2.8.2  fix a bug concerning bar updating, 27-Jun-2016 (JA)
%           v2.8.3  update documentation and demos, 27-Jun-2016 (JA)
%           v2.8.4  update known issues
%           v2.8.5  bug fixes
%           v2.9    support of parallel parfor loops, 28-Jun-2016 (JA)
%           v2.9.1  bug fixing (deploy mode) and optimization,
%                   28-Jun-2016 (JA)
%           v2.9.2  fix bug in updateParallel(), 29-Jun-2016 (JA)
%           v2.9.3  fix bug where updateParallel() doesn't return the
%                   correct write-directory, 30-June-2016 (JA)
%           v2.9.4  the directory of the worker aux. files can now be
%                   specified, 03-Jul-2016 (JA)
%           v2.9.5  show s/it if it/s < 1 for easier overview,
%                   10-Aug-2016 (JA)
%           v2.9.6  default update rate is now 5 Hz, 10-Aug-2016 (JA)
%           v2.9.7  remove commas after if, for, etc., improve stability a
%                   bit, 11-Oct-2016 (JA)
%           v3.0.0  - refactor the class to be a MATLAB System Object
%                   - support a title banner if title longer than
%                     MaxTitleLength
%                   02-May-2017 (JA)
%           v3.1.0  timing initialization is now done in the object's setup phase. Previously, this
%                   was done in the constructor so time book keeping could have been awkward if
%                   step() methods wouldn't have been called immediately. Some private properties
%                   have been renamed. 03-11-2019 (JA)
%


properties (Constant)
   % Tag every timer with this to find it properly
    TIMER_TAG_NAME = 'ProgressBar';
    VERSION = '3.1.0';
end

properties (Nontunable)
    % Total number of iterations to compute progress and ETA
    Total;
    
    % Titel of the progress bar if desired. Shown in front of the bar
    Title = 'Processing';
    
    % The visual printing rate in Hz. Default is 5 Hz
    UpdateRate = 5;
    
    % The unit of each update. Can be either 'Iterations' or 'Bytes'.
    % Default is 'Iterations'.
    Unit = 'Iterations';
    
    % Directory in which the worker binary files are being saved when in
    % parallel mode.
    WorkerDirectory = tempdir;
end

properties (Logical, Nontunable)
    UseUnicode = true;
    IsParallel = false;
end

properties (Access = private)
    Bar = '';
    IterationCounter = 0;
    
    NumWrittenCharacters = 0;
    FractionMainBlock;
    FractionSubBlock;
    
    HasTotalIterations = false;
    HasBeenUpdated = false;
    HasFiniteUpdateRate = true;
    HasItPerSecBelow1 = false;
    
    BlockCharacters = getUnicodeSubBlocks();
    
    IsTimerRunning = false;
    
    TicObject;
    TimerObject;
    
    MaxBarWidth = 75;
    
    CurrentTitleState = '';
end

properties (Constant, Access = private)
    % The number of sub blocks in one main block of width of a character.
    % HTML 'left blocks' go in eigths -> 8 sub blocks in one main block
    NumSubBlocks = 8;
    
    % The number of characters the title string should shift each cycle
    NumCharactersShift = 3;
    
    % The maximum length of the title string without banner cycling
    MaxTitleLength = 20;
end

properties (Access = private, Dependent)
    IsThisBarNested;
end




methods
    % Class Constructor
    function [obj] = ProgressBar(total, varargin)
        if nargin
            obj.Total = total;
            
            obj.setProperties(nargin-1, varargin{:});
        end
        
        if ~isempty(obj.Total)
            obj.HasTotalIterations = true;
        end
        if isinf(obj.UpdateRate)
            obj.HasFiniteUpdateRate = false;
        end
        
        % check if prog. bar runs in deployed mode and if so, switch to
        % ASCII symbols and a smaller bar width
        if isdeployed
%             obj.UseUnicode = false;
            obj.MaxBarWidth = 100;
        end
        
        % setup ASCII symbols if desired
        if ~obj.UseUnicode
            obj.BlockCharacters = getAsciiSubBlocks();
        end 
    end
    
    function [] = printMessage(obj, message, shouldPrintNextProgBar)
    %PRINTMESSAGE class method to print a message while prog bar running
    %----------------------------------------------------------------------
    % This method lets the user print a message during the processing. A
    % normal fprintf() or disp() would break the bar so this method can be
    % used to print information about iterations or debug infos.
    %
    % Usage: obj.printMessage(obj, message)
    %        obj.printMessage(obj, message, shouldPrintNextProgBar)
    %
    % Input: ---------
    %       message - the message that should be printed to screen
    %       shouldPrintNextProgBar - Boolean to define wether to
    %                                immidiately print another prog. bar
    %                                after print the success message. Can
    %                                be usefule when every iteration takes
    %                                a long time and a white space appears
    %                                where the progress bar used to be.
    %                                [default: shouldPrintNextProgBar = false]
    %
        
        % input parsing and validation
        narginchk(2, 3);
        
        if nargin < 3 || isempty(shouldPrintNextProgBar)
            shouldPrintNextProgBar = false;
        end
        validateattributes(shouldPrintNextProgBar, ...
            {'logical', 'numeric'}, ...
            {'scalar', 'binary', 'nonempty', 'nonnan'} ...
            );
        
        % remove the current prog bar
        fprintf(1, backspace(obj.NumWrittenCharacters));
        
        % print the message and break the line
        fprintf(1, '\t');
        fprintf(1, message);
        fprintf(1, '\n');
        
        % reset the number of written characters
        obj.NumWrittenCharacters = 0;
        
        % if the next prog bar should be printed immideately do this
        if shouldPrintNextProgBar
            obj.printProgressBar();
        end
    end
    
    function [yesNo] = get.IsThisBarNested(obj)
        % If there are more than one timer object with our tag, the current
        % bar must be nested
        yesNo = length(obj.getTimerList()) > 1;
    end
end


methods (Access = protected)
    function [] = validatePropertiesImpl(obj)
        valFunStrings = @(in) validateattributes(in, {'char'}, {'nonempty'});
        valFunNumeric = @(in) validateattributes(in, ...
            {'numeric'}, ...
            {'scalar', 'positive', 'real', 'nonempty', 'nonnan'} ...
            );
        valFunBoolean = @(in) validateattributes(in, ...
            {'logical', 'numeric'}, ...
            {'scalar', 'binary', 'nonnan', 'nonempty'} ...
            );
        
        assert(...
            checkInputOfTotal(obj.Total) ...
            );
        
        assert(...
            any(strcmpi(obj.Unit, {'Iterations', 'Bytes'})) ...
            );
        
        valFunStrings(obj.Title);
        valFunStrings(obj.WorkerDirectory);
        valFunNumeric(obj.UpdateRate);
        valFunBoolean(obj.UseUnicode);
        valFunBoolean(obj.IsParallel);
    end
    
    function [] = setupImpl(obj)
        % get a new tic object
        obj.TicObject = tic;
        
        % add a new timer object with the standard tag name and hide it
        obj.TimerObject = timer(...
            'Tag', obj.TIMER_TAG_NAME, ...
            'ObjectVisibility', 'off' ...
            );
        
        % if the bar should not be printed in every iteration setup the
        % timer to the desired update rate
        if obj.HasFiniteUpdateRate
            obj.setupTimer();
        end
        
        % if 'Total' is known setup the bar correspondingly and compute
        % some constant values
        if obj.HasTotalIterations
            % initialize the progress bar and pre-compute some measures
            obj.setupBar();
            obj.computeBlockFractions();
        end
        
        obj.CurrentTitleState = obj.Title;
        if length(obj.Title) > obj.MaxTitleLength
            obj.CurrentTitleState = [obj.CurrentTitleState, ' -- '];
        end
        
        % if the bar is used in a parallel setup start the timer right now
        if obj.IsParallel
            obj.startTimer();
        end
        
        % if this is a nested bar hit return
        if obj.IsThisBarNested
            fprintf(1, '\n');
        end
        obj.printProgressBar();
    end
    
    function [] = stepImpl(obj, stepSize, wasSuccessful, shouldPrintNextProgBar)
    %STEPIMPL class method to increment the object's progress state
    %----------------------------------------------------------------------
    % This method is the central update function in the loop to indicate
    % the increment of the progress. Pass empty arrays for each input
    % argument if default is desired.
    %
    % Usage: obj.step(stepSize, wasSuccessful, shouldPrintNextProgBar)
    %
    % Input: ---------
    %       stepSize - the size of the progress step when the method is
    %                  called. This can be used to pass the number of
    %                  processed bytes when using 'Bytes' as units.
    %                  [default: stepSize = 1]
    %       wasSuccessful - Boolean to provide information about the
    %                       success of an individual iteration. If you pass
    %                       a 'false' a message will be printed stating the
    %                       current iteration was not successful.
    %                       [default: wasSuccessful = true]
    %       shouldPrintNextProgBar - Boolean to define wether to
    %                                immidiately print another prog. bar
    %                                after print the success message. Can
    %                                be useful when every iteration takes
    %                                a long time and a white space appears
    %                                where the progress bar used to be.
    %                                [default: shouldPrintNextProgBar = false]
    %
        
        % input parsing and validating
        if isempty(shouldPrintNextProgBar)
            shouldPrintNextProgBar = false;
        end
        if isempty(wasSuccessful)
            wasSuccessful = true;
        end
        if isempty(stepSize)
            stepSize = 1;
        end
        
        validateattributes(stepSize, ...
            {'numeric'}, ...
            {'scalar', 'positive', 'real', 'nonnan', 'finite', 'nonempty'} ...
            );
        validateattributes(wasSuccessful, ...
            {'logical', 'numeric'}, ...
            {'scalar', 'binary', 'nonnan', 'nonempty'} ...
            );
        validateattributes(shouldPrintNextProgBar, ...
            {'logical', 'numeric'}, ...
            {'scalar', 'binary', 'nonnan', 'nonempty'} ...
            );
        
        
        % increment the iteration counter
        obj.incrementIterationCounter(stepSize);
        
        % if the timer was stopped before, because no update was given,
        % start it now again.
        if ~obj.IsTimerRunning && obj.HasFiniteUpdateRate
            obj.startTimer();
        end
        
        % if the iteration was not successful print a message saying so.
        if ~wasSuccessful
            infoMsg = sprintf('Iteration %i was not successful!', ...
                obj.IterationCounter);
            obj.printMessage(infoMsg, shouldPrintNextProgBar);
        end
        
        % when the bar should be updated in every iteration, do this with
        % each time calling update()
        if ~obj.HasFiniteUpdateRate
            obj.printProgressBar();
        end
        
        % stop the timer after the last iteration if an update rate is
        % used. The first condition is needed to prevent the if-statement
        % to fail if obj.Total is empty. This happens when no total number
        % of iterations was passed / is known.
        if         ~isempty(obj.Total) ...
                && obj.IterationCounter == obj.Total ...
                && obj.HasFiniteUpdateRate
            
            obj.stopTimer();
        end
    end
    
    function [] = releaseImpl(obj)
        % stop the timer
        if obj.IsTimerRunning
            obj.stopTimer();
        end
        
        if obj.IsThisBarNested
            % when this prog bar was nested, remove it from the command
            % line and get back to the end of the parent bar.
            % +1 due to the line break
            fprintf(1, backspace(obj.NumWrittenCharacters + 1));
        elseif obj.IterationCounter && ~obj.IsThisBarNested
            % when a non-nested progress bar has been plotted, hit return
            fprintf(1, '\n');
        end
        
        % delete the timer object
        delete(obj.TimerObject);
        
        % if used in parallel processing delete all aux. files and clear
        % the persistent variables inside of updateParallel()
        if obj.IsParallel
            files = findWorkerFiles(obj.WorkerDirectory);
            
            if ~isempty(files)
                delete(files{:});
            end
            
            clear updateParallel;
            
            % rest some time to not flood the screen with the parent bar
            pause(0.1);
        end
    end
end




methods (Access = private)
    function [] = computeBlockFractions(obj)
    % Compute the progress percentage of a single main and a single sub
    % block
        obj.FractionMainBlock = 1 / length(obj.Bar);
        obj.FractionSubBlock = obj.FractionMainBlock / obj.NumSubBlocks;
    end
    
    
    
    function [] = setupBar(obj)
    % Set up the growing bar part of the printed line by computing the
    % width of it
        
        [~, preBarFormat, postBarFormat] = obj.returnFormatString();
        
        % insert worst case inputs to get (almost) maximum length of bar
        preBar = sprintf(...
            preBarFormat, ...
            blanks(min(length(obj.CurrentTitleState), obj.MaxTitleLength)), ...
            100 ...
            );
        postBar = sprintf(...
            postBarFormat, ...
            obj.Total, ...
            obj.Total, ...
            10, 60, 60, 10, 60, 60, 1e2 ...
            );
        
        lenBar = obj.MaxBarWidth - length(preBar) - length(postBar);
        
        obj.Bar = blanks(lenBar);
    end
    
    
    
    
    function [] = printProgressBar(obj)
    % This method removes the old and prints the current bar to the screen
    % and saves the number of written characters for the next iteration
        
        % remove old previous bar
        fprintf(1, backspace(obj.NumWrittenCharacters));
        
        formatString = obj.returnFormatString();
        argumentList = obj.returnArgumentList();
        
        % print new bar
        obj.NumWrittenCharacters = fprintf(1, ...
            formatString, ...
            argumentList{:} ...
            );
    end
    
    
    
    
    
    function [format, preString, postString] = returnFormatString(obj)
    % This method returns the format string for the fprintf() function in
    % printProgressBar()

        % use the correct units
        if strcmp(obj.Unit, 'Bytes')
            if obj.HasItPerSecBelow1
                unitStrings = {'K', 's', 'KB'};
            else
                unitStrings = {'K', 'KB', 's'};
            end
        else
            if obj.HasItPerSecBelow1
                unitStrings = {'', 's', 'it'};
            else
                unitStrings = {'', 'it', 's'};
            end
        end
        
        
        
        % consider a growing bar if the total number of iterations is known
        % and consider a title if one is given.
        if obj.HasTotalIterations
            preString  = '%s:  %03.0f%%  ';
            
            centerString = '|%s|';
            
            postString = ...
                [' %i', unitStrings{1}, '/%i', unitStrings{1}, ...
                ' [%02.0f:%02.0f:%02.0f<%02.0f:%02.0f:%02.0f, %.2f ', ...
                unitStrings{2}, '/', unitStrings{3}, ']'];
            
            format = [preString, centerString, postString];
        else
            preString  = '';
            postString = '';
            
            format = ['%s:  %i', unitStrings{2}, ...
                ' [%02.0f:%02.0f:%02.0f, %.2f ', unitStrings{2}, '/', ...
                unitStrings{3}, ']'];
        end
    end

    
    
    
    function [argList] = returnArgumentList(obj)
    % This method returns the argument list as a cell array for the
    % fprintf() function in printProgressBar()
        
        % elapsed time (ET)
        thisTimeSec = toc(obj.TicObject);
        etHoursMinsSecs = convertTime(thisTimeSec);

        % mean iterations per second counted from the start
        iterationsPerSecond = obj.IterationCounter / thisTimeSec;
        
        if iterationsPerSecond < 1
            iterationsPerSecond = 1 / iterationsPerSecond;
            obj.HasItPerSecBelow1 = true;
        else
            obj.HasItPerSecBelow1 = false;
        end
        
        
        % consider the correct units
        scaledIteration = obj.IterationCounter;
        scaledTotal     = obj.Total;
        if strcmp(obj.Unit, 'Bytes')
            % let's show KB
            scaledIteration     = round(scaledIteration / 1000);
            scaledTotal         = round(scaledTotal / 1000);
            iterationsPerSecond = iterationsPerSecond / 1000;
        end
        
        if obj.HasTotalIterations
            % 1 : Title
            % 2 : progress percent
            % 3 : progBar string
            % 4 : iterationCounter
            % 5 : Total
            % 6 : ET.hours
            % 7 : ET.minutes
            % 8 : ET.seconds
            % 9 : ETA.hours
            % 10: ETA.minutes
            % 11: ETA.seconds
            % 12: it/s
            
            % estimated time of arrival (ETA)
            [etaHoursMinsSecs] = obj.estimateETA(thisTimeSec);
            
            if obj.IterationCounter
                % usual case -> the iteration counter is > 0
                barString = obj.getCurrentBar;
            else
                % if startMethod() calls this method return the empty bar
                barString = obj.Bar;
            end
            
            argList = {
                obj.CurrentTitleState(...
                    1:min(length(obj.Title), obj.MaxTitleLength) ...
                    ), ...
                floor(obj.IterationCounter / obj.Total * 100), ...
                barString, ...
                scaledIteration, ...
                scaledTotal, ...
                etHoursMinsSecs(1), ...
                etHoursMinsSecs(2), ...
                etHoursMinsSecs(3), ...
                etaHoursMinsSecs(1), ...
                etaHoursMinsSecs(2), ...
                etaHoursMinsSecs(3), ...
                iterationsPerSecond ...
                };
        else
            % 1: Title
            % 2: iterationCounter
            % 3: ET.hours
            % 4: ET.minutes
            % 5: ET.seconds
            % 6: it/s
            
            argList = {
                obj.CurrentTitleState(...
                    1:min(length(obj.Title), obj.MaxTitleLength) ...
                    ), ..., ...
                scaledIteration, ...
                etHoursMinsSecs(1), ...
                etHoursMinsSecs(2), ...
                etHoursMinsSecs(3), ...
                iterationsPerSecond ...
                };
        end
        
        % cycle the bar's title
        obj.updateCurrentTitle();
    end
    
    
    
    
    function [barString] = getCurrentBar(obj)
    % This method constructs the growing bar part of the printed line by
    % indexing the correct part of the blank bar and getting either a
    % Unicode or ASCII symbol.
        
        % set up the bar and the current progress as a ratio
        lenBar = length(obj.Bar);
        currProgress = obj.IterationCounter / obj.Total;
        
        % index of the current main block
        thisMainBlock = min(ceil(currProgress / obj.FractionMainBlock), lenBar);
        
        % index of the current sub block
        continuousBlockIndex = ceil(currProgress / obj.FractionSubBlock);
        thisSubBlock = mod(continuousBlockIndex - 1, obj.NumSubBlocks) + 1;
        
        % fix for non-full last blocks when steps are large: make them full
        obj.Bar(1:max(thisMainBlock-1, 0)) = ...
            repmat(obj.BlockCharacters(end), 1, thisMainBlock - 1);
        
        % return a full bar in the last iteration or update the current
        % main block
        if obj.IterationCounter == obj.Total
            obj.Bar = repmat(obj.BlockCharacters(end), 1, lenBar);
        else
            obj.Bar(thisMainBlock) = obj.BlockCharacters(thisSubBlock);
        end
        
        barString = obj.Bar;
    end
    
    
    
    
    function [etaHoursMinsSecs] = estimateETA(obj, elapsedTime)
    % This method estimates linearly the remaining time
        
        % the current progress as ratio
        progress = obj.IterationCounter / obj.Total;
        
        % the remaining seconds
        remainingSeconds = elapsedTime * ((1 / progress) - 1);
        
        % convert seconds to hours:mins:seconds
        etaHoursMinsSecs = convertTime(remainingSeconds);
    end
    
    
    
    
    function [] = setupTimer(obj)
    % This method initializes the timer object if an upate rate is used
        
        obj.TimerObject.BusyMode = 'drop';
        obj.TimerObject.ExecutionMode = 'fixedSpacing';
        
        if ~obj.IsParallel
            obj.TimerObject.TimerFcn = @(~, ~) obj.timerCallback();
            obj.TimerObject.StopFcn  = @(~, ~) obj.timerCallback();
        else
            obj.TimerObject.TimerFcn = @(~, ~) obj.timerCallbackParallel();
            obj.TimerObject.StopFcn  = @(~, ~) obj.timerCallbackParallel();
        end
        updatePeriod = round(1 / obj.UpdateRate * 1000) / 1000;
        obj.TimerObject.Period = updatePeriod;
    end
    
    
    
    function [] = timerCallback(obj)
    % This method is the timer callback. If an update came in between the
    % last printing and now print a new prog bar, else stop the timer and
    % wait.
    if obj.HasBeenUpdated
        obj.printProgressBar();
    else
        obj.stopTimer();
    end
    
    obj.HasBeenUpdated = false;
    end
    
    
    
    
    function [] = timerCallbackParallel(obj)
        % find the aux. worker files
        [files, numFiles] = findWorkerFiles(obj.WorkerDirectory);
        
        % if none have been written yet just print a progressbar and return
        if ~numFiles
            obj.printProgressBar();
            
            return;
        end
        
        % read the status in every file
        results = zeros(numFiles, 1);
        for iFile = 1:numFiles
            fid = fopen(files{iFile}, 'rb');
            
            if fid > 0
                results(iFile) = fread(fid, 1, 'uint64');
                fclose(fid);
            end
        end
        
        % the sum of all files should be the current iteration
        obj.IterationCounter = sum(results);
        
        % print the progress bar
        obj.printProgressBar();
        
        % if total is known and we are at the end stop the timer
        if ~isempty(obj.Total) && obj.IterationCounter == obj.Total
            obj.stopTimer();
        end
end
    
    
    
    
    function [] = startTimer(obj)
    % This method starts the timer object and updates the status bool
    
        start(obj.TimerObject);
        obj.IsTimerRunning = true;
    end
    
    
    
    
    function [] = stopTimer(obj)
    % This method stops the timer object and updates the status bool
        
        stop(obj.TimerObject);
        obj.IsTimerRunning = false;
    end
    
    
    
    
    function [] = incrementIterationCounter(obj, stepSize)
    % This method increments the iteration counter and updates the status
    % bool
        
        obj.IterationCounter = obj.IterationCounter + stepSize;
        
        obj.HasBeenUpdated = true;
    end
    
    
    
    
    function [list] = getTimerList(obj)
    % This function returns the list of all hidden timers which are tagged
    % with our default tag
        
        list = timerfindall('Tag', obj.TIMER_TAG_NAME);
    end
    
    
    function [] = updateCurrentTitle(obj)
        strTitle = obj.CurrentTitleState;
        
        if length(strTitle) > obj.MaxTitleLength
            strTitle = circshift(strTitle, -obj.NumCharactersShift);
            
            obj.CurrentTitleState = strTitle;
        end
    end
end

methods (Static)
    function deleteAllTimers()
        delete(timerfindall('Tag', ProgressBar.TIMER_TAG_NAME));
    end
end

end



function [blocks] = getUnicodeSubBlocks()
% This function returns the HTML 'left blocks' to construct the growing
% bar. The HTML 'left blocks' range from 1 to 8 excluding the 'space'.

blocks = [
    char(9615);
    char(9614);
    char(9613);
    char(9612);
    char(9611);
    char(9610);
    char(9609);
    char(9608);
    ];
end

function [blocks] = getAsciiSubBlocks()
% This function returns the ASCII number signs (hashes) to construct the
% growing bar. The HTML 'left blocks' range from 1 to 8 excluding the
% 'space'.

blocks = repmat('#', 1, 8);
end


function [str] = backspace(numChars)
% This function returns the desired numbers of backspaces to delete
% characters from the current line

str = repmat(sprintf('\b'), 1, numChars);
end


function [hoursMinsSecs] = convertTime(secondsIn)
% This fast implementation to convert seconds to hours:mins:seconds using
% mod() stems from http://stackoverflow.com/a/21233409

hoursMinsSecs = floor(mod(secondsIn, [0, 3600, 60]) ./ [3600, 60, 1]);
end


function [yesNo] = checkInputOfTotal(total)
% This function is the input checker of the main constructor argument
% 'total'. It is ok if it's empty but if not it must obey
% validateattributes.

isTotalEmpty = isempty(total);

if isTotalEmpty
    yesNo = isTotalEmpty;
    return;
else
    yesNo = ~isTotalEmpty;
    validateattributes(total, ...
        {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'real', 'nonnan', 'finite'} ...
        );
end
end

function [files, numFiles] = findWorkerFiles(workerDir)
% This function returns file names and the number of files that were
% written by the updateParallel() function if the prog. bar is used in a
% parallel setup.
%
% Input: workerDir - directory where the aux. files of the worker are saved
%

[pattern] = updateParallel();

files = dir(fullfile(workerDir, pattern));
files = {files.name};

files = cellfun(...
    @(filename) fullfile(workerDir, filename), ...
    files, ...
    'uni', false ...
    );
numFiles = length(files);
end

