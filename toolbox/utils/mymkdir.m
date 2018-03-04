function [ pth ] = mymkdir( pth, varargin )
%MYMKDIR creates a directory if not exists

if ~isempty(varargin)
    for iV=1:length(varargin)
        pth=fullfile(pth,varargin{iV});
    end
end

if ~exist(pth,'dir')
    mkdir(pth);
end

end

