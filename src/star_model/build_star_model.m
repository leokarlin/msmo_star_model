function [ model ] = build_star_model( db, descrs, pars )
%build_star_model.m: a function building the star model object.
% Inputs:
%  Inputs: 
%   db          is the main Star Model database, see get_product_templates_db.m
%   descrs      the set of SIFT descriptors compute for the dataset, see get_db_descrs.m
%   pars        parameters struct (default values are hardcoded below)
% ----------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ----------------------------------------------------------------------------

%% parameters
if ~exist('pars','var') || isempty(pars)
    pars=[];
end

pars=setParamsDefaults(pars,{
    {'num_pca_dims',[]}, ...
    {'force_image_center_cnt',false},...
    {'base_cand_cls_sigma',[]}, ...
    {'ann_split',[]},...
    {'skip_ann',false},...
    {'offsDimsMult',2},...
    {'cntShift',[]}...
});

%% main code
fprintf('building Star Model model object...');

cntX=accumarray(descrs.src(3:4,:)',descrs.src(1,:)');
cntY=accumarray(descrs.src(3:4,:)',descrs.src(2,:)');
nrm=accumarray(descrs.src(3:4,:)',1);
cntX=cntX./(nrm+(nrm==0));
cntY=cntY./(nrm+(nrm==0));

if ~isempty(pars.cntShift)
    cntX=cntX+pars.cntShift(1);
    cntY=cntY+pars.cntShift(2);
end

model.scales=descrs.scales;
model.nPatchesIS=nrm;
model.srcXYI=descrs.src;
model.patchHeight=descrs.patchHeight;
model.pths=db.pths;
model.obj_cntXY=cat(1,permute(cntX,[3 1 2]),permute(cntY,[3 1 2]));
model.steps=descrs.steps;

nImgs=size(model.obj_cntXY,2);
% nScales=size(model.obj_cntXY,3);

offsXY=model.obj_cntXY(:,model.srcXYI(3,:)+nImgs*(model.srcXYI(4,:)-1))-model.srcXYI(1:2,:);
model.obj_cntOffsXY=offsXY;

X=descrs.X;
if ~isempty(pars.num_pca_dims)
    model.pca.m=mean(X,2);
    X=bsxfun(@minus,X,model.pca.m);
    X=X';
    [model.pca.T,X,model.pca.loadings]=princomp(X,'econ');
    model.pca.loadings=model.pca.loadings/sum(model.pca.loadings);
    model.pca.T=inv(model.pca.T);
    model.pca.T=model.pca.T(1:pars.num_pca_dims,:);
    X=X(:,1:pars.num_pca_dims)';
end

model.numPrimaryDims=size(X,1);
if ~pars.skip_ann
    if isempty(pars.ann_split)
        model.ann=vl_kdtreebuild(X,'NumTrees',5);
    else
        assert(sum(pars.ann_split)==1);
        ordX=randperm(size(X,2));
        splitsX=round(cumsum(pars.ann_split)*size(X,2));
        curStart=1;
        for iSp=1:length(splitsX)
            model.ann{iSp,1}=ordX(curStart:splitsX(iSp));
            model.ann{iSp,2}=vl_kdtreebuild(X(:,model.ann{iSp,1}),'NumTrees',5);
            curStart=splitsX(iSp)+1;
        end
    end
end
model.X=X;

model.meta=db.meta;

model.objHeight=size(db.imgs{1},1);
model.objWidth=size(db.imgs{1},2);

for iImg=1:length(db.imgs)
    sz_cur=size(db.imgs{iImg});
    model.allSizesXY(iImg,:)=fliplr(sz_cur(1:2));
end

if ~isempty(pars.base_cand_cls_sigma)
    extraDims=cat(1,bsxfun(@rdivide,offsXY,model.scales(model.srcXYI(4,:))),model.scales(model.srcXYI(4,:)));
    extraDimsMult=pars.offsDimsMult./pars.base_cand_cls_sigma;
    X=[X ; bsxfun(@times,extraDimsMult(:),extraDims)];
    model.X=X;
    model.redet_ann=vl_kdtreebuild(X,'NumTrees',5);
    model.offsDimsMult=extraDimsMult;
    model.can_redetection_enable=true;
end

if isfield(descrs,'imgPyrSizesXY')
    model.imgPyrSizesXY=descrs.imgPyrSizesXY;
    model.descrPyrSizesXY=descrs.descrPyrSizesXY;
end
fprintf('done.\n');

