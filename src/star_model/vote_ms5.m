function [ res ] = vote_ms5( model, img, params, test_descrs, pos_xy )
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
    {'do_initial_voting_only',false},...
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
    ... meta
    {'nd_enabled',true},...
    {'metaSigma',[]},...
    ... direct matching
    {'do_direct_matching',false},...
    ... hash
    {'enableHashSearch',false},...
    {'hashFailThresh',1},...
    {'killHashNaNs',true},...
    {'postHashDescrStep',[]},...
    ... patch match
    {'usePatchMatch',false},...
    {'patchMatchRad',1},...
    {'patchMatchFailThresh',1},...
    {'numPatchMatchIters',8},...
    ... filtering descriptors
    {'descriptorFilterByNNThresh',inf},...
    ... multiple classifications
    {'ovlp_thresh4join',0.8},...
    ... debug
    {'verbouse',false},...
    {'debugFlag',false} ...
});

%% extract test image descriptors
sz=size(img);

if ~exist('test_descrs','var') || ~exist('pos_xy','var') || isempty(test_descrs) || isempty(pos_xy)
    tic; [test_descrs,pos_xy]=get_img_descrs(img,model.patchHeight,params.test_stride); toc;
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
ticID=tic;
remaining=true(1,size(test_descrs,2));
if params.enableHashSearch && (params.hashFailThresh>0) && isfield(model,'hashObj') && ~isempty(model.hashObj)
    [idx,dst]=model.hashObj.query(model.X,test_descrs,params.k);
%     [idx,dst]=vl_kdtreequery(model.ann,model.X,test_descrs,'NUMNEIGHBORS',params.k,'MaxNumComparisons',params.nn_max_num_comp);

    minDst=min(dst,[],1);
    if params.killHashNaNs
        remaining(isinf(minDst))=false;
    end
    remaining(minDst<=(params.hashFailThresh^2))=false;
    
    if ~isempty(params.postHashDescrStep) && (params.postHashDescrStep~=params.test_stride)
        relStride=params.postHashDescrStep/params.test_stride;
        unqX=unique(pos_xy(1,:));
        unqY=unique(pos_xy(2,:));
        unqX=unqX(1:relStride:end);
        unqY=unqY(1:relStride:end);
        toKill=~(ismember(pos_xy(1,:),unqX) & ismember(pos_xy(2,:),unqY));
        dst(:,toKill & remaining)=inf;
        remaining(toKill)=false;
    end
    
    if any(remaining) && params.usePatchMatch
        [dst,ord]=sort(dst,1,'ascend');
        ord=bsxfun(@plus,ord,size(ord,1)*(0:(size(ord,2)-1)));
        idx=reshape(idx(ord),size(idx));
        ixRemaining=find(remaining);
        
        aux_descrs=test_descrs(:,ixRemaining);
        
        queryIx=sub2ind(size(img),pos_xy(2,:),pos_xy(1,:));
        coverMap=zeros(size(img),'int32');
        coverMap_d=inf(size(img),'single');
        qCovered=(dst(1,:)<=params.hashFailThresh^2);
        coverMap(queryIx(qCovered))=idx(1,qCovered);
        coverMap_d(queryIx(qCovered))=dst(1,qCovered);
        
        [idxPM,dstPM]=deal(zeros(0,size(idx,2)));
        %rng(0); % controls the random seed to ouput deterministic result
        if any(coverMap(:))
            for iPMIter=1:params.numPatchMatchIters
                %%
                %obtain the current state of the cover, will be updated through
                %iterations of improvement
                dtSrcMap=logical(coverMap);
                if iPMIter>1
                    coveredIxx=queryIx(qCovered);
                    dtDistortIx=(randi(2,[1 length(coveredIxx)])==2);
                    if all(dtDistortIx)
                        dtDistortIx(1)=false;
                    end
                    dtSrcMap(coveredIxx(dtDistortIx))=int32(0);
                end
                
                [~,ixClosest]=bwdist(dtSrcMap);
                [dy,dx]=ind2sub(size(img),ixClosest(queryIx(ixRemaining)));
                [dx,dy]=deal(dx-pos_xy(1,ixRemaining),dy-pos_xy(2,ixRemaining));

                %compute the corresponding training offsets, take only the
                %closest NN as seed
                vNNseedIx=coverMap(ixClosest(queryIx(ixRemaining)));
                modelSteps=model.steps(model.srcXYI(4,vNNseedIx));
                modelDXY=round(bsxfun(@times,(1./modelSteps),-[dx ; dy]));
                szz=cumprod(size(model.descrPyrSizesXY));
                modelDIdx=modelDXY(2,:)+modelDXY(1,:).*model.descrPyrSizesXY(2+szz(1)*(model.srcXYI(3,vNNseedIx)-1)+szz(2)*(model.srcXYI(4,vNNseedIx)-1));
                match_ix=int32(vNNseedIx)+int32(modelDIdx);
                v2=(match_ix>0) & (match_ix<=size(model.X,2));
                v2(v2)=(model.srcXYI(3,match_ix(v2))==model.srcXYI(3,vNNseedIx(v2))) & (model.srcXYI(4,match_ix(v2))==model.srcXYI(4,vNNseedIx(v2)));
                v2(v2)=all(bsxfun(@eq,model.srcXYI(1:2,match_ix(v2))-model.srcXYI(1:2,vNNseedIx(v2)),bsxfun(@times,modelSteps(v2),modelDXY(:,v2))),1);

                %now put it all together
                idxPM(1,ixRemaining(v2))=match_ix(v2);
                dstPM(1,ixRemaining(v2))=L2_dist2NNv2_mex(model.X,aux_descrs(:,v2),match_ix(v2));
%                 dstPM(1,ixRemaining(v2))=sum((model.X(:,match_ix(v2))-test_descrs(:,ixRemaining(v2))).^2,1);

                %update the cover map
                v2=find(v2);
                newlyCovered=ixRemaining(v2(dstPM(end,ixRemaining(v2))<=params.hashFailThresh^2));
                newlyCovered=newlyCovered(coverMap_d(queryIx(newlyCovered))>dstPM(end,newlyCovered));
                coverMap(queryIx(newlyCovered))=idxPM(end,newlyCovered);
                coverMap_d(queryIx(newlyCovered))=dstPM(end,newlyCovered);
                qCovered(newlyCovered)=true;
            end
        end
        
        %append the accumulated matches
        dstPM(idxPM==0)=inf;
        idxPM(idxPM==0)=1;
        idx=[idx ; idxPM];
        dst=[dst ; dstPM];
    end
    
    minDst=min(dst,[],1);
    remaining(minDst<=(params.patchMatchFailThresh^2))=false;
end
if any(remaining)
    if params.do_direct_matching
        dst=2-(2*(model.X'))*test_descrs;
        [dst,idx]=sort(dst,1);
        dst=dst(1:params.k,:);
        idx=idx(1:params.k,:);
    else
        if ~iscell(model.ann)
            [idx(1:params.k,remaining),dst(1:params.k,remaining)]=vl_kdtreequery(model.ann,model.X,test_descrs(:,remaining),'NUMNEIGHBORS',params.k,'MaxNumComparisons',params.nn_max_num_comp);
        else
            [idx,dst]=deal([]);
            for iA=1:size(model.ann,1)
                [cur_idx,cur_dst]=vl_kdtreequery(model.ann{iA,2},model.X(:,model.ann{iA,1}),test_descrs(:,remaining),'NUMNEIGHBORS',params.k,'MaxNumComparisons',params.nn_max_num_comp);
                idx=cat(1,idx,model.ann{iA,1}(cur_idx));
                dst=cat(1,dst,cur_dst);
            end
            [dst,ixSort]=sort(dst,'ascend');
            ixSort=bsxfun(@plus,ixSort,size(dst,1)*(0:(size(dst,2)-1)));
            idx=reshape(idx(ixSort),size(idx));
            dst=dst(1:params.k,:);
            idx=idx(1:params.k,:);
        end
    end
end
if params.verbouse
    fprintf('[%.2f] total NN search, percent left to kd-tree: %.2f\n',toc(ticID),100*sum(remaining)/numel(remaining));
end

dst(isnan(dst))=inf;
dst(idx==0)=inf;
idx(idx==0)=1;

if ~isinf(params.descriptorFilterByNNThresh)
    qCovered=(min(dst,[],1)<=params.descriptorFilterByNNThresh^2);
    dst=dst(:,qCovered);
    idx=idx(:,qCovered);
    pos_xy=pos_xy(:,qCovered);
    test_descrs=test_descrs(:,qCovered);
end

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
un_probs=probs;
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
nScales=length(model.scales); %max(model.srcXYI(4,:));

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
            s=model.scales(iS);
%             s=s/(model.steps(iS)/max(model.steps));
            s=s^2;
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

if params.do_initial_voting_only
    return;
end

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
%         evalc('p=ezfit(x(:),double(y(:)),''poly2'');');
%         pred_scale=-0.5*p.m(2)/p.m(3);

        cand_scale(iC,1)=pred_scale;
    end
end

if params.kickStart_phase>0
    res.final_cands_xyScrSclCls=[cand_xy cand_scale(:)];
    return;
end

if isempty(cand_xy)
    res.final_cands_xyScrSclCls=[];
    res.clsAlternatives=[];
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
    
    %% fine-grained
%     if isfield(model,'meta') && params.nd_enabled
%         %% vote for classes
%         cur_vPosR=reshape(vPos(:,validCols,:),[],2);
%         
%         trgClsIx=model.meta(model.srcXYI(3,reshape(idx(:,validCols),[],1))',1);
%         clsVote=accumarray(trgClsIx,bpWgt(:),[max(model.meta(:,1)) 1]);
%         clsVote=clsVote/max(clsVote(:));
%         presentClasses=find(clsVote>=params.minMaxFactorCLS*max(clsVote));
%         for iCls=1:length(presentClasses)
%             cur_geom_sigma=1+round(cand_scale(iCand)*params.geom_sigma*model.allSizesXY(presentClasses(iCls),:)/model.allSizesXY(presentClasses(iCls),1));
%             trgCoords=single([cur_vPosR model.meta(model.srcXYI(3,reshape(idx(:,validCols),[],1))',2:end)]);
%             assert(length(params.metaSigma)==(size(model.meta,2)-1));
%             kernelSig=[cur_geom_sigma params.metaSigma];
%             v=bpValid(:) & (trgClsIx==presentClasses(iCls));
%             
%             w=probs(:,validCols);
% %             w=un_probs(:,validCols);
% 
%             w=w(:);
%             if nnz(v)==1
%                 voting_max_val=w(v);
%                 voting_max_coord=trgCoords(v,:);
%             else
%                 [voting_max_val,voting_max_coord]=NDvoting_v2(trgCoords(v,:),w(v),kernelSig);
%             end
%             d=pdist2(single(model.meta(:,2:end)),single(voting_max_coord(3:end)));
%             d(model.meta(:,1)~=presentClasses(iCls))=inf;
%             [tMin,nnClass]=min(d);
%             all_cands=[all_cands ; voting_max_coord(1:2) voting_max_val cand_scale(iCand) nnClass iCand];
%         end
%     else
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
            all_cands=[all_cands ; cur_cand_xyp cand_scale(iCand)*stub presentClasses(iCls)*stub iCand*stub];

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
%    end
end

res.bpMap=bpMap;

%% perform nms and final object extraction
if params.debugFlag
    %%
    figure;
    imshow(img);
    hold on;
    c2s=all_cands(:,3)>=params.finalDetThresh;
    plot(all_cands(c2s,1)/working_res,all_cands(c2s,2)/working_res,'rx','markersize',15);
end

%x y score scale class
[~,ix]=sort(all_cands(:,3),'descend');
toDismiss=false(size(all_cands,1),1);

clsAlternatives=zeros(size(all_cands,1),1,2);
clsAlternatives(:,1,1)=all_cands(:,5);
clsAlternatives(:,1,2)=all_cands(:,3);

for iC=1:length(ix)
    if ~toDismiss(ix(iC))
        d=pdist2(all_cands(:,1:2),all_cands(ix(iC),1:2));
        c=all_cands(ix(iC),5);
        suppRad4C=round(0.8*all_cands(ix(iC),4)*working_res*min(model.allSizesXY(c,:)));
        next2Dismiss=setdiff(find((~toDismiss) & (d<suppRad4C/2) & (all_cands(:,3)<all_cands(ix(iC),3))),ix(iC));
        toDismiss(next2Dismiss)=true;
        
        %update the multiple classification options list
        altTo=false(size(next2Dismiss));
        [~,rCur]=objBBPoly(all_cands(ix(iC),:),model.allSizesXY);
        for iN2D=1:length(next2Dismiss)
            if all_cands(next2Dismiss(iN2D),6)==all_cands(ix(iC),6)
                altTo(iN2D)=true;
            else
                [~,rN2D]=objBBPoly(all_cands(next2Dismiss(iN2D),:),model.allSizesXY);
                ovp_score=jaccard_index(rCur,rN2D);
                if ovp_score>=params.ovlp_thresh4join
                    altTo(iN2D)=true;
                end
            end
        end
        alt_cls2add=clsAlternatives(next2Dismiss(altTo),:,1);
        alt_scores2add=clsAlternatives(next2Dismiss(altTo),:,2);
        nz_ix_alt_cls2add=find(alt_cls2add);
        lastEntry=find(clsAlternatives(ix(iC),:,1)==0,1,'first');
        if isempty(lastEntry)
            lastEntry=size(clsAlternatives,2);
        else
            lastEntry=lastEntry-1;
        end
        clsAlternatives(ix(iC),(lastEntry+1):(lastEntry+length(nz_ix_alt_cls2add)),1)=alt_cls2add(nz_ix_alt_cls2add);
        clsAlternatives(ix(iC),(lastEntry+1):(lastEntry+length(nz_ix_alt_cls2add)),2)=alt_scores2add(nz_ix_alt_cls2add);
    end
end

all_cands=all_cands(~toDismiss,:);
clsAlternatives=clsAlternatives(~toDismiss,:,:);

%% run BB classifier for validation
if isfield(model,'bbClassifier') && ~isempty(model.bbClassifier)
    all_cands=bbClassifier(img,all_cands,model,working_res,test_descrs,pos_xy,params);
end

%% output the final result
if ~isempty(params.working_height)
    all_cands(:,1:2)=round(all_cands(:,1:2)/working_res);
end
res.final_cands_xyScrSclCls=all_cands;
res.clsAlternatives=clsAlternatives;

end

