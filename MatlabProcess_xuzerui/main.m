% main.m �������ļ���Ҫ���ڻ�ͼ�������ݴ���


% ���ú���
% frameDataRead_A	��ȡ bin �ļ��ز�����
% fun_SCR	�����ź����ӱ�
% fun_add_clutter	���뱳���Ӳ�
% fun_lss_pulse_compression	������ѹ��
% fun_lss_range_concate	ɾ�����������ƴ��
% fun_Process_MTD	�ٶ�-���� FFT����Ŀ����
% fun_0v_pressing	���ƾ�ֹĿ�ꡢ���Ӳ�


clc;clear; close all;

%% 1.���������Ʋ���
SimulateTarget = 0;    % ����ģ��ز�����
show_echo = 0;         % �ز���ʾ����
iSTC_show = 0;         % iSTC��ʾ����
show_PC = 0;           % ����ѹ�������ʾ
show_kaiser = 0;       % ��������ʾ����
show_hamming = 0;      % ��������ʾ����

%% 2.�ļ����ź�֡��������
prtNum = 1536;         % ÿ֡�źŵ�������
orgDataFilePath = 'D:\MATLAB_Project\20220420�����¥�������źŲɼ�\4\BasebandRawData_mat'; % STC
frameRInd = 38;       % bin�ļ�֡��1->380
fileTotalNums = 380;   % ����bin�ļ�����19*20=380
framesEachFile = 10;   % ÿ�����ļ��洢��֡��10��1536PRT

%% 3.������������
cj = sqrt(-1);         % ������λ
c  =  2.99792458e8;    % ��Ų������ٶ�
PI2 = 2*pi;
MHz = 1e+6;            % frequency unit(MHz)
us  = 1e-6;            % time unit(us)
ns  = 1e-9;            % time unit(ns)
KHz = 1e+3;            % frequency unit(KHz)
GHz = 1e+9;            % frequency unit(GHz)

%% 4.����ϵͳ��������
fs = 25*MHz;           % ����ԭʼ�źŵĲ���Ƶ��
ts = 1/fs;             % ��������
deltaR = c*ts/2;       % ����ֱ���
tao1  = 0.28*us;       % ���� 1 ����
tao2  = 3*us;          % ���� 2 ����
tao3  = 6.4*us;        % ���� 3 ����
f0 = 0*MHz;
fc = 9400*MHz;         % �״���Ƶ
prt = 64.88*us;        % �����ظ�����
prf = 1/prt;           % �����ظ�Ƶ��
wavelength = c/fc;
B = 20*MHz;            % ����
K1 = B/tao1;           % �������Ƶб�ʣ�ʱƵͼб�ʣ�
K2 = B/tao2;           % �������Ƶб�ʣ�ʱƵͼб�ʣ�
K3 = -B/tao3;          % �������Ƶб�ʣ�ʱƵͼб�ʣ�

% �����ļ���С����
point_prt = 1031;      % 3 ������� PRT ����������һ����������1������2������3 �������岨��
point_prt1 = 82;       % 1 �����������
point_prt2 = 242;      % 2 �����������    
point_prt3 = 707;      % 3 ����������� 
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9]; % FIR�˲���ϵ��
filter_coef = filter_coef /max(filter_coef );     % �˲���ϵ����һ��

%% 5.ģ�����ɷ����źţ�Chirp �źŷ��棩����ͼ
%����chirp�ź�ʱ����
t1 = -tao1/2:ts:tao1/2-ts;                     % ���� 1 ʱ����
t2 = -tao2/2:ts:tao2/2-ts;                     % ���� 2 ʱ����
t3 = -tao3/2:ts:tao3/2-ts;                     % ���� 3 ʱ����
t123 = linspace(0,prt,point_prt);

pulse1 = sin(2*pi*t1+pi/2);                    % 7����
pulse2 = exp(cj*2*pi*(f0*t2+0.5*K2*(t2.^2)));  % 75����
pulse3 = exp(cj*2*pi*(f0*t3+0.5*K3*(t3.^2)));  % 160����
pulse123 = zeros(1,point_prt);

pulse123(1,1:7) = pulse1;
pulse123(1,point_prt1+1:point_prt1+75) = pulse2;
pulse123(1,point_prt1+point_prt2+1:point_prt1+point_prt2+160) = pulse3;  % ģ���źŵ�ƴ����Ӵ�����������ͬ�����ź�ƴ�ӳ��������䲨�Ρ�

pulse1_prt=zeros(1,1622);
pulse2_prt=zeros(1,1622);
pulse3_prt=zeros(1,1622);

pulse1_prt(1,1:7)=pulse1;
pulse1_prt(1,93:168-1)=pulse2;
pulse1_prt(1,414:574-1)=pulse3;
a_pulse_prt=zeros(1,1622);
a_pulse_prt(1,150:1622-1)=pulse1_prt(1,1:1622-150);

% figure;
% subplot(211), plot(real(pulse1_prt));
% subplot(212), plot(real(a_pulse_prt));

aa_pulse_prt=zeros(1,1622);
aa_pulse_prt(1,1:82)=a_pulse_prt(10:10+82-1);
aa_pulse_prt(1,83:325)=a_pulse_prt(170:170+242);
aa_pulse_prt(1,325:325+707)=a_pulse_prt(574:574+707);
aa_pulse_prt_stc=aa_pulse_prt;


s_pc_prt=zeros(1,1031);
qujian1=aa_pulse_prt_stc(1:82);
qujian2=aa_pulse_prt_stc(83:83+242);
qujian3=aa_pulse_prt_stc(83+242+1:1031);

signal_PC_1=filter(filter_coef,1,qujian1(1,:).').';          % �����ź� 1 FIR�˲�
signal_PC_2=fun_pulse_compression(pulse2,qujian2);           % �����ź� 2 ����ѹ��
signal_PC_3=fun_pulse_compression(pulse3,qujian3);           % �����ź� 3 ����ѹ��
s_pc_prt(1,1:82)=signal_PC_1(1,1:82);
s_pc_prt(1,83:325)=signal_PC_2(1,1:242+1);
s_pc_prt(1,325:325+707-1)=signal_PC_3(1,1:707);


figure(1)
subplot(411)
plot(real(pulse1_prt));
subplot(412)
plot(real(a_pulse_prt));
subplot(413)
plot(real(aa_pulse_prt));
subplot(414)
plot(real(aa_pulse_prt_stc));

figure(2)
plot(abs(s_pc_prt));

figure(3)
subplot(411)
plot(t1,real(pulse1));
title('������');
xlabel('t/s');
ylabel('����');

subplot(412)
plot(t2,real(pulse2));
title('������ ');
xlabel('t/s');
ylabel('����');

subplot(413)
plot(t3,real(pulse3));
title('������');
xlabel('t/s');
ylabel('����');

subplot(414)
plot(t123,real(pulse123));
title('�ܷ�������');
xlabel('t/s');
ylabel('����');

%% 6.��ȡ�ز�����

% [echoData_Frame_0,echoData_Frame_1,frameInd,modFlag,beamPosNum,freInd,angleCode] = frameDataRead_A_xzr(orgDataFilePath,frameRInd,prtNum); 
% echoData_Frame_Left���������߲�λ�����ݣ�echoData_Frame_Right���Ҳ������Ͳ�λ�����ݣ�frameInd����ǰ֡�ı�ţ�modFlag��ģʽ��־
% beamPosNum������λ�ñ�ţ�beamNums���ܲ�������freInd��Ƶ��������angleCode���Ǳ�������
% save('echoData_Frame.mat','echoData_Frame_0','echoData_Frame_1');

echoData_Frame = load(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\4\BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']); % �����������ظ��ˣ�����ѡ��ע�͵�һ��
echoData_Frame_0 = echoData_Frame.echoData_Frame_0;
echoData_Frame_1 = echoData_Frame.echoData_Frame_1;
% echoData_Frame_0=echoData_Frame_1;

%��ʾ�ز�����
if show_echo == 1
    for i_prt = 1:prtNum  
    figure(4)
    subplot(221), plot(real(echoData_Frame_0(i_prt,:))),title(' 0����I·');
    subplot(222), plot(imag(echoData_Frame_0(i_prt,:))),title(' 0����-Q·');
    subplot(223), plot(real(echoData_Frame_1(i_prt,:))),title(' 1����I·');
    subplot(224), plot(imag(echoData_Frame_1(i_prt,:))),title(' 1����-Q·');
    pause(0.05)
    
    %title(strcat('��',num2str(frameInd),'֡����',num2str(i_prt-1),'%d����ز�'));
    fprintf('��%d֡����%d����ز�\n',frameRInd, i_prt);
    pause(0.0001)
    
    end
end

%% ����ģ��ĳһ���봦���˶�Ŀ��ز�
if SimulateTarget == 0 % ����ģ����
    SCR=10;%dB
    Velocity=5.7*(-1);
    Range=320;
    % Echo_simu=fun_SimulateTarget(Velocity,Range,prtNum,pulse1,pulse2,pulse3);
    
    Echo_simu = fun_SCR(prtNum,Echo_simu,echoData_Frame_0,SCR);       % Ŀ��ز��ź�����
    
    %���Ӳ�
    Echo_simu_clutter= fun_add_clutter(Echo_simu,echoData_Frame_0);   % gΪ�����źŵ���ϵ��
end


for i=1:2
figure(3);
subplot(211), plot(real(Echo_simu(i,:))),title('�����ź�');
subplot(212), plot(real(Echo_simu_clutter(i,:))),title(' �����ź��źŵ����Ӳ� ');
pause(0.05)
end
Echo_simu_clutter=gather(Echo_simu_clutter);

%% ����ѹ��
[Echo_simu_clutter_0]=fun_lss_pulse_compression(Echo_simu_clutter,show_PC,pulse1,pulse2,pulse3);
[s_PC_0]=fun_lss_pulse_compression(echoData_Frame_0,show_PC,pulse1,pulse2,pulse3);

% ɾ���ظ�������
Echo_simu_clutter_0=fun_lss_range_concate(prtNum,Echo_simu_clutter_0);
s_PC_0=fun_lss_range_concate(prtNum,s_PC_0);

%point_prt���ȸı���
[~,point_prt]=size(Echo_simu_clutter_0);


if show_hamming==1%��ʾ������
hamm=hamming(1536)';%���ɺ�����
hf=fftshift(fft(hamm,5000));
hf=hf/max(abs(hf));
figure(6);
plot(20*log10(abs(hf))),title('������Ƶ��');
end

for i=1:10
figure(4);
subplot(211), plot(abs(s_PC_0(i,:))),title('ԭʼ������ѹ');
subplot(212), plot(abs(Echo_simu_clutter_0(i,:))),title('����Ŀ����ѹ');
pause(0.05)
end


%% MTD
[m,n]=size(s_PC_0);
MTD_Signal_0 = fun_Process_MTD( s_PC_0,n,m );
MTD_Signal_simu = fun_Process_MTD( Echo_simu_clutter_0,n,m );
% ���Ķ������˲�ѹ�� 0 �ٶ��Ӳ�����ֹĿ��͵��Ӳ���
MTD_Signal_0=fun_0v_pressing(MTD_Signal_0);                 % ѹ��0�ٸ����ķ�ֵ
MTD_Signal_simu=fun_0v_pressing(MTD_Signal_simu);           % ѹ��0�ٸ����ķ�ֵ


if show_kaiser==1
betaMTD = 8;
WindowData= kaiser(m,betaMTD);
WindowDataf=fftshift(fft(WindowData,5000));
WindowDataf=WindowDataf/max(abs(WindowDataf));
figure(7);
plot(20*log10(abs(WindowDataf))),title('������Ƶ��');
end

point_prt=868;

%����MTD��άͼ
figure(8);
MTD_Signal_0 = 20*log10(abs(MTD_Signal_0)/max(max(abs(MTD_Signal_0))));
R_point=6;%������6m
r0=0:R_point:point_prt*R_point-R_point;%������
fd=linspace(-prf/2,prf/2,prtNum);
v0=fd*wavelength/2;%�ٶ���
subplot(121);
mesh(r0,v0,MTD_Signal_0);xlabel('����m');ylabel('�ٶ�m/s');zlabel('����dB');title('0����ԭʼ�ź�MTD');

MTD_Signal_simu= 20*log10(abs(MTD_Signal_simu)/max(max(abs(MTD_Signal_simu))));
subplot(122);
mesh(r0,v0,MTD_Signal_simu);xlabel('����m');ylabel('�ٶ�m/s');zlabel('����dB');title('0���������ź�MTD');


%% �����ٶ�ά
MTD_max=max(max(MTD_Signal_simu));
[vindex,rindex]=find(MTD_Signal_simu(:,:)==MTD_max);

figure(9);
subplot(211);plot(v0,(MTD_Signal_0(:,rindex))),xlabel('�ٶ�m/s'),ylabel('����dB');title('�ٶ�ά');
subplot(212);plot(v0,(MTD_Signal_simu(:,rindex))),xlabel('�ٶ�m/s'),ylabel('����dB');title('�ٶ�ά');

%% ��������ά

figure(10);
subplot(211);plot(r0,(MTD_Signal_0(vindex,:))),xlabel('����m'),ylabel('����dB');title('����ά');
subplot(212);plot(r0,(MTD_Signal_simu(vindex,:))),xlabel('����m'),ylabel('����dB');title('����ά');






