function B = compressSHv2(X, SHparam)
%
% [B, U] = compressSH(X, SHparam)
%
% Input
%   X = features matrix [Nsamples, Nfeatures]
%   SHparam =  parameters (output of trainSH)
%
% Output
%   B = bits (compacted in 8 bits words)
%   U = value of eigenfunctions (bits in B correspond to U>0)
%
%
% Spectral Hashing
% Y. Weiss, A. Torralba, R. Fergus. 
% Advances in Neural Information Processing Systems, 2008.

nbits = SHparam.nbits;

omega0=pi./(SHparam.mx-SHparam.mn);
omegas=SHparam.modes.*repmat(omega0, [nbits 1]);

X = X*SHparam.pc;
X = bsxfun(@minus,X,SHparam.mn);

%% mex call
B=hash_mex(X,omegas);

return;

%% original code
% [Nsamples Ndim] = size(X);
% nbits = 26; %SHparam.nbits;
% 
% ys=zeros(size(X));
% 
% U = zeros([Nsamples nbits]);
% for i=1:nbits
%     omegai = omegas(i,:);
%     vv=omegai~=0;
%     ys(:,vv) = sin(bsxfun(@times,X(:,vv),omegai(vv))+pi/2);
%     
%     if nnz(vv)>1
%         yi = prod(ys(:,vv),2);
%     else
%         yi = ys(:,vv);
%     end
%     U(:,i)=yi;    
% end
% 
% B = compactbit(U>0);
% 
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function cb = compactbit(b)
% %
% % b = bits array
% % cb = compacted string of bits (using words of 'word' bits)
% 
% [nSamples nbits] = size(b);
% nwords = ceil(nbits/8);
% cb = zeros([nSamples nwords], 'uint8');
% 
% for j = 1:nbits
%     w = ceil(j/8);
%     cb(:,w) = bitset(cb(:,w), mod(j-1,8)+1, b(:,j));
% end
% 
% 
