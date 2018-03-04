function [ labels ] = img2gt_shell( img_pth )
%IMG2GT_SHELL converts the image path to the gt meta data labels first of
%which is the class

global all_shell_classes;

[~,nm,~]=fileparts(img_pth);

iYaw=strfind(nm,'_yaw_');
iPitch=strfind(nm,'_pitch_');
iRoll=strfind(nm,'_roll_');

cls=lower(nm(1:iYaw-1));
yaw=str2double(strrep(strrep(nm(iYaw+length('_yaw_'):iPitch-1),'m','-'),'p',''));
pitch=str2double(strrep(strrep(nm(iPitch+length('_pitch_'):iRoll-1),'m','-'),'p',''));
roll=str2double(strrep(strrep(nm(iRoll+length('_roll_'):end),'m','-'),'p',''));

[v,iCls]=ismember(cls,all_shell_classes);
if ~v
    all_shell_classes{end+1}=cls;
    iCls=length(all_shell_classes);
end

labels=[iCls yaw pitch roll];

end

