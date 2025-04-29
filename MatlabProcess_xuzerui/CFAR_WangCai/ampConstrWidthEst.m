function widthDots = ampConstrWidthEst(specData_long1,ampConstr,interpFlag,interpTimes)

specDataOrg = abs(fftshift(specData_long1));
% ²åÖµ
% interpTimes = 1;
if interpFlag
    indSerie1 = 0:length(specData_long1)-1;
    indSerie2 = 0:1/interpTimes:length(specData_long1)-1;
    specData = interp1(indSerie1,specDataOrg,indSerie2,'spline');
    
    figure(70),plot(indSerie1,specDataOrg,'k'); hold on
    plot(indSerie2,specData,'r--');hold off
else
    specData = specDataOrg;
    indSerie2 =  0:length(specData_long1)-1;
end

[M1,I1] = max(specData);
specDataNorm = specData./M1(1);
specDataScaled = 20*log10(specDataNorm);

% intCount = 0;
% for jj = I1(1):-1:1
%     if specDataScaled(jj)<=ampConstr
%         indConstr(1) = jj;
%         break
%     end
% end
% 
% for jj = I1(1):1:length(indSerie2)
%     if specDataScaled(jj)<=ampConstr
%         indConstr(2) = jj;
%         break
%     end
% end

indConstr = find(specDataScaled>=ampConstr);

if ~isempty(indConstr)
    dotContr = indSerie2(indConstr);
    widthDots = abs(dotContr(end)-dotContr(1));
else
    widthDots = 0;   
end
figure(71),plot(indSerie2,specDataScaled,'k');