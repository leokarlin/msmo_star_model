function [ all_gathered, all_cls_alts, all_vm, all_bp, f ] = vote_wrapper_v3( img, model, params )
%VOTE_WRAPPER wrapper for the default invocation of the star model
% supports classification alternatives
% ---------------------------------------------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ---------------------------------------------------------------------------------------------------------------
% Inputs:
%   img             query image
%   model           the Star Model model object, see main_runThrough.m for production details.
%   params          parameters struct. default values are listed below.
%
% Outputs:
%   all_gathered    an [N,6] matrix of detections. Each row is a single bounding box, 
%                   with columns [x_center, y_center, score, scale, category, ?]. The width and heigh of the bbox are computed by scaling the category template.
%   all_cls_alts    the alternative categories proposals for the detected bounding boxes (including these in all_gathered)
%                   each row of all_cls_alts(:,:,1) contains category numbers for the detection box specified in the corresponding row of all_gathered.
%                   thus, all_gathered(:,5) == all_cls_alts(:,1,1)
%                   each row of all_cls_alts(:,:,2) contains detection scores corresp. to the categories in corresponding location in all_cls_alts(:,:,2). 
%                   thus, all_gathered(:,3) == all_cls_alts(:,1,2)

%% params
if ~exist('params','var') || isempty(params)
    params=[];
end

params=setParamsDefaults(params,{
    {'debugFlag',false}, ...
    {'do_kickStart',false}, ...
    {'working_height',500}, ...
    {'test_stride',4}, ...
    {'initDetThresh',10}, ... %7
    {'finalDetThresh',10}, ... %10
    {'minMaxFactor',0}, ...
    {'geom_sigma',15}, ...
    {'k',50}, ...
    {'scales_nrm_type','area'}, ...
    {'nd_enabled',true}, ... 
    {'rs_nCutOff',5}, ...
    {'rs_nIters',5}, ...
    ...
    {'doImgFlipLR',false},...
    {'vote_func',@vote_ms3}, ...
    {'min_sz',100}, ...
    {'doDisplay',true}, ...
    {'dispFigNum',1235}, ...
    {'dispFigVis','on'}, ...
    {'naming_fun',@(x)(x(1:min(5,length(x))))}, ...
    ...
    ... multiple classifications
    {'ovlp_thresh4join',0.5},...
    {'large_scale_step',0.5}...
});

%% basic run loop
[all_gathered,all_cls_alts]=deal([]);
tImg=img;
scale=1;
[all_bp,all_vm]=deal(zeros(size(img)));
while size(tImg,1)>=min(params.min_sz,size(img,1)) %360
    ticID=tic;[ res ] = params.vote_func( model, tImg, params );toc(ticID);
    cur=res.final_cands_xyScrSclCls;
    cur_alts=res.clsAlternatives;
    all_vm=max(all_vm,imresize(res.vm,size(img)));
    if isfield(res,'bpMap')
        all_bp=max(all_bp,imresize(res.bpMap,size(img)));
    end
    if ~isempty(cur)
        cur(:,1:2)=round(cur(:,1:2)/scale);
        cur(:,4)=cur(:,4)/scale;
    end
    all_gathered=[all_gathered ; cur];
    
    %accumulate the alternatives
    if ~isempty(cur_alts)
        if ~isempty(all_cls_alts)
            sz_d=size(all_cls_alts,2)-size(cur_alts,2);
            if sz_d>0
                cur_alts(1,end+sz_d,1)=0;
            elseif sz_d<0
                all_cls_alts(1,end-sz_d,1)=0;
            end
        end
        all_cls_alts=cat(1,all_cls_alts,cur_alts);
    end
    
    tImg=imresize(tImg,params.large_scale_step);
    scale=scale*params.large_scale_step;
end

if params.doImgFlipLR
    tImg=fliplr(img);
    scale=1;
    while size(tImg,1)>=min(params.min_sz,size(img,1)) %360
        ticID=tic;[ res ] = params.vote_func( model, tImg, params );toc(ticID);
        cur=res.final_cands_xyScrSclCls;
        cur_alts=res.clsAlternatives;
        all_vm=max(all_vm,fliplr(imresize(res.vm,size(img))));
        if isfield(res,'bpMap')
            all_bp=max(all_bp,imresize(res.bpMap,size(img)));
        end
        if ~isempty(cur)
            cur(:,1:2)=round(cur(:,1:2)/scale);
            cur(:,1)=size(img,2)-cur(:,1);
            for iCC=1:size(cur,1)
                labels=img2gt_shell(model.pths{cur(iCC,5)});
                labels(2)=-labels(2);
                d=pdist2(model.meta(:,2:end),labels(2:end));
                d(model.meta(:,1)~=model.meta(cur(iCC,5),1))=inf;
                [tMin,nnClass]=min(d);
                cur(iCC,5)=nnClass;
            end
            cur(:,4)=cur(:,4)/scale;
        end
        all_gathered=[all_gathered ; cur];
        
        %accumulate the alternatives
        if ~isempty(cur_alts)
            if ~isempty(all_cls_alts)
                sz_d=size(all_cls_alts,2)-size(cur_alts,2);
                if sz_d>0
                    cur_alts(1,end+sz_d,1)=0;
                elseif sz_d<0
                    all_cls_alts(1,end-sz_d,1)=0;
                end
            end
            all_cls_alts=cat(1,all_cls_alts,cur_alts);
        end
        
        tImg=imresize(tImg,0.5);
        scale=scale*0.5;
    end
end

%% nms
if ~isempty(all_gathered)
    [~,ix]=sort(all_gathered(:,3),'descend');
    toDismiss=false(size(all_gathered,1),1);
    for iC=1:length(ix)
        if ~toDismiss(ix(iC))
            d=abs(bsxfun(@minus,all_gathered(:,1:2),all_gathered(ix(iC),1:2)));
            c=all_gathered(ix(iC),5);
            suppRad4C=round(0.8*all_gathered(ix(iC),4)*model.allSizesXY(c,:));
            next2Dismiss=setdiff(find(all(bsxfun(@le,d,suppRad4C/2),2) & (all_gathered(:,3)<all_gathered(ix(iC),3))),ix(iC));
            
            if ~isempty(setdiff(find(all(bsxfun(@le,d,suppRad4C/2),2) & (all_gathered(:,3)>all_gathered(ix(iC),3))),ix(iC))) % & (all_gathered(:,5)==all_gathered(ix(iC),5))
                toDismiss(ix(iC))=true;
            end
            
            toDismiss(next2Dismiss)=true;
            
            %update the multiple classification options list
            if ~toDismiss(ix(iC))
                altTo=false(size(next2Dismiss));
                [~,rCur]=objBBPoly(all_gathered(ix(iC),:),model.allSizesXY);
                for iN2D=1:length(next2Dismiss)
                    [~,rN2D]=objBBPoly(all_gathered(next2Dismiss(iN2D),:),model.allSizesXY);
                    ovp_score=jaccard_index(rCur,rN2D);
                    if ovp_score>=params.ovlp_thresh4join
                        altTo(iN2D)=true;
                    end
                end
                alt_cls2add=all_cls_alts(next2Dismiss(altTo),:,1);
                alt_scores2add=all_cls_alts(next2Dismiss(altTo),:,2);
                nz_ix_alt_cls2add=find(alt_cls2add);
                lastEntry=find(all_cls_alts(ix(iC),:,1)==0,1,'first');
                if isempty(lastEntry)
                    lastEntry=size(all_cls_alts,2);
                else
                    lastEntry=lastEntry-1;
                end
                all_cls_alts(ix(iC),(lastEntry+1):(lastEntry+length(nz_ix_alt_cls2add)),1)=alt_cls2add(nz_ix_alt_cls2add);
                all_cls_alts(ix(iC),(lastEntry+1):(lastEntry+length(nz_ix_alt_cls2add)),2)=alt_scores2add(nz_ix_alt_cls2add);
            end
        end
    end
    all_gathered(toDismiss,:)=[];
    all_cls_alts(toDismiss,:,:)=[];
end

%compact the all_cls_alts by making sure all options are unique and sorted
%by the score
for iObj=1:size(all_cls_alts,1)
    cur_cls=all_cls_alts(iObj,:,1);
    [cur_cls,~,ix_cls]=unique(cur_cls);
    cur_cls_scores=accumarray(ix_cls,all_cls_alts(iObj,:,2),[],@max);
    [cur_cls_scores,cur_cls_ord]=sort(cur_cls_scores,'descend');
    cur_cls=cur_cls(cur_cls_ord);
    all_cls_alts(iObj,:,:)=0;
    all_cls_alts(iObj,1:length(cur_cls),1)=cur_cls;
    all_cls_alts(iObj,1:length(cur_cls),2)=cur_cls_scores;
end
lastOne=find(any(all_cls_alts(:,:,1),1),1,'last');
all_cls_alts=all_cls_alts(:,1:lastOne,:);

%% display final detections
if params.doDisplay
    f=figure(params.dispFigNum);clf;
    set(f,'visible',params.dispFigVis);
    if ~isfield(params,'templates') && ~isempty(params.templates)
        show_img=img;
    else
        show_img=repmat(img,[1 1 3]);
        for iD=1:size(all_gathered,1)
            xy=all_gathered(iD,1:2);
            s=all_gathered(iD,3);
            if s<params.finalDetThresh
                continue;
            end
            c=all_gathered(iD,5);
            w=round(all_gathered(iD,4)*model.allSizesXY(c,1));
            h=round(all_gathered(iD,4)*model.allSizesXY(c,2));
            aggrOffs=0;
            for iC2S=1:min(2,size(all_cls_alts,2))
                c2d=all_cls_alts(iD,iC2S,1);
                dSz=round((all_cls_alts(iD,iC2S,2)/all_cls_alts(iD,1,2))*[h w]/2);
                if any(dSz<5)
                    break;
                end
                cls_img=imresize(params.templates{c2d},dSz);
                cntX=double(xy(1)-0.5*w+size(cls_img,2)/2)+aggrOffs;
                cntY=double(xy(2)+0.5*h-size(cls_img,1)/2);
                [meshX,meshY]=meshgrid(1:size(cls_img,2),1:size(cls_img,1));
                t_meshX=round(cntX+meshX-size(cls_img,2)/2);
                t_meshY=round(cntY+meshY-size(cls_img,2)/2);
                vv=(t_meshX>=1) & (t_meshX<=size(show_img,2)) & (t_meshY>=1) & (t_meshY<=size(show_img,1));
                for iChan=1:3
                    cls_img_range = meshY(vv)+(meshX(vv)-1)*size(cls_img,1);
                    if size(cls_img,3)==3,
                        cls_img_range = cls_img_range + numel(cls_img)*(iChan-1)/3;
                    end
                    show_img(t_meshY(vv)+(t_meshX(vv)-1)*size(show_img,1)+numel(img)*(iChan-1))=cls_img(cls_img_range);
                end
                aggrOffs=aggrOffs+size(cls_img,2);
            end
        end
    end
    warning off;
    imshow(show_img);
    warning on;
    hold on;
    for iD=1:size(all_gathered,1)
        xy=all_gathered(iD,1:2);
        s=all_gathered(iD,3);
        if s<params.finalDetThresh
            continue;
        end
        %         w=round(model.scales(res.final_cands_xyScrSclCls(iD,4))*model.objHeight);
        c=all_gathered(iD,5);
        w=round(all_gathered(iD,4)*model.allSizesXY(c,1)); %size(db.imgs{c},2));
        h=round(all_gathered(iD,4)*model.allSizesXY(c,2)); %size(db.imgs{c},1));

        cls_nm=model.pths{c};
        [~,cls_nm]=fileparts(cls_nm);

        cls_nm=params.naming_fun(cls_nm);

        cls_nm=strrep(cls_nm,'_','-');
        plot(xy(1)+0.5*w*[-1 1 1 -1 -1],xy(2)+0.5*h*[-1 -1 1 1 -1],'c-');
        try
            sAllVM=round(max(max(all_vm(round(xy(2))+(-5:5),round(xy(1)+(-5:5))))));
        catch
            sAllVM=-1;
        end
        text(double(xy(1)-0.5*w),double(xy(2)-0.5*h),sprintf('%.1f - %d',s,sAllVM),'backgroundcolor','y','color','b','fontsize',7,'margin',1);
        
%         if ~isfield(params,'templates') && ~isempty(params.templates)
            text(double(xy(1)),double(xy(2)+0.5*h),sprintf('%s',cls_nm),'backgroundcolor','y','color','b','fontsize',7,'margin',1);
%         end
    end
    drawnow;
else
    f=[];
end

end

