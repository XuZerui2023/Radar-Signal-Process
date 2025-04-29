function fc = freValueGen(freInd)
% 根据频点号得到频率值
switch freInd
    case 0
        fc = 9365*1e6; 
    case 1
        fc = 9365*1e6;
    case 2
        fc = 9375*1e6;   
    case 3
        fc = 9385*1e6; 
    case 4
        fc = 9395*1e6;
    case 5
        fc = 9405*1e6;       
    case 6
        fc = 9415*1e6;    
    case 7
        fc = 9425*1e6;
    case 8
        fc = 9435*1e6;
    case 9
        fc = 9445*1e6;
    case 10
        fc = 9455*1e6;
        
    otherwise
        
end