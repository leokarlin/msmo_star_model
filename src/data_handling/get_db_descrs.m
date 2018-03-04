function [ descrs ] = get_db_descrs( db_path, pars)
%get_db_descrs.m: computes dense SIFT descriptors for the training images
% usage: get_db_descrs( db_path, pars)
% Inputs:
%   db_path     full path to the .mat file containing the 'db' variable. db is the
%               main Star Model database, see get_product_templates_db.m
%   pars        parameters struct (default values are hardcoded below)
% ----------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ----------------------------------------------------------------------------

fprintf('computing descriptors for training images...');

pars=setParamsDefaults(pars,{
    {'patchHeight',24} ... % radius of the point extracted exp(linspace(log(16),log(60),3));
    {'padVal',[]} ... % padding
    {'scales',[1]} ...  % compute descriptors for images resized to these pars.scales
    {'sift_step',4} ... % step(pixels) of the SIFT descriptor sampling
    {'uniformity_thresh',0} ... % uniformity threshold
    });

if mod(pars.patchHeight,4)~=0
    error('Cannot use %d patch size, not divisible by 4!');
end
binSz=pars.patchHeight/4;



if ~exist('pars.uniformity_thresh','var') || isempty(pars.uniformity_thresh)
    pars.uniformity_thresh=0;
end

if isempty(pars.padVal)
    var_name=sprintf('descrs_%02d_no_pad',pars.patchHeight);
else
    var_name=sprintf('descrs_%02d_pad_%03d',pars.patchHeight,pars.padVal);
end

var_name=sprintf('%s_step_%d',var_name,pars.sift_step);

sVars=whos('-file',db_path);
sVars={sVars.name};
if ismember(var_name,sVars)
    load(db_path,var_name);
    eval(['descrs=' var_name ';']);
else
    %% need to compute the descriptors
    load(db_path,'db');
    [cdescrs,cxyi]=deal(cell(1,length(db.imgs)));
    [imgPyrSizesXY,descrPyrSizesXY]=deal(zeros(2,length(db.imgs),length(pars.scales)));
    for iImg=1:length(db.imgs)
        if size(db.imgs{iImg},3)==3
            img=rgb2gray(db.imgs{iImg});
        else
            img=db.imgs{iImg};
        end
        img=single(im2double(img));
        mask=db.masks{iImg};
        
        for iS=1:length(pars.scales)
            if pars.scales(iS)~=1
                sImg=imresize(img,pars.scales(iS));
                if ~isempty(mask)
                    sMask=imresize(mask,pars.scales(iS));
                else
                    sMask=[];
                end
            else
                %fix by Sivan
                sImg=img;
                sMask=mask;
            end
            
            imgPyrSizesXY(:,iImg,iS)=[size(sImg,2) ; size(sImg,1)];
            
            if ~isempty(pars.sift_step)
                cur_sift_step=max(2,ceil(pars.sift_step*pars.scales(iS)));
            else
                cur_sift_step=2;
            end
            [frms,curDescrs]=vl_dsift(sImg,'Size',binSz,'FloatDescriptors','Norm','Step',cur_sift_step,'Fast');
            
            if pars.uniformity_thresh>0
                uMask=stdfilt(sImg,ones(pars.patchHeight+1))>=(pars.uniformity_thresh/255);
                if ~isempty(sMask)
                    sMask=sMask & uMask;
                else
                    sMask=uMask;
                end
            end
            
            if ~isempty(sMask)
                ixDescrs=size(sMask,1)*(frms(1,:)-1)+frms(2,:);
                maskValid=sMask(ixDescrs);
                frms=frms(:,maskValid);
                curDescrs=curDescrs(:,maskValid);
            else
                nDescrPosX=length(unique(frms(1,:)));
                nDescrPosY=length(unique(frms(2,:)));
                descrPyrSizesXY(:,iImg,iS)=[nDescrPosX ; nDescrPosY];
            end
            
            curDescrs=bsxfun(@rdivide,curDescrs,sqrt(sum(curDescrs.^2)));
            cdescrs{iS,iImg}=curDescrs;
            cxyi{iS,iImg}=[frms(1:2,:) ; iImg*ones(1,size(frms,2)) ; iS*ones(1,size(frms,2))];
        end
    end
    
    descrs.X=cell2mat(cdescrs(:)');
    descrs.src=cell2mat(cxyi(:)');
    
    descrs.imgPyrSizesXY=imgPyrSizesXY;
    descrs.descrPyrSizesXY=descrPyrSizesXY;
    
    valid=~any(isnan(descrs.X),1);
    descrs.X=descrs.X(:,valid);
    descrs.src=descrs.src(:,valid);
    
    descrs.pars.patchHeight=pars.patchHeight;
    descrs.binSz=binSz;
    descrs.pars.padVal=pars.padVal;
    descrs.pars.scales=pars.scales;
    descrs.steps=max(2,ceil(descrs.pars.scales*pars.sift_step));
    
    eval([var_name '=descrs;']);
    save(db_path,'-append',var_name);
end
fprintf('done.\n');

end

