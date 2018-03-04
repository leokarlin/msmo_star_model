function [voting_max_val, voting_max_coord] = NDvoting_v2( votingCoords, wgts, kernelSig, kernelScaleDim, kernelScaleDim_refVal )
%% handle simpler input
if length(kernelSig)==1
    kernelSig=repmat(kernelSig,1,size(votingCoords,2));
end

%% scale dim ref
if exist('kernelScaleDim','var') && ~isempty(kernelScaleDim)
    kerScale4Pts=votingCoords(:,kernelScaleDim)/kernelScaleDim_refVal;
else
    kerScale4Pts=ones(size(votingCoords,1),1);
end

%% normalize
votingCoords=bsxfun(@rdivide,votingCoords,kernelSig);
kernelSz=inf; %in sigma multiples
width_path_4_clust_assoc=0.25/kernelSz;

if size(votingCoords,1)<5000
    %exact version
    
    %% compute pairwise distance - for large amounts, removing squareform gives a boost in both perf. and mem. consumption
    D=squareform(pdist(votingCoords));

    D_in_Ker=D; %this is what it should be
    %D_in_Ker=squareform(pdist(votingCoords,'chebychev')); %this is just for backward compatibility, I suggest using D and thus spherical neighborhoods

    %% gen votes in the voting locations, may be by itself sufficient for one best init of the mean shift later
    valid_neighs=(D_in_Ker<=kernelSz);
    vote_loc_scores=sum(bsxfun(@times,exp(-0.5*(bsxfun(@rdivide,D,kerScale4Pts).^2)).*valid_neighs,wgts'),2);
else
    %quantized version
    [qCoords,tmp,ix]=unique(round(votingCoords),'rows');
    qWgts=accumarray(ix,wgts.*exp(-0.5*compute_vec_len(votingCoords-qCoords(ix,:))));
    qKerScale4Pts=accumarray(ix,kerScale4Pts.*exp(-0.5*compute_vec_len(votingCoords-qCoords(ix,:))));
    qKerScale4Pts=qKerScale4Pts./accumarray(ix,exp(-0.5*compute_vec_len(votingCoords-qCoords(ix,:))));
    
    if size(qCoords,1)<7000
        D=squareform(pdist(qCoords));
        D_in_Ker=D;
        valid_neighs=(D_in_Ker<=kernelSz);
        q_vote_loc_scores=sum(bsxfun(@times,exp(-0.5*(bsxfun(@rdivide,D,qKerScale4Pts).^2)).*valid_neighs,qWgts'),2);
        vote_loc_scores=q_vote_loc_scores(ix);
    else
        %approximate version
        ann_obj=ann(qCoords');
        ann_eps=3;
        [idx,dst]=ksearch(ann_obj,qCoords',100,ann_eps,true);
        q_vote_loc_scores=sum(exp(-0.5*bsxfun(@rdivide,dst,(qKerScale4Pts').^2)).*qWgts(idx),1)';
        close_ann(ann_obj);
        vote_loc_scores=q_vote_loc_scores(ix);
    end
end

%% mean shift iterations
clustAssign=zeros(size(vote_loc_scores));
cur_clust=1;
clus_max=[];

while ~all(clustAssign)
    rem=find(~clustAssign);
    [tmp,max_ind]=max(vote_loc_scores(rem));
    
    cur=votingCoords(rem(max_ind),:);
    cur_kerScale=kerScale4Pts(rem(max_ind));
    
    inside=[];
    prev_inside=[];
    cur_valid_ix=1:size(votingCoords,1);
    valid_thresh=20; %in sigma
    while isempty(inside) || (~isequal(inside,prev_inside))
        cur_D=pdist2(votingCoords(cur_valid_ix,:),cur);

        cur_D_in_Ker=cur_D; %this is what it should be
        %cur_D_in_Ker=pdist2(votingCoords,cur,'chebychev'); %as stated above, need to be replaced with regular neighborhood

        valid_neighs=(cur_D_in_Ker<=kernelSz);
        cur_W=exp(-0.5*((cur_D/cur_kerScale).^2)).*valid_neighs.*wgts(cur_valid_ix);
        nrm_cur_W=cur_W/sum(cur_W);
        cur=sum(bsxfun(@times,votingCoords(cur_valid_ix,:),nrm_cur_W),1);
        cur_kerScale=sum(bsxfun(@times,kerScale4Pts(cur_valid_ix),nrm_cur_W),1);

        %update cluster assignment (hopefully should be consistent, but
        %I do not think full clustering is necessary), the 0.25 is off
        %the shelf heuristic I found on the web :-) ...
        clustAssign(cur_valid_ix(cur_D_in_Ker<width_path_4_clust_assoc*kernelSz*cur_kerScale))=cur_clust;

        prev_inside=inside;
        inside=find(valid_neighs);
        cur_valid_ix=cur_valid_ix(cur_D<=(valid_thresh*cur_kerScale));
    end

    clus_max(cur_clust,1:(length(cur)+1))=[cur sum(cur_W)];
    cur_clust=cur_clust+1;

    %I think one is enough...
    break;
end

[voting_max_val,mx_ind]=max(clus_max(:,end));
voting_max_coord=clus_max(mx_ind,1:end-1);

%% de-normalize
voting_max_coord=round(bsxfun(@times,voting_max_coord,kernelSig));