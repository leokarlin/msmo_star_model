function [ db ] = get_product_templates_db( img_pathes, pars)
% produces the database db for the detector.
% db has the following structure:
% db.root       a struct with db name and the list of full pathes to training images
% db.wc         dataset name
% db.pths       a cell array of full-path filenames for training images
% db.imgs       a cell array of (resized) training images
% db.masks      a cell array of binary masks for the training images
% sb.meta       a vector of class labels (integers) corresp. to training images

% the database is produced in this function and is saved to file db_filename (see below).
% if the file already exists, the db is loaded from file.

% ----------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ----------------------------------------------------------------------------

fprintf('building Star Model db object...');

pars=setParamsDefaults(pars,{
    {'sz',150} ... % training image size (minimal image height)
    {'min_sz',[]} ... % minimal image size (in row or col dimension)
    {'edge_mask',false} ... % use edge masks for training images
    });


if ~iscell(img_pathes)
    img_pathes={img_pathes};
end

if ~isstruct(img_pathes{1})
    [root,name,ext]=fileparts(img_pathes{1});
    name=[name ext];
    [~,name2]=fileparts(root);
    db_filename=fullfile(fileparts(mfilename('fullpath')),'..','..','data',['db_' name2 '_' name '.mat']);
    db_filename=strrep(db_filename,'*','[all]');
else
    name=img_pathes{1}.name;
    db_filename=fullfile(fileparts(mfilename('fullpath')),'..','..','data',['db_' name '.mat']);
end

if ~exist(db_filename,'file')
    %db.root=img_pathes;
    db.wc=name;
    
    [db.pths,db.imgs,db.masks]=deal({});
    db.meta=[];
    
    for iWPath=1:length(img_pathes)
        if ~isstruct(img_pathes{iWPath})
            d=dir(img_pathes{iWPath});
            db_pths=cellfun(@(x)(fullfile(fileparts(img_pathes{iWPath}),x)),{d.name}','uniformoutput',false);
        else
            db_pths=img_pathes{iWPath}.train_images;
            if isfield(img_pathes{iWPath},'train_masks'),
                db_mask_pths=img_pathes{iWPath}.train_masks;
            end
        end
        
        [db_imgs,db_masks]=deal(cell(size(db_pths)));        
        valid=false(size(db_pths));
        for iImg=1:length(db_pths)
            try
                img=imread(db_pths{iImg});
                valid(iImg)=true;
            catch
                fprintf('failed to read: %s\n',db_pths{iImg})
            end
            
            if pars.edge_mask
                if size(img,3)==3
                    eMap=edge(rgb2gray(img),'canny');
                else
                    eMap=edge(img,'canny');
                end
                [rs,cs]=find(eMap);
                bb_tlc=[min(rs) min(cs)];
                bb_brc=[max(rs) max(cs)];
                if ~isempty(bb_tlc) && ~isempty(bb_brc)
                    img=img(bb_tlc(1):bb_brc(1),bb_tlc(2):bb_brc(2),:);
                end
            end
            
            sz_img=size(img);
            
            if length(pars.sz)==1
                if isempty(pars.min_sz)
                    img_scale=pars.sz/sz_img(1);
                else
                    img_scale=max(pars.sz/sz_img(1),pars.min_sz/min(sz_img(1:2)));
                end
            elseif length(pars.sz)==2
                if isempty(pars.min_sz)
                    img_scale=pars.sz(1:2);
                else
                    img_scale=max(pars.sz(1:2),round((pars.min_sz/min(pars.sz(1:2))*pars.sz(1:2))));
                end
            end
            
            img=imresize(img,img_scale);
            db_imgs{iImg}=img;
            
            %read mask if exists
            if ~exist('db_mask_pths','var')
                [maskPth,img_nm,img_ext]=fileparts(db_pths{iImg});
                maskPth=fullfile(maskPth,'masks',[img_nm img_ext]);
            else
                maskPth=db_mask_pths{iImg};
            end
            if exist(maskPth,'file')
                mask=logical(imread(maskPth));
                if pars.edge_mask
                    mask=mask(bb_tlc(1):bb_brc(1),bb_tlc(2):bb_brc(2),:);
                end
                mask=imresize(mask,img_scale);
                db_masks{iImg}=mask;
            end
                       
        end
        
        %clean invalid
        db_pths=db_pths(valid);
        db_imgs=db_imgs(valid);
        db_masks=db_masks(valid);
        
        %append to the pool
        db.pths=[db.pths ; db_pths];
        db.imgs=[db.imgs ; db_imgs];
        db.masks=[db.masks ; db_masks];
    end
    save_path = fileparts(db_filename);
    if ~exist(save_path,'dir'),
        mkdir(save_path);
    end
    save(db_filename,'db','-v7.3');
else
    load(db_filename,'db');
end

fprintf('done.\n');
end

