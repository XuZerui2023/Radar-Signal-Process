%STCµ÷ÖÆ²¹³¥
function [stc,eoch_iSTC]=fun_iSTC(eoch)
[m,n]=size(eoch);
eoch_iSTC=zeros(m,n);
% stc_ini=textread('./UAVdataset/20220326/2/20220326_164800/stcCurve.txt','%f');%1025*1
stc_ini=textread('DJIFlightRecord_2022-04-20_[10-31-47]','%f');%1025*1
stc_ini=stc_ini';%1*1025 
stc=zeros(1,n);
stc(1:length(stc_ini))=stc_ini;


for i=1:m

eoch_iSTC(i,:)=eoch(i,:).*(10.^(stc/20));
end

end