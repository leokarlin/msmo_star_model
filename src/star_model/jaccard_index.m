function [ ji ] = jaccard_index( r1, r2 )
%JACCARD_INDEX computes jaccard index= intersection over union of two
%recatngles in [x y w h]

intArea=myrectint(r1,r2);
a1=prod(r1(3:4));
a2=prod(r2(3:4));
nrm=(a1+a2-intArea);
ji=intArea/(nrm+(nrm==0));

end

