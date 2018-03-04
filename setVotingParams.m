function params = setVotingParams(db)

   
    params.dispFigNum=1235;
    params.test_stride=2;
    params.initDetThresh=5; %5
    params.finalDetThresh=10; %10
    params.k=50;
    params.scales_nrm_type='area'; %'rs'
    params.min_sz=100;
    params.doDisplay=true;
    params.dispFigVis='on';
    
    params.vote_func=@vote_ms5;
    
    params.enableHashSearch=true;
    params.postHashDescrStep=2;
    params.hashFailThresh=0.5; %0.5;
    params.nn_max_num_comp=200;
    params.killHashNaNs=true;
    
    params.usePatchMatch=true;
    params.patchMatchFailThresh=inf;
    params.numPatchMatchIters=5;
    
    params.descriptorFilterByNNThresh=0.5;
    
    params.verbouse=false;
    
    params.nd_enabled=true;
    
    params.naming_fun=@(cls_nm)(strtok(cls_nm(1:min(8,length(cls_nm)))));
    params.templates=db.imgs;