function [ res ] = vote_ms2( model, img, params, test_descrs, pos_xy )
%VOTE perform the standard star model voting + back-projection

%% params
if ~exist('params','var') || isempty(params)
    params=[];
end

params=setParamsDefaults(params,{
    {'sigma',0.2}, ...
    {'k',25}, ...
    {'test_stride',4}, ...
    {'nmsDiam',15}, ...
    {'minMaxFactor',0.1}, ...
    {'minMaxFactorCLS',0.1}, ...
    {'geom_sigma',15}, ...
    {'sigma_factor',1}, ...
    {'scale_sigma',0.1}, ...
    {'initDetThresh',50}, ...
    {'nn_max_num_comp',200},...
    ... scales normalization
    {'scales_nrm_type','rs'},... 'rs', 'area'
    ... speed up
    {'working_height',[]},...
    ... robust stat
    {'rs_nCutOff',5},...
    {'rs_nIters',5},...
    {'rs_subs',1},...
    ... kickStart
    {'do_kickStart',false},...
    {'kickStart_perc',0.1},...
    {'kickStart_mmff',0.5},...
    {'kickStart_nnf',1},...
    {'kickStart_ncf',0.5},...
    {'kickStart_minNumDescrs',20000},...
    {'kickStart_phase',0},...
    ... debug
    {'debugFlag',false} ...
});

%% extract test image descriptors
sz=size(img);

if ~exist('test_descrs','var') || ~exist('pos_xy','var') || isempty(test_descrs) || isempty(pos_xy)
    [test_descrs,pos_xy]=get_img_descrs(img,model.patchHeight,params.test_stride);
    if isfield(model,'pca')
        test_descrs=bsxfun(@minus,test_descrs,model.pca.m);
        test_descrs=model.pca.T*test_descrs;
    end
    
    %% kick-start
    if params.do_kickStart
        %%
        kickStart_params=params;
        kickStart_params.initDetThresh=0;
        kickStart_params.kickStart_phase=1;
        kickStart_params.minMaxFactor=params.minMaxFactor*params.kickStart_mmff;
        kickStart_params.k=ceil(params.k*params.kickStart_nnf);
        kickStart_params.nn_max_num_comp=ceil(params.nn_max_num_comp*params.kickStart_ncf);
        kickStart_params.rs_subs=2;
        
        %call the model with sub-sampled descriptors set
        ks_subs=randperm(size(test_descrs,2));
        ks_subs=ks_subs(1:max(params.kickStart_minNumDescrs,round(length(ks_subs)*params.kickStart_perc)));
        ks_res=vote_ms2(model,img,kickStart_params,test_descrs(:,ks_subs),pos_xy(:,ks_subs));
        
        %build ks_map
        ks_map=false(size(img));
        cands=ks_res.final_cands_xyScrSclCls;
        for iC=1:size(cands,1)
            tlc=max(round(cands(iC,[2 1])-model.objHeight*cands(iC,3)/2-1),1);
            brc=min(round(cands(iC,[2 1])+model.objHeight*cands(iC,3)/2+1),sz(1:2));
            ks_map(tlc(1):brc(1),tlc(2):brc(2))=true;
        end
        ks_valid=ks_map(pos_xy(2,:)+sz(1)*(pos_xy(1,:)-1));
        ks_remaining=ks_valid;
        ks_remaining(ks_subs)=false;
        
        %filter the descriptors
        extra_pos_xy=pos_xy(:,ks_subs(ks_valid(ks_subs)));
        extra_idx=ks_res.idx(:,ks_valid(ks_subs));
        extra_dst=ks_res.dst(:,ks_valid(ks_subs));
        test_descrs=test_descrs(:,ks_remaining);
        pos_xy=[pos_xy(:,ks_remaining) extra_pos_xy];
    end
end

%% nn search
[idx,dst]=vl_kdtreequery(model.ann,model.X,test_descrs,'NUMNEIGHBORS',params.k,'MaxNumComparisons',params.nn_max_num_comp);
dst(isnan(dst))=inf;
dst(idx==0)=inf;
idx(idx==0)=1;

if params.do_kickStart && (params.kickStart_phase==0)
    idx=[idx extra_idx];
    dst=[dst extra_dst];
end

res.idx=idx;
res.dst=dst;

%% speed-up
if ~isempty(params.working_height)
    working_res=min(params.working_height/sz(1),1);
    if params.debugFlag
        img=imresize(img,working_res);
    end
    pos_xy=round(pos_xy*working_res);
    model.objHeight=round(model.objHeight*working_res);
    sz(1:2)=ceil(sz(1:2)*working_res);
    params.geom_sigma=params.geom_sigma*working_res;
end

%% compute probs
probs=exp(-0.5*dst/params.sigma^2);
nrm=sum(probs);
probs=bsxfun(@rdivide,probs,nrm+(nrm==0));

%% compute voting pos
p=permute(pos_xy,[3 2 1]);
o=permute(reshape(model.obj_cntOffsXY(:,idx(:)),[2 size(idx)]),[2 3 1]);
if ~isempty(params.working_height)
    o=o*working_res;
end
vPos=round(bsxfun(@plus,o,p));
valid=all(vPos>0,3) & all(bsxfun(@le,vPos,reshape(sz([2 1]),[1 1 2])),3);
vPosR=single(reshape(vPos,[],2));
vScale=single(model.srcXYI(4,idx(:))');
nScales=max(model.srcXYI(4,:));

%% compute vm
vm=permute(accumarray([vPosR(valid(:),:) vScale(valid(:))],probs(valid(:)),[sz([2 1]) nScales]),[2 1 3]);
for iS=1:nScales
    cur_geom_sigma=ceil(params.geom_sigma*model.scales(iS));
%     vm(:,:,iS)=(2*pi*cur_geom_sigma^2)*vl_imsmooth(vm(:,:,iS),cur_geom_sigma);
    ker=fspecial('gaussian',cur_geom_sigma*[2 2]+1,cur_geom_sigma);
    vm(:,:,iS)=imfilter(vm(:,:,iS),ker/max(ker(:)),'same','conv');
    switch params.scales_nrm_type
        case 'rs'
            if params.rs_subs~=1
                [m,s]=robust_stat(vm(1:params.rs_subs:end,1:params.rs_subs:end,iS),params.rs_nCutOff,params.rs_nIters);
            else
                [m,s]=robust_stat(vm(:,:,iS),params.rs_nCutOff,params.rs_nIters);
            end
            s=max(s,0.1);
        case 'area'
            m=0;
            s=model.scales(iS)^2;
    end
    vm(:,:,iS)=max(vm(:,:,iS)-m,0)/(s+(s==0));
end

if params.kickStart_phase==0
    vm_scs=vm;
    for iS=1:nScales
        sNNs=iS+(-1:1);
        sNNs((sNNs<=0) | (sNNs>nScales))=[];
        sWeights=exp(-0.5*(params.scale_sigma^(-2))*(model.scales(sNNs)-model.scales(iS)).^2);
        sWeights=sWeights/sum(sWeights);
        vm_scs(:,:,iS)=sum(bsxfun(@times,vm(:,:,sNNs),reshape(sWeights,[1 1 length(sWeights)])),3);
    end
    vm=vm_scs;
end

origVM=vm;

% vm=sum(vm,3);
[vm,chosenScaleIx]=max(vm,[],3);

switch params.scales_nrm_type
    case 'area'
        [m,s]=robust_stat(vm,params.rs_nCutOff,params.rs_nIters);
        s=max(s,0.1);
        vm=max(vm-m,0)/(s+(s==0));
    case 'rs'
        % do nothing
end

res.vm=vm;

if params.debugFlag
    %% debug display - primary voting
    figure;
    imshow(repmat(img,[1 1 3]));
    hold on;
    warning off;
    h=imagesc(imdilate(vm/max(vm(:)),ones(31)));
    set(h,'alphadata',0.5);
    warning on;
    colormap jet;
end

%% select candidates - extract local maxima & nms
nms=logical((vm==imdilate(vm,ones(params.nmsDiam))).*(vm>=max(params.initDetThresh,params.minMaxFactor*max(vm(:)))));
[cand_xy(:,2),cand_xy(:,1)]=find(nms);
if params.kickStart_phase>0
    cand_scale=model.scales(chosenScaleIx(nms));
else
    for iC=1:size(cand_xy,1)
        cScales=chosenScaleIx(cand_xy(iC,2),cand_xy(iC,1));
        if (length(model.scales)<3) || (cScales==1) || (cScales==length(model.scales))
            cand_scale(iC,1)=model.scales(cScales);
            continue;
        end
        cScales=cScales+(-1:1);

        x=model.scales(cScales);
        y=squeeze(origVM(cand_xy(iC,2),cand_xy(iC,1),cScales));
        p=fit(x(:),double(y(:)),'poly2');
        pred_scale=-0.5*p.p2/p.p1;
        cand_scale(iC,1)=pred_scale;
    end
end

if params.kickStart_phase>0
    res.final_cands_xyScrSclCls=[cand_xy cand_scale(:)];
    return;
end

if isempty(cand_xy)
    res.final_cands_xyScrSclCls=[];
    return
end

%% loop over hypotheses
sigmas=[params.geom_sigma params.geom_sigma params.scale_sigma];
votes_xys=bsxfun(@rdivide,[vPosR reshape(model.scales(vScale),[],1)],sigmas);
bpMap=zeros(sz(1:2));
all_cands=[];

for iCand=1:size(cand_xy,1)
    curCandXYS=[cand_xy(iCand,:) cand_scale(iCand)];
    
    %% back projection
    d=pdist2(...
        votes_xys,...
        single(bsxfun(@rdivide,curCandXYS,sigmas))...
    );
%     d=sum(bsxfun(@minus,votes_xys,curCandXYS./sigmas).^2,2);
    d=reshape(d,size(idx));

    bpValid=(d<=(params.sigma_factor));
    validCols=any(bpValid,1);
    nValidCols=sum(validCols);
    bpValid=bpValid(:,validCols);
    bpWgt=exp(-0.5*d(:,validCols).^2).*bpValid;
    bpWgt=bpWgt.*probs(:,validCols);
    ixAssign=(pos_xy(1,validCols)-1)*sz(1)+pos_xy(2,validCols);
    bpMap(ixAssign)=...
        max(...
            bpMap(ixAssign),...
            max(bpWgt,[],1)...
        );
    
    %% vote for classes
    clsVote=accumarray(model.srcXYI(3,reshape(idx(:,validCols),[],1))',bpWgt(:),[max(model.srcXYI(3,:)) 1]);
    clsVote=clsVote/max(clsVote(:));
    presentClasses=find(clsVote>=params.minMaxFactorCLS*max(clsVote));

    if params.debugFlag
        fprintf('cand %d: %s\n',iCand,sprintf('%s, ',model.pths{presentClasses}));
    end

    %% vote for final class detections
    suppRad4C=round(cand_scale(iCand)*model.objHeight);

    for iCls=1:length(presentClasses)
        validC=valid(:,validCols) & bpValid & reshape(presentClasses(iCls)==model.srcXYI(3,reshape(idx(:,validCols),[],1)),[size(idx,1) nValidCols]);
        cur_vPosR=reshape(vPos(:,validCols,:),[],2);
        
        %shift by tlc, small size voting
        tlc=round(curCandXYS(1:2)-params.sigma_factor*params.geom_sigma-1);
        brc=round(curCandXYS(1:2)+params.sigma_factor*params.geom_sigma+1);
        
        vmC=accumarray(bsxfun(@minus,cur_vPosR(validC(:),:),tlc-1),bpWgt(validC(:)),brc-tlc+1)';
%         cur_geom_sigma=ceil(params.geom_sigma*cand_scale(iCand));
%         vmC=(2*pi*cur_geom_sigma^2)*vl_imsmooth(vmC,cur_geom_sigma);

        cur_geom_sigma=1+round(cand_scale(iCand)*params.geom_sigma*model.allSizesXY(presentClasses(iCls),:)/model.allSizesXY(presentClasses(iCls),1));
        kerX=fspecial('gaussian',[1 (4*cur_geom_sigma(1)+1)],cur_geom_sigma(1));
        kerX=kerX/max(kerX(:));
        kerY=fspecial('gaussian',[(4*cur_geom_sigma(2)+1) 1],cur_geom_sigma(2));
        kerY=kerY/max(kerY(:));
        vmC=imfilter(vmC,kerX,'same','conv');
        vmC=imfilter(vmC,kerY,'same','conv');

        clear cur_cand_xyp;
        nms=(vmC.*(vmC==imdilate(vmC,ones(suppRad4C))).*(vmC>=(params.minMaxFactor*max(vmC(:)))));
        [cur_cand_xyp(:,2),cur_cand_xyp(:,1),cur_cand_xyp(:,3)]=find(nms);
        
        %add the tlc back
        cur_cand_xyp(:,1:2)=bsxfun(@plus,cur_cand_xyp(:,1:2),tlc-1);

        stub=ones(size(cur_cand_xyp,1),1);
        all_cands=[all_cands ; cur_cand_xyp cand_scale(iCand)*stub presentClasses(iCls)*stub];

        if params.debugFlag
            %% debug display - primary voting
            figure;
            imshow(repmat(img,[1 1 3]));
            hold on;
            warning off;
            h=imagesc(imdilate(vmC/max(vmC(:)),ones(31)));
            set(h,'alphadata',0.5);
            warning on;
            colormap jet;
            title(model.pths{presentClasses(iCls)});
        end
    end
end

res.bpMap=bpMap;

%% perform nms and final object extraction
if params.debugFlag
    %%
    figure;
    imshow(img);
    hold on;
    plot(all_cands(59,1)/working_res,all_cands(59,2)/working_res,'rx','markersize',15);
end

%x y score scale class
[~,ix]=sort(all_cands(:,3),'descend');
toDismiss=false(size(all_cands,1),1);
for iC=1:length(ix)
    if ~toDismiss(ix(iC))
        d=pdist2(all_cands(:,1:2),all_cands(ix(iC),1:2));
        c=all_cands(ix(iC),5);
        suppRad4C=round(0.8*all_cands(ix(iC),4)*working_res*min(model.allSizesXY(c,:)));
        next2Dismiss=setdiff(find((d<suppRad4C/2) & (all_cands(:,3)<all_cands(ix(iC),3))),ix(iC));
%         if ismember(59,next2Dismiss)
%             %%
%             figure;
%             imshow(img);
%             hold on;
%             plot(all_cands(ix(iC),1)/working_res,all_cands(ix(iC),2)/working_res,'co','markersize',15);
%             plot(all_cands(next2Dismiss,1)/working_res,all_cands(next2Dismiss,2)/working_res,'rx','markersize',15);
%             break;
%         end
        toDismiss(next2Dismiss)=true;
    end
end

all_cands=all_cands(~toDismiss,:);

%% run BB classifier for validation
if isfield(model,'bbClassifier') && ~isempty(model.bbClassifier)
    all_cands=bbClassifier(img,all_cands,model,working_res,test_descrs,pos_xy,params);
end

%% output the final result
if ~isempty(params.working_height)
    all_cands(:,1:2)=round(all_cands(:,1:2)/working_res);
end
res.final_cands_xyScrSclCls=all_cands;

end

