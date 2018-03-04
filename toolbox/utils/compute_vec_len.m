function [ l ] = compute_vec_len( x )
%COMPUTE_VEC_LEN eucledian norm

l=sqrt(sum(x.^2,2));

end

