function [ hashObj ] = trainHashNNv2( X, params )
%TRAINHASHNN trains the "distnce preserving" hashing function for the given data
% X is d x N

%% params
if ~exist('params','var') || isempty(params)
    params=[];
end

params=setParamsDefaults(params,{
    {'hashType','SH'},...
    {'nbits',16},...
    {'maxK',50},...
    {'hashIndex',[]}...
});

%% allow to use a subset
if ~isempty(params.hashIndex)
    X=X(:,params.hashIndex);
end

%% train the hash function
clear hashObj;
switch params.hashType
    case 'SH'
        hashObj.SHparam.nbits=params.nbits;
        hashObj.SHparam=trainSH(X',hashObj.SHparam);
    otherwise
        error('Unsupported hash type: %s',params.hashType);
end

%% build the LUT
hashObj.N_X=compressSHv2_mex(X',hashObj.SHparam);
hashObj.SHparam.maxK=params.maxK;
hashObj.hashLUT=hashLUTv2_build_mex(hashObj.N_X,hashObj.SHparam.nbits,hashObj.SHparam.maxK);
hashObj.hashIndex=params.hashIndex;

%% add the interface functions
hashObj.close=@()(close_LUT());
hashObj.reopen=@()(open_LUT());
hashObj.query=@(X,Y,k)(query(X,Y,k));

%% inner functions
    function [ idx, dst ] = query( X, Y, k )
        assert(k<=hashObj.SHparam.maxK,'maximum number of neighbors breached');
        N_Y=compressSHv2_mex(Y',hashObj.SHparam);
        idx=hashLUTv2_query_mex(hashObj.hashLUT,N_Y,k,hashObj.SHparam.nbits);
        if ~isempty(hashObj.hashIndex)
            idx(idx~=0)=hashObj.hashIndex(idx(idx~=0));
        end
        dst=L2_dist2NNv2_mex(X,Y,idx);
        dst(idx==0)=inf;
        idx(idx==0)=1;
    end

    function [] = close_LUT()
        hashLUTv2_clear_mex(hashObj.N_X,hashObj.hashLUT);
        hashObj.hashLUT=[];
    end

    function [] = open_LUT()
        assert(isempty(hashObj.hashLUT),'can only re-open previously closed object');
        hashObj.hashLUT=hashLUTv2_build_mex(hashObj.N_X,hashObj.SHparam.nbits,hashObj.SHparam.maxK);
    end
end

