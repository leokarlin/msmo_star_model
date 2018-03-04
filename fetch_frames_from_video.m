function frames_path = fetch_frames_from_video(video_path)
[fpath, fname, ext]= fileparts(video_path);
frames_path = fullfile(fpath,fname); 
if ~exist(frames_path,'dir'),
    mkdir(frames_path)
end
vid = VideoReader(video_path);
cntr1 = 0;
cntr2 = 0;
frames = [];
while hasFrame(vid)
    fr = readFrame(vid);
    if mod(cntr1,20)==0
        imwrite(fr,fullfile(frames_path,['frame_',num2str(cntr2,'%.3d'),'.jpg']));    
        %frames{end+1} = fr;
        cntr2 = cntr2+1;
    end
    cntr1 = cntr1+1;
%     if cntr2 ==20,
%         break
%     end
end