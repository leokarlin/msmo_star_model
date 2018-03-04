function [ intArea ] = myrectint( r1, r2 )
%MYRECTINT same as Matlab's rectint just  the xy is of rect center

intArea=rectint([r1(1:2)-0.5*r1(3:4) r1(3:4)],[r2(1:2)-0.5*r2(3:4) r2(3:4)]);

end

