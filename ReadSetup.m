function Params = ReadSetup(LogLanguage)
%
%    ,     'Setup'  
%  'm'.      ( 
% 'Params.').  Setup       
%  m-.     
% '% End of Params' (, , ,    
%  '% End of Params'   ,    ).
%        
% ,   '% End of Params'    
% .    .   
%       .  
%        ,    
%     , ..    .
% :        ,
%   Setup    ,     , 
%       .
%
%  :
%   Params - cell-    , 
%        () Setup.

    %  
        Params = cell(0);

    %     Params      
        FieldNames = { ...
            'Source', ...
            'BBFrame', ...
            'Encoder', ...
            'Interleaver', ...
            'Mapper', ...
            'Sig', ...
            'PLScrambler', ...
            'RRCFilter', ...
            'Channel', ...
            'BER', ...
            'Common' ...
        };
   
    %  
        %    
            FileNames = cell(0);
        %    
            Listing = dir;
        %    ,   
            for k = 1:length(Listing)
                %   
                if ~Listing(k).isdir
                    % ,      Setup  
                    %  'm'
                    if length(Listing(k).name) >= length('Setup.m')
                        if strcmp(Listing(k).name(1:length('Setup')), ...
                                'Setup') && strcmp(Listing(k).name( ...
                                end-1:end), '.m')
                            FileNames{end+1} = Listing(k).name; %#ok<AGROW>
                        end
                    end
                end
            end

    %    
        for k = 1:length(FileNames)
            %     
                NumParams = length(Params);

            %     
                try
                    fid = fopen(FileNames{k});
                catch
                    if strcmp(LogLanguage, 'Russian')
                        error(['     ', ...
                            '%s!\n'], FileNames{k});
                    else
                        error('Failed to open setup file %s!\n', ...
                            FileNames{k});
                    end
                end
                
            %    
                BufParams = [];
                
            %     
                tline = fgetl(fid);
                isFindEndOfParams = false; %    
                    % ,   
                while ischar(tline)
                    %  'BufParams.'    
                    % 
                        for n = 1:length(FieldNames)
                            OldStr = [FieldNames{n}, '.'];
                            NewStr = ['BufParams.', OldStr];
                            tline = strrep(tline, OldStr, NewStr);
                        end

                    %   
                        try
                            eval(tline);
                        catch
                            if strcmp(LogLanguage, 'Russian')
                                error(['   ''%s'' ', ...
                                    '  %s!\n'], tline, FileNames{k});
                            else
                                error(['Failed to evaluate ''%s'' in ', ...
                                    'file %s!\n'], tline, FileNames{k});
                            end
                        end

                    % ,       
                    %  
                        isFindEndOfParams = contains(tline, ...
                            '% End of Params');
                    
                    %        
                    %     ,   
                    %        
                    %     
                        if isFindEndOfParams
                            if ~isempty(BufParams)
                                Params{end+1} = BufParams; %#ok<AGROW>
                                BufParams = [];
                            end
                        end
                    
                    %    
                        tline = fgetl(fid);
                end

            %   ,      ,
            %         
                if ~isFindEndOfParams
                    if ~isempty(BufParams)
                        Params{end+1} = BufParams; %#ok<AGROW>
                    end
                end

            %  
                fclose(fid);

            %    
                if strcmp(LogLanguage, 'Russian')
                    fprintf(['%s   %s  %d  ', ...
                        '.\n'], datestr(now), FileNames{k}, ...
                        length(Params) - NumParams);
                else
                    fprintf(['%s %d parameter sets are parsed from ', ...
                        'file %s.\n'], datestr(now), length(Params) - ...
                        NumParams, FileNames{k});
                end
                fprintf('\n');
        end
        
    %        ,   
    %       
        if isempty(Params)
            Params = cell(1);
            %    
                if strcmp(LogLanguage, 'Russian')
                    fprintf(['%s      , ', ...
                        '      ', ...
                        '  .\n'], datestr(now));
                else
                    fprintf(['%s No parameters were found thus one ', ...
                        'calculation with default parameters will be ', ...
                        'performed.\n'], datestr(now));
                end                    
                fprintf('\n');
        end
