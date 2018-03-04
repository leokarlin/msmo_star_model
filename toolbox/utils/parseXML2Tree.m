function [ xml ] = parseXML2Tree( xml_pth )
%PARSEXML2TREE parseXML wrapper, generates a tree struct as output

if ischar(xml_pth)
    root=parseXML(xml_pth);
    xml=parseXML2Tree(root);
    return;
else
    root=xml_pth;
end

nChildren=length(root.Children);
for iCh=1:nChildren
    ch=root.Children(iCh);
    if strcmp(ch.Name,'#text')
        if nChildren==1
            xml=strtrim(ch.Data);
            if isempty(xml)
                xml=[];
            else
                xml=eval(xml);
            end
        end
    else
        xml.(ch.Name)=parseXML2Tree(ch);
    end
end

end

