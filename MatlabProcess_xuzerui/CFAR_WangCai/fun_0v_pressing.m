%ѹ��MTD_0�ٸ����Ĳ���
function MTD=fun_0v_pressing(MTD)%����ز����ȿ���
[prtNum,point_prt]=size(MTD);
zero_v_pos=round(prtNum/2);
MTD(zero_v_pos-round(prtNum/20):zero_v_pos+round(prtNum/20),:)=0;

end