function [ params ] = setParamsDefaults( params_in, defaults, log_flush_call )
%sets default values to unset fields of the params structure
%   params - a struct, may be empty
%   defaults - a cell array of pairs: {'field name', value}

%% incoming
if ~exist('log_flush_call','var') || isempty(log_flush_call)
    log_flush_call=false;
end

%% global system configuration
global system_config;
global system_config_pth;

%% logging
global config_caller_stack_4logging;
global params_log_file_path;
log_enabled=false;

if ~isempty(system_config_pth)
    if isempty(system_config)
        system_config=parseXML2Tree(system_config_pth);
    end
    
    %% init
    params=[];
    if isfield(system_config.general,'log_enabled') && ~isempty(system_config.general.log_enabled) && logical(system_config.general.log_enabled)
        log_enabled=true;
        curDateStr=date();
        params_log_file_path=fullfile(mymkdir(fullfile(fileparts(system_config_pth),'logs_of_params')),['log_' curDateStr '.xml']);
        logF=fopen(params_log_file_path,'a');
    end
    
    %% calling func specific - precedense 1
    callerStck=dbstack(1);
    if ~isempty(callerStck)
        caller=callerStck(1).name;
        if isfield(system_config,caller)
            params=setParamsDefaults_impl(params,system_config.(caller));
        end
    end
    
    %% logging
    if log_enabled
        if ~isempty(config_caller_stack_4logging)
            maxNIters=min(length(callerStck),length(config_caller_stack_4logging));
            for iC=1:(maxNIters+1)
                if (iC>maxNIters) || (~isequal(config_caller_stack_4logging(length(config_caller_stack_4logging)-iC+1).line,callerStck(length(callerStck)-iC+1).line)) || (~strcmpi(config_caller_stack_4logging(length(config_caller_stack_4logging)-iC+1).name,callerStck(length(callerStck)-iC+1).name))
                    break;
                end
            end
            iEq=iC-1;
            
            %special case
            if (iEq==length(config_caller_stack_4logging)) && (iEq==length(callerStck))
                iEq=iEq-1;
            end
            
            for iC=1:(length(config_caller_stack_4logging)-iEq)
                printNTabs(logF,length(config_caller_stack_4logging)-iC);
                fprintf(logF,'</%s--line--%d>\n',config_caller_stack_4logging(iC).name,config_caller_stack_4logging(iC).line);
            end
        else
            iEq=0;
        end
        if ~log_flush_call
            for iC=(length(callerStck)-iEq):-1:1
                printNTabs(logF,length(callerStck)-iC);
                fprintf(logF,'<%s--line--%d>\n',callerStck(iC).name,callerStck(iC).line);
                try
                    callPth=which(callerStck(iC).name);
                    printNTabs(logF,length(callerStck)-iC+1);
                    fprintf(logF,'<path>%s</path>\n',callPth);
                end
            end
        end
        config_caller_stack_4logging=callerStck;
    end
    
    %% set general params - precedense 2
    params=setParamsDefaults_impl(params,system_config.general);
    
    %% provided - precedense 3
    params=setParamsDefaults_impl(params,params_in);
    
    %% logging
    if log_enabled && (~log_flush_call)
        printNTabs(logF,length(callerStck));
        if ~strcmp(class(params),'function_handle')
            fprintf(logF,'<params>%s</params>\n',struct2str(params));
        else
            fprintf(logF,'<params>%s</params>\n',func2str(params));   
        end
        
        fclose(logF);
    end
else
    params=params_in;
end

%% configure defaults if not overriden
params=setParamsDefaults_impl(params,defaults);

%%%%%% inner functions
    function [] = printNTabs( f, n )
        for iTab=1:n
            fprintf(f,'\t');
        end
    end

end