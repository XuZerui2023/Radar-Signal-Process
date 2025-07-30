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

function MTD = fun_0v_pressing(MTD, config) % ����ز����ȿ���

% 1. ��ȡ��������ά�Ⱥ�ϵͳ����
[prtNum, point_prt] = size(MTD); 
velocity_resolution = config.cfar.deltaV;   % �ٶȷֱ��ʴ�С��Ҳ��һ���ٶȲο���Ԫ�Ĵ�С
suppress_velocity_ms = config.cfar.MTD_V;   % ���ɵ�����������Ҫ���Ƶ��ٶȷ�Χ���������غ���������Ϊ -3m/s �� +3m/s

% 2. ������Ҫ���Ƶ��ٶȵ�Ԫ����
notch_width_bins = ceil(suppress_velocity_ms / velocity_resolution);
% fprintf('  > �ٶȷֱ���: %.3f m/s, ���ư��ڿ��: %d ��Ԫ.\n', velocity_resolution, notch_width_bins);

% 3. ��λ����ͨ��
zero_v_pos = round(prtNum/2) + 1;

% 4. �������Ʒ�Χ�������б߽���
start_bin = max(1, zero_v_pos - notch_width_bins);
end_bin = min(prtNum, zero_v_pos + notch_width_bins);
suppress_range = start_bin:end_bin;

% 5. ִ������ѹ��
MTD(suppress_range, :) = 0;    % �൱��164�ٶȵ�Ԫ��168�ٶȵ�Ԫ

end
