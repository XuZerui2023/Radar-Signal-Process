% ��MTD�����������ѹ�ƣ������ƾ�ֹĿ�ꡢ���Ӳ�
%
% ����������һ������-������ͼ��RDM����ͨ��������ͨ�����丽��
% �������ֵǿ�����㣬����Ч�������Ե��桢������Ⱦ�ֹĿ���ǿ�ز������Ӳ�����
% ����MTD������������߶�Ŀ������ȵĹؼ�һ����
%
% �������:
%   MTD - (prtNum x point_prt double) ����ľ���-�����վ������д����ٶ�ά���д������ά��
%
% �������:
%   MTD - (prtNum x point_prt double) ��������ѹ�ƴ����ľ���-�����վ���

function MTD = fun_0v_pressing(MTD) % ����ز����ȿ���
% 1. ��ȡ��������ά��
[prtNum,point_prt] = size(MTD);

% 2. ��λ����ͨ��
zero_v_pos = round(prtNum/2);
% MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=mean(mean(abs(MTD)));

% 3. ִ������ѹ��
MTD(zero_v_pos-round(prtNum/150) : zero_v_pos+round(prtNum/150),:) = 0;

end
