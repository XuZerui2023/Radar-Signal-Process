% �������Զ��������Ƶ��״�ز����зֶ�����ѹ��
% ������ר�Ŵ���һ�������ֲ�ͬ���壨�̡��С�����ƴ�Ӷ��ɵĸ����״ﲨ�Ρ�
% �����Ƚ��ز��źŰ��������ͷָȻ���ÿһ��ʹ�ò�ͬ�ķ�����������ѹ������󽫽�����ºϲ���
%
% �������:
%   echoData_Frame_0 - (prtNum x point_prt) ԭʼ�ز����ݾ���ÿһ����һ��������PRT�ز���
%   show_PC          - (logical) ��ͼ���أ�Ϊ1ʱ��ʾÿ��PRT����ѹ��������ڵ��ԡ�
%   pulse1           - (1xN1) ��1�����壨խ���壩�Ĳο����Ρ�
%   pulse2           - (1xN2) ��2�����壨�����壩�Ĳο����Ρ�
%   pulse3           - (1xN3) ��3�����壨�����壩�Ĳο����Ρ�
%   point_prt1       - ������Ĳ�������
%   point_prt2       - ������Ĳ�������
%   point_prt3       - ������Ĳ�������
% �������:
%   s_PC_0           - (prtNum x point_prt) ����ѹ�����������źž���
%
function s_PC_0 = fun_lss_pulse_compression(echoData,params,show_PC,pulse1,pulse2,pulse3,point_prt1,point_prt2,point_prt3)

%����������ֿ�                     Ϊʲô�ܲɼ�����~= խ����ɼ����� + ������ɼ����� + ������ɼ����� !!!!!!
[m,n] = size(echoData);
prtNum = m;
point_prt = n;
signal_01 = echoData( :, 1:point_prt1);                          % 1-228
signal_02 = echoData( :, point_prt1+1 : point_prt1+point_prt2);  % 229-951
signal_03 = echoData( :, point_prt1+point_prt2+1 : point_prt);   % 952-3404

s_PC_0 = zeros(prtNum, point_prt); % ����ѹ�����ٺϵ�һ��


% FIR�˲���ϵ�������ȱʧ��
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9];
filter_coef = filter_coef /max(filter_coef ); % ��һ��


% ����ѹ��
for i_prt = 1:prtNum
    % �������� ����ѹ��
    signal_PC_01 = filter(filter_coef,1,signal_01(i_prt,:).').';        % խ������fir�˲�
    signal_PC_01 = signal_PC_01/1.2;

    signal_PC_02 = fun_pulse_compression(pulse2, signal_02(i_prt,:));   % ������ѹ��
    signal_PC_03 = fun_pulse_compression(pulse3, signal_03(i_prt,:));   % ������ѹ��

    % ����ѹ���������
    % s_PC_0(i_prt,1:point_prt1) = signal_PC_01(1:point_prt1);          % ��������
    % �Զ�����FIR�˲�����Ⱥ�ӳ� (ͨ��Ϊ����)
    delay1 = round(mean(grpdelay(filter_coef)));                        % ����FIR�˲�����Ⱥ�ӳ�

    % ʹ��ѭ����λ��У������ӳ� (�������ǰ�ƶ� delay1 ����)
    temp_signal = circshift(signal_PC_01, -delay1);                     % �����ѭ��ǰ�ƣ��Ӷ������ӳ�
    s_PC_0(i_prt, 1:point_prt1) = temp_signal(1:point_prt1);            % ��������
    
    %pluse1����filter������ѹ��������ǻᵼ�¼���ʵ��λ���Ӻ�12���㣬���Ծͽ����ǰ��12��
    % s_PC_0(i_prt,1:point_prt1-12)=signal_PC_01(13:point_prt1);
    % s_PC_0(i_prt,point_prt1-12+1:point_prt1)=signal_PC_01(1:12);

    % s_PC_0(i_prt,point_prt1+1:point_prt1+point_prt2) = signal_PC_02(75:end); % ��������
    offset2 = length(pulse2); % ��ȡ������ο��źŵ�ʵ�ʳ���
    % ����ѹ����ĵ� offset2 ���㿪ʼ��ȡ����ȡ point_prt2 ����
    s_PC_0(i_prt, point_prt1+1 : point_prt1+point_prt2) = signal_PC_02(offset2 : offset2+point_prt2-1); % ��������

    % s_PC_0(i_prt,point_prt1+point_prt2+1:point_prt) = signal_PC_03(160:end); % ��������
    offset3 = length(pulse3); % ��ȡ������ο��źŵ�ʵ�ʳ���
    % ����ѹ����ĵ� offset3 ���㿪ʼ��ȡ����ȡ point_prt3 ����
    s_PC_0(i_prt, point_prt1+point_prt2+1 : point_prt1+point_prt2+point_prt3) = signal_PC_03(offset3 : offset3+point_prt3-1); % ��������


    % --- ��ѡ�Ļ�ͼ���� ---
    if show_PC == 1
        % 1. ����ǰPRT����ѹ��������һ���ṹ��
        plot_data.pc_signal = s_PC_0(i_prt, :);
        plot_data.prt_index = i_prt;           % ����ǰѭ��������i_prt�ӽ�ȥ
        
        % 2. ���÷�װ�õĻ�ͼ��������ָ����ͼ����
        fun_plot_visualizations('pulse_compression', plot_data, params);
    end

end

end