
% vlFeat 0.9.20
% cur=pwd();
% vlSetupPath=fullfile(rootPath,'toolbox\vlfeat-0.9.20\toolbox');
% cd(vlSetupPath);
% vl_setup();
% cd(cur);

% vlFeat 0.9.20
cur=pwd();
vlSetupPath=fullfile(rootPath,'toolbox\vlfeat-0.9.21\toolbox');
cd(vlSetupPath);
vl_setup();
cd(cur);


% src path
addpath(genpath(fullfile(rootPath,'src')));
addpath(genpath(fullfile(rootPath,'toolbox','utils')));
addpath(genpath(fullfile(rootPath,'toolbox','hashing')));

% dbstop
dbstop if error;

