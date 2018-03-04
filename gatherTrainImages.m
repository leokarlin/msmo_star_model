function trainImgs = gatherTrainImages(img_root_path)
% gatherTrainImages: recursively collect full path filenames of images within the img_root_path
fprintf('gathering list of images...');
srch_str1='*.jpg';
srch_str2='*.png';
queue={img_root_path};
trainImgs={};
while ~isempty(queue) % run over folders of training data
    %pop folder
    pop=queue{1};
    queue=queue(2:end);
    %disp(pop);
    
    %add current dir images
    d=[];
    d = [d; dir(fullfile(pop,srch_str1))];
    d = [d; dir(fullfile(pop,srch_str2))];
    cur_trainImgs=cellfun(@(x)(fullfile(pop,x)),{d.name}','uniformoutput',false);
    trainImgs=[trainImgs ; cur_trainImgs(:)];
    
    %recurse on subdirs
    d=dir(fullfile(pop,'*'));
    for iD=1:length(d)
        if d(iD).isdir && ~ismember(d(iD).name,{'.','..'})
            queue{end+1}=fullfile(pop,d(iD).name); %#ok<*SAGROW>
        end
    end
end
fprintf('done.\n');