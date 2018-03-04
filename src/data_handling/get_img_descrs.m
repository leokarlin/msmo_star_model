function [ descrs, pos_xy ] = get_img_descrs( img, patchHeight, step, rootSIFT, useOpenCV )
%GET_IMG_DESCRS computes dense sift for a given image

if ~exist('rootSIFT','var') || isempty(rootSIFT)
    rootSIFT=false;
end

if ~exist('useOpenCV','var') || isempty(useOpenCV)
    useOpenCV=false;
end

if ~exist('step','var') || isempty(step)
    step=1;
end

if ~exist('patchHeight','var') || isempty(patchHeight)
    patchHeight=24;
else
    if mod(patchHeight,4)~=0
        error('Cannot use %d patch size, not divisible by 4!');
    end
end

binSz=patchHeight/4;

if size(img,3)==3
    img=single(im2double(rgb2gray(img)));
else
    img=single(im2double(img));
end

if ~useOpenCV
    [frms,descrs]=vl_dsift(img,'Size',binSz,'FloatDescriptors','Norm','Step',step,'Fast');
else
    [x,y]=meshgrid(1:step:(size(img,2)-patchHeight+1),1:step:(size(img,1)-patchHeight+1));
    frms=[x(:) y(:)]';
    descrs=computeSURFdescs_mex(im2uint8(img),int32(frms),single(patchHeight));
    frms=frms+patchHeight/2;
end

if rootSIFT
    nrm=sum(abs(descrs));
    descrs=bsxfun(@rdivide,descrs,nrm+(nrm==0));
    descrs=sqrt(descrs);
else
    nrm=sqrt(sum(descrs.^2));
    descrs=bsxfun(@rdivide,descrs,nrm+(nrm==0));
end
pos_xy=frms(1:2,:);

end

