function SHparam = trainSH(X, SHparam)
%
% Input
%   X = features matrix [Nsamples, Nfeatures]
%   SHparam.nbits = number of bits (nbits do not need to be a multiple of 8)
%
%
% Spectral Hashing
% Y. Weiss, A. Torralba, R. Fergus. 
% Advances in Neural Information Processing Systems, 2008.

[Nsamples Ndim] = size(X);
nbits = SHparam.nbits;

% algo:
% 1) PCA
npca = min(nbits, Ndim);

covX=cov(X);
% m=size(X,1);
% xc=bsxfun(@minus,X,sum(X,1)/m);  % Remove mean
% covX=(xc' * xc);
% covX=covX/(m-1);

[pc, l] = eigs(double(covX), npca);
X = X * pc; % no need to remove the mean


% 2) fit uniform distribution
% mn = myprctile(X, 5);  
mn = min(X)-eps;
% mx = myprctile(X, 95);  
mx = max(X)+eps;


% 3) enumerate eigenfunctions
R=(mx-mn);
maxMode=ceil((nbits+1)*R/max(R));

nModes=sum(maxMode)-length(maxMode)+1;
modes = ones([nModes npca]);
m = 1;
for i=1:npca
    modes(m+1:m+maxMode(i)-1,i) = 2:maxMode(i);
    m = m+maxMode(i)-1;
end
modes = modes - 1;
omega0 = pi./R;
omegas = modes.*repmat(omega0, [nModes 1]);
eigVal = -sum(omegas.^2,2);
[yy,ii]= sort(-eigVal);
modes=modes(ii(2:nbits+1),:);


% 4) store paramaters
SHparam.pc = pc;
SHparam.mn = mn;
SHparam.mx = mx;
SHparam.mx = mx;
SHparam.modes = modes;
