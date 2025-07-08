% fun_Process_MTD MTD������
% �ٶ�-���� FFT����Ŀ����
% ����������һ����������ѹ����"����-����"�����ݾ���ͨ����ÿ�����뵥Ԫ�����崮������ʱ��FFT�����з��򣩣�����ת��Ϊ"����-�ٶ�"����󣨾���-������ͼ, RDM����
%
% �������:
%   ProSignal       - (Num_PRTperFrame x Len_PRT) ������źž����з�������ʱ�䣨���룩���з��������ʱ�䣨���壩��
%   Len_PRT         - (double) ���뵥Ԫ��һ���������Ӧһ�����뵥Ԫ�����������������������
%   Num_PRTperFrame - (double) һ����δ�������CPI���е������������������������
%
% �������:
%   MTD_Signal      - (Num_PRTperFrame x Len_PRT) ������ٶ�-��������д����ٶȵ�Ԫ���д�����뵥Ԫ��

function MTD_Signal = fun_Process_MTD(ProSignal, Len_PRT, Num_PRTperFrame)
%% MTD����
% 1. ���ɴ�����
% �ڽ���FFT֮ǰ���źżӴ���������Ч����Ƶ��й©����ֹǿ�ź�����й¶�����ڵ�Ƶ�ʵ�Ԫ���Ӷ���߶���СĿ��ļ��������
betaMTD = 8;
WindowData= kaiser(Num_PRTperFrame,betaMTD);                   % �Ӵ�
% WindowData=load('kaiser_win.mat').kaiser_win;
% WindowData = ones(Num_PRTperFrame,1);                        % ���δ� �����Ӵ�

% 2. ��ʼ���������
MTD_Signal = zeros(Num_PRTperFrame,Len_PRT);                   % MTD������
MTD_Signal_R = zeros(1,Len_PRT);                               % MTD����ά������

% 3. ������뵥Ԫ����MTD���� (������FFT)
for Index=1:Len_PRT
    % �Ӵ�����
    Signal_Win = ProSignal(:,Index) .* WindowData;             % ��ȡ����ǰ���뵥Ԫ����������ز����γ�һ����������
    % FFT����
    FFT_Signal = fftshift(fft(Signal_Win, Num_PRTperFrame));   % ���н���FFT
    % ��ģֵ
    Abs_Signal = abs(FFT_Signal);
    % ���뵥Ԫѡ��
    [MTD_Signal_R(Index),~] = max(Abs_Signal);    % �ҳ���ǰ���뵥Ԫ�����ٶ��е��������ֵ������һ�ּ򵥵ķ�����ۻ���
    MTD_Signal(:,Index) = Abs_Signal;             % ����ǰ���뵥Ԫ���ٶ��״������յ�RDM����
end
% ��ȡÿ���ٶȵ�Ԫ����������Ӧ
MTD_Signal_V = max(MTD_Signal,[],2)';             % ������RDM�������ž���ά���з��������ֵ��
end

