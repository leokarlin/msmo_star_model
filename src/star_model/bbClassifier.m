function [ all_cands ] = bbClassifier( img, all_cands, model, working_res, test_descrs, pos_xy, params )
%BBVALIDATOR run the BB classification step

%% params
if ~exist('params','var') || isempty(params)
    params=[];
end

params=setParamsDefaults(params,{
});

%% inputs
if isfield(model.bbClassifier,'fv_model') && model.bbClassifier.fv_enabled
    fv_model=model.bbClassifier.fv_model;
else
    fv_model=[];
end
if isfield(model.bbClassifier,'cnn_model') && model.bbClassifier.cnn_enabled
    cnn_model=model.bbClassifier.cnn_model;
else
    cnn_model=[];
end

%% main flow
for iC=1:size(all_cands,1)
    hw=[model.objHeight model.objWidth];
    tlc=max(round(all_cands(iC,[2 1])-hw*all_cands(iC,4)/2),1);
    brc=min(round(all_cands(iC,[2 1])+hw*all_cands(iC,4)/2),[size(img,1) size(img,2)]);
    
    fi_tlc=max(round(tlc/working_res),[1 1]);
    fi_brc=min(round(brc/working_res),[size(img,1) size(img,2)]);
    subImg=img(fi_tlc(1):fi_brc(1),fi_tlc(2):fi_brc(2));
    
    nClasses=length(model.pths);
    
    if ~isempty(cnn_model)
        cls_score_cnn=zeros(1,nClasses);
        cnn_enc=compute_cnn_descr(subImg,cnn_model.net);
        if ~cnn_model.allPairs
            for iClass=1:nClasses
                cls_score_cnn(iClass)=cnn_model.cls(iClass).W(:)'*cnn_enc(:)+cnn_model.cls(iClass).B;
            end
        else
            allScores=cnn_model.all_pairs.W*cnn_enc(:)+cnn_model.all_pairs.B(:)>0;
            all_games=false(nClasses,nClasses);
            ixCur=1;
            for iC1=1:nClasses
                for iC2=(iC1+1):nClasses
                    all_games(iC1,iC2)=allScores(ixCur);
                    all_games(iC2,iC1)=~allScores(ixCur);
                    ixCur=ixCur+1;
                end
            end
            cls_score_cnn=sum(all_games,2);
        end
        
        %normalize
        cls_score_cnn=(cls_score_cnn-mean(cls_score_cnn))/std(cls_score_cnn);
    end
    
    if ~isempty(fv_model)
        cls_score_fv=zeros(1,nClasses);
        
        [~,iScale]=min(abs(fv_model.scales-all_cands(iC,4)));
        ixIn=(pos_xy(1,:)>=tlc(2)) & (pos_xy(2,:)>=tlc(1)) & (pos_xy(1,:)<=brc(2)) & (pos_xy(2,:)<=brc(1)) & (pos_xy(1,:)>=tlc(2)) & (pos_xy(1,:)>=tlc(2));
        %         ixIn=ixIn & (bpMap((pos_xy(1,:)-1)*sz(1)+pos_xy(2,:))>0);
        fv_enc=vl_fisher(...
            test_descrs(:,ixIn),...
            fv_model.fv(iScale).means,fv_model.fv(iScale).covariances,fv_model.fv(iScale).priors,'Improved');

        if ~fv_model.allPairs
            for iClass=1:nClasses
                cls_score_fv(iClass)=fv_model.cls(iScale,iClass).W(:)'*fv_enc(:)+fv_model.cls(iScale,iClass).B;
            end
        else
            allScores=fv_model.all_pairs(iS).W*fv_enc(:)+fv_model.all_pairs(iS).B(:)>0;
            all_games=false(nClasses,nClasses);
            ixCur=1;
            for iC1=1:nClasses
                for iC2=(iC1+1):nClasses
                    all_games(iC1,iC2)=allScores(ixCur);
                    all_games(iC2,iC1)=~allScores(ixCur);
                    ixCur=ixCur+1;
                end
            end
            cls_score_fv=sum(all_games,2);
        end
        
        %normalize
        cls_score_fv=(cls_score_fv-mean(cls_score_fv))/std(cls_score_fv);
    end
    
    cls_score=cls_score_cnn+cls_score_fv;
    
    [~,ixSc]=sort(cls_score,'descend');
    all_cands(iC,6:8)=ixSc(1:3);
end

end

