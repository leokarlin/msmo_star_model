function [ p, rect ] = objBBPoly( obj, allSizesXY )
%OBJBBPOLY get object rectangle
    c=obj(5);
    w=round(obj(4)*allSizesXY(c,1));
    h=round(obj(4)*allSizesXY(c,2));
    p=[obj(1)+0.5*w*[-1 1 1 -1 -1] ; ...
       obj(2)+0.5*h*[-1 -1 1 1 -1]];
   rect=[obj(1:2) w h];
end

