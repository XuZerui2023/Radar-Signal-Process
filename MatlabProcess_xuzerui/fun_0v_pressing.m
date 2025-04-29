% 压制MTD_0速附近的波形，抑制静止目标、地杂波
function MTD=fun_0v_pressing(MTD)%无噪回波幅度控制
[prtNum,point_prt]=size(MTD);
zero_v_pos=round(prtNum/2);
% MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=mean(mean(abs(MTD)));
MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=0;
end