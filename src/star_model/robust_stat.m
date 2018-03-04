function [ m, s ] = robust_stat( X, nCutOff, nIters )
%ROBUST_STAT computes the robust mean and std with outlier rejection

X=X(:);
valid=true(size(X));

for iIter=1:nIters
    m=mean(X(valid));
    s=std(X(valid));
    if s==0
        return;
    end
    valid=valid & (((X-m)/s)<=nCutOff);
end

m=mean(X(valid));
s=std(X(valid));

end

