% ѹ��MTD_0�ٸ����Ĳ��Σ����ƾ�ֹĿ�ꡢ���Ӳ�
function MTD=fun_0v_pressing(MTD)%����ز����ȿ���
[prtNum,point_prt]=size(MTD);
zero_v_pos=round(prtNum/2);
% MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=mean(mean(abs(MTD)));
MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=0;
end