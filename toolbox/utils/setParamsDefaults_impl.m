function [ params ] = setParamsDefaults_impl( params, defaults )
%sets default values to unset fields of the params structure
%   params - a struct, may be empty
%   defaults - a cell array of pairs: {'field name', value}

%% configure
if ~isstruct(defaults)
    num_defaults=length(defaults);

    if (num_defaults>0) && (isempty(params) || ~isstruct(params))
        clear params;
    end

    for i=1:num_defaults
        if iscell(defaults{i}) && length(defaults{i})>=2
            field_name=defaults{i}{1};
            field_val=defaults{i}{2};

            if ischar(field_name)
                if ~exist('params','var') ||...
                        ~isfield(params,field_name) ||...
                        isempty(eval(sprintf('params.%s',field_name)))
                    eval(sprintf('params.%s=field_val;',field_name));
                end
            end
        end
    end
else
    def_fields=fieldnames(defaults);
    num_defaults=length(def_fields);
    
    if (num_defaults>0) && (isempty(params) || ~isstruct(params))
        clear params;
    end

    for i=1:num_defaults
        field_name=def_fields{i};
        field_val=getfield(defaults,def_fields{i});

        if ischar(field_name)
            if ~exist('params','var') ||...
                    ~isfield(params,field_name) ||...
                    isempty(eval(sprintf('params.%s',field_name)))
                eval(sprintf('params.%s=field_val;',field_name));
            end
        end
    end
end