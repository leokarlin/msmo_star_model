%main_runThrough.m
% main script demonstrating training and application of Star Model algorithm for oblect detection.
% based on the paper:
% L. Karlinsky, J. Shtok, Y. Tzur, A. Tzadok,  "Fine-grained recognition of thousands of object categories with single-example Training".CVPR 2017
% ----------------------------------------------------------------------------
% part of the multi-scale multi-object Star Model open source code.
% Leonid Karlinsky (karlinka@ibm.il.com), Joseph Shtok (josephs@il.ibm.com),
% IBM Research AI, Haifa, Israel, 2017
% ----------------------------------------------------------------------------

%% set up libraries
rootPath = 'C:\lb\project 170301 StarModel Matlab code\base_repository'; % set here the main folder of the code repository (where main_runThrough.m is located)
%train_images_path='C:\lb\project 170301 StarModel Matlab code\data\GroZi3.2k_data\grozi_training_food'; % set here the dataset path
train_images_path=fullfile(rootPath,'data\GroZi120\inVitro'); % set here the dataset path

set_up_libraries();

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%    Training       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% build list of training images from all subfolders
% trainImgs: cell array of full paths of training images
trainImgs = gatherTrainImages(train_images_path);
if isempty(trainImgs)
    error('No training images found.');
end
%% prepare the database db
db_filename =  fullfile(rootPath,'data','db_grozi.mat');
pars.sz = 150; % training image size (minimal image height)
pars.min_sz = 70; % minimal image size (in row or col dimension)
pars.edge_mask = true; % use edge masks for training images

trainImgs_struct = struct('name','grozi','train_images',{trainImgs});

% db is the main data structure comprising the model data. It is generated once, and is
% loaded from disk if already exists. See details within get_product_templates_db.m
[ db ] = get_product_templates_db(trainImgs_struct, pars); %[235 190]

%% compute image descriptors
pars.patchHeight = 24; % height of patches
pars.padVal = []; % image padding 
pars.scales = [0.6 0.8 1]; % compute descriptors for images resized to these scales
pars.sift_step = 4; % step(pixels) of the SIFT descriptor sampling
pars.uniformity_thresh = 0;

% compute visual descriptors for the database and append the data to the db_filename. Descriptors are is generated
% once, and are loaded from disk if they already exist
[ descrs ] = get_db_descrs(db_filename, pars); %[0.15 0.25 0.35 0.45 0.55 0.65 0.75 0.9 1]

%% build the star model
model_params=[];

% use this code to handle memory issues if using kd-trees:
    % model_params.num_pca_dims=64;
    % model_params.base_cand_cls_sigma=15;
    % model_params.ann_split=[0.25 0.25 0.25 0.25];

model_params.skip_ann=true;
descrs.scales = pars.scales;
descrs.patchHeight = pars.patchHeight;
[ model ] = build_star_model( db, descrs, model_params );

%% train hash
hash_params.nbits=27; %27
hash_params.maxK=50;
hashObj=trainHashNNv2(model.X,hash_params);
% call hashObj.close() to clean up

model.hashObj=hashObj;

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%    Test           %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pars.nominalMaxSize = 500; % maximal image height
%% test images 1
%test_examples_root_path = fullfile(rootPath,'data/sample_imgs');
test_examples_root_path = fullfile(rootPath,'data/sample_imgs');

% produce test images from a video file
% video_path = fullfile(rootPath,'data/GroZi120/video/Shelf_1.avi');
% test_examples_root_path = fetch_frames_from_video(video_path);


testImgs = gatherTrainImages(test_examples_root_path);
outDir=mymkdir(test_examples_root_path,'test_results');
SM_detection(db, model, testImgs, outDir, pars)

