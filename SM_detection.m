function SM_detection(db, model, testImgs, outDir, pars)
% SM_detection.m: a wrapper for Star Model detection algorithm, applied to a list of test images.
% usage: SM_detection(db, model, testImgs, outDir, pars)
%
% Inputs: 
%   db,model        Star Model objects (see production script in main_runThrough.m)
%   testImgs        cell array of (full path) image filenames for test images.
%   outDir          path for writing the test results
%   pars            pars.nominalMaxSize is the maximal image height. Typical value = 500.
%
% Outputs:          the script produces a Matlab data file with detections and an image with overlayed bounding boxes.
%                   for the code that draws the detected bounding boxes, see vode_wrapper_v3.m, section "display final detections"
%   all_gathered    an [N,6] matrix of detections. Each row is a single bounding box, 
%                   with columns [x_center, y_center, score, scale, category, ?]. The width and heigh of the bbox are computed by scaling the category template.
%   all_cls_alts    the alternative categories proposals for the detected bounding boxes (including these in all_gathered)
%                   each row of all_cls_alts(:,:,1) contains category numbers for the detection box specified in the corresponding row of all_gathered.
%                   thus, all_gathered(:,5) == all_cls_alts(:,1,1)
%                   each row of all_cls_alts(:,:,2) contains detection scores corresp. to the categories in corresponding location in all_cls_alts(:,:,2). 
%                   thus, all_gathered(:,3) == all_cls_alts(:,1,2)
% ----------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ----------------------------------------------------------------------------
nominalMaxSize = pars.nominalMaxSize;
ticID=tic;
for iT=1:length(testImgs)
    fprintf('Checking image %d of %d..',iT,length(testImgs));
    % check if already done
    [~,nm,ext]=fileparts(testImgs{iT});
    sv_path=fullfile(outDir,[nm '.mat']);
    src_img_path=testImgs{iT};
    warning off;
    imInf=imfinfo(testImgs{iT});
    warning on;
    if ~isfield(imInf,'Orientation')
        imInf.Orientation=1;
    end
    
    toContinue=false;
    if exist(sv_path,'file')
        verif=load(sv_path,'src_img_path');
        if ~strcmpi(src_img_path,verif.src_img_path)
            [~,nm2]=fileparts(fileparts(testImgs{iT}));
            [~,nm3]=fileparts(fileparts(fileparts(testImgs{iT})));
            nm=[nm '_' nm2 '_' nm3];
            sv_path=fullfile(outDir,[nm '.mat']);
            if exist(sv_path,'file')
                toContinue=true;
            end
        else
            %already done
            toContinue=true;
            fprintf(' already done.\n');
        end
    end
    
    %store a local copy just in case...
    originalsPath=fullfile(mymkdir(outDir,'originals'),[nm ext]);
    if ~exist(originalsPath,'file')
        copyfile(testImgs{iT},originalsPath);
    end
    
    if toContinue
        continue;
    end
    fprintf('\n');
    rotAngle=0;
    
    % report
    fprintf('[%.2f] Processing image %d of %d\n',toc(ticID),iT,length(testImgs));
    ticID=tic; %#ok<*NASGU>
    
    % prepare the test image
    img=imread(testImgs{iT});
    if rotAngle~=0
        img=imrotate(img,rotAngle);
    end
    if size(img,3)>1
        img=rgb2gray(img);
    end
    img=imresize(img,min(pars.nominalMaxSize/size(img,1),1));
    
    % vote
    params = setVotingParams(db);
    
    ticID=tic;
    evalc('[all_gathered,all_cls_alts,all_vm,all_bp,f]=vote_wrapper_v3(img,model,params);');
    cur_total=toc(ticID);
    drawnow;
    fprintf('\tprocessed in %.2f seconds\n',cur_total);
    
    % store the output
    outFile=fullfile(mymkdir(outDir,'imgs'),[nm '.tif']);
    print(f,'-dtiff',outFile);
    params_netto=params;
    params_netto.templates=[];
    save(sv_path,'all_gathered','all_cls_alts','all_vm','all_bp','src_img_path','rotAngle','originalsPath','nominalMaxSize','params_netto');
end