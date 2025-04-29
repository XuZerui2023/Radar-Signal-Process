% main.m 主函数文件主要用于画图，非数据处理


% 调用函数
% frameDataRead_A	读取 bin 文件回波数据
% fun_SCR	控制信号信杂比
% fun_add_clutter	加入背景杂波
% fun_lss_pulse_compression	多脉冲压缩
% fun_lss_range_concate	删除冗余点区间拼接
% fun_Process_MTD	速度-距离 FFT，动目标检测
% fun_0v_pressing	抑制静止目标、地杂波


clc;clear; close all;

%% 1.开关量控制部分
SimulateTarget = 0;    % 采用模拟回波开关
show_echo = 0;         % 回波显示开关
iSTC_show = 0;         % iSTC显示开关
show_PC = 0;           % 脉冲压缩结果显示
show_kaiser = 0;       % 凯撒窗显示开关
show_hamming = 0;      % 海明窗显示开关

%% 2.文件与信号帧参数配置
prtNum = 1536;         % 每帧信号的脉冲数
orgDataFilePath = 'D:\MATLAB_Project\20220420气象局楼顶基带信号采集\4\BasebandRawData_mat'; % STC
frameRInd = 38;       % bin文件帧号1->380
fileTotalNums = 380;   % 数据bin文件个数19*20=380
framesEachFile = 10;   % 每个新文件存储的帧数10个1536PRT

%% 3.基本常数定义
cj = sqrt(-1);         % 复数单位
c  =  2.99792458e8;    % 电磁波传播速度
PI2 = 2*pi;
MHz = 1e+6;            % frequency unit(MHz)
us  = 1e-6;            % time unit(us)
ns  = 1e-9;            % time unit(ns)
KHz = 1e+3;            % frequency unit(KHz)
GHz = 1e+9;            % frequency unit(GHz)

%% 4.基本系统参数设置
fs = 25*MHz;           % 生成原始信号的采样频率
ts = 1/fs;             % 采样周期
deltaR = c*ts/2;       % 距离分辨率
tao1  = 0.28*us;       % 脉冲 1 脉宽
tao2  = 3*us;          % 脉冲 2 脉宽
tao3  = 6.4*us;        % 脉冲 3 脉宽
f0 = 0*MHz;
fc = 9400*MHz;         % 雷达载频
prt = 64.88*us;        % 脉冲重复周期
prf = 1/prt;           % 脉冲重复频率
wavelength = c/fc;
B = 20*MHz;            % 带宽
K1 = B/tao1;           % 短脉冲调频斜率（时频图斜率）
K2 = B/tao2;           % 长脉冲调频斜率（时频图斜率）
K3 = -B/tao3;          % 长脉冲调频斜率（时频图斜率）

% 数据文件大小参数
point_prt = 1031;      % 3 个脉冲的 PRT 采样点数，一共包含脉冲1、脉冲2和脉冲3 三个脉冲波形
point_prt1 = 82;       % 1 脉冲区间点数
point_prt2 = 242;      % 2 脉冲区间点数    
point_prt3 = 707;      % 3 脉冲区间点数 
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9]; % FIR滤波器系数
filter_coef = filter_coef /max(filter_coef );     % 滤波器系数归一化

%% 5.模拟生成发射信号（Chirp 信号仿真）及绘图
%画出chirp信号时域波形
t1 = -tao1/2:ts:tao1/2-ts;                     % 脉冲 1 时间轴
t2 = -tao2/2:ts:tao2/2-ts;                     % 脉冲 2 时间轴
t3 = -tao3/2:ts:tao3/2-ts;                     % 脉冲 3 时间轴
t123 = linspace(0,prt,point_prt);

pulse1 = sin(2*pi*t1+pi/2);                    % 7个点
pulse2 = exp(cj*2*pi*(f0*t2+0.5*K2*(t2.^2)));  % 75个点
pulse3 = exp(cj*2*pi*(f0*t3+0.5*K3*(t3.^2)));  % 160个点
pulse123 = zeros(1,point_prt);

pulse123(1,1:7) = pulse1;
pulse123(1,point_prt1+1:point_prt1+75) = pulse2;
pulse123(1,point_prt1+point_prt2+1:point_prt1+point_prt2+160) = pulse3;  % 模拟信号的拼接与加窗，将三个不同脉冲信号拼接成完整发射波形。

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

signal_PC_1=filter(filter_coef,1,qujian1(1,:).').';          % 仿真信号 1 FIR滤波
signal_PC_2=fun_pulse_compression(pulse2,qujian2);           % 仿真信号 2 脉冲压缩
signal_PC_3=fun_pulse_compression(pulse3,qujian3);           % 仿真信号 3 脉冲压缩
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
title('短脉冲');
xlabel('t/s');
ylabel('幅度');

subplot(412)
plot(t2,real(pulse2));
title('中脉冲 ');
xlabel('t/s');
ylabel('幅度');

subplot(413)
plot(t3,real(pulse3));
title('长脉冲');
xlabel('t/s');
ylabel('幅度');

subplot(414)
plot(t123,real(pulse123));
title('总发射脉冲');
xlabel('t/s');
ylabel('幅度');

%% 6.读取回波数据

% [echoData_Frame_0,echoData_Frame_1,frameInd,modFlag,beamPosNum,freInd,angleCode] = frameDataRead_A_xzr(orgDataFilePath,frameRInd,prtNum); 
% echoData_Frame_Left：左波束（高波位）数据，echoData_Frame_Right：右波束（低波位）数据，frameInd：当前帧的编号，modFlag：模式标志
% beamPosNum：波束位置编号，beamNums：总波束数，freInd：频率索引，angleCode：角编码数据
% save('echoData_Frame.mat','echoData_Frame_0','echoData_Frame_1');

echoData_Frame = load(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\4\BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']); % 和上面那行重复了，可以选择注释掉一行
echoData_Frame_0 = echoData_Frame.echoData_Frame_0;
echoData_Frame_1 = echoData_Frame.echoData_Frame_1;
% echoData_Frame_0=echoData_Frame_1;

%显示回波数据
if show_echo == 1
    for i_prt = 1:prtNum  
    figure(4)
    subplot(221), plot(real(echoData_Frame_0(i_prt,:))),title(' 0波束I路');
    subplot(222), plot(imag(echoData_Frame_0(i_prt,:))),title(' 0波束-Q路');
    subplot(223), plot(real(echoData_Frame_1(i_prt,:))),title(' 1波束I路');
    subplot(224), plot(imag(echoData_Frame_1(i_prt,:))),title(' 1波束-Q路');
    pause(0.05)
    
    %title(strcat('第',num2str(frameInd),'帧，第',num2str(i_prt-1),'%d脉冲回波'));
    fprintf('第%d帧，第%d脉冲回波\n',frameRInd, i_prt);
    pause(0.0001)
    
    end
end

%% 仿真模拟某一距离处的运动目标回波
if SimulateTarget == 0 % 仿真模拟检测
    SCR=10;%dB
    Velocity=5.7*(-1);
    Range=320;
    % Echo_simu=fun_SimulateTarget(Velocity,Range,prtNum,pulse1,pulse2,pulse3);
    
    Echo_simu = fun_SCR(prtNum,Echo_simu,echoData_Frame_0,SCR);       % 目标回波信号生成
    
    %加杂波
    Echo_simu_clutter= fun_add_clutter(Echo_simu,echoData_Frame_0);   % g为无杂信号调制系数
end


for i=1:2
figure(3);
subplot(211), plot(real(Echo_simu(i,:))),title('仿真信号');
subplot(212), plot(real(Echo_simu_clutter(i,:))),title(' 仿真信号信号叠加杂波 ');
pause(0.05)
end
Echo_simu_clutter=gather(Echo_simu_clutter);

%% 脉冲压缩
[Echo_simu_clutter_0]=fun_lss_pulse_compression(Echo_simu_clutter,show_PC,pulse1,pulse2,pulse3);
[s_PC_0]=fun_lss_pulse_compression(echoData_Frame_0,show_PC,pulse1,pulse2,pulse3);

% 删除重复的区间
Echo_simu_clutter_0=fun_lss_range_concate(prtNum,Echo_simu_clutter_0);
s_PC_0=fun_lss_range_concate(prtNum,s_PC_0);

%point_prt长度改变了
[~,point_prt]=size(Echo_simu_clutter_0);


if show_hamming==1%显示海明窗
hamm=hamming(1536)';%生成海明窗
hf=fftshift(fft(hamm,5000));
hf=hf/max(abs(hf));
figure(6);
plot(20*log10(abs(hf))),title('海明窗频域');
end

for i=1:10
figure(4);
subplot(211), plot(abs(s_PC_0(i,:))),title('原始数据脉压');
subplot(212), plot(abs(Echo_simu_clutter_0(i,:))),title('仿真目标脉压');
pause(0.05)
end


%% MTD
[m,n]=size(s_PC_0);
MTD_Signal_0 = fun_Process_MTD( s_PC_0,n,m );
MTD_Signal_simu = fun_Process_MTD( Echo_simu_clutter_0,n,m );
% 中心多普勒滤波压制 0 速度杂波（静止目标和地杂波等
MTD_Signal_0=fun_0v_pressing(MTD_Signal_0);                 % 压制0速附近的峰值
MTD_Signal_simu=fun_0v_pressing(MTD_Signal_simu);           % 压制0速附近的峰值


if show_kaiser==1
betaMTD = 8;
WindowData= kaiser(m,betaMTD);
WindowDataf=fftshift(fft(WindowData,5000));
WindowDataf=WindowDataf/max(abs(WindowDataf));
figure(7);
plot(20*log10(abs(WindowDataf))),title('凯撒窗频域');
end

point_prt=868;

%画出MTD三维图
figure(8);
MTD_Signal_0 = 20*log10(abs(MTD_Signal_0)/max(max(abs(MTD_Signal_0))));
R_point=6;%两点间距6m
r0=0:R_point:point_prt*R_point-R_point;%距离轴
fd=linspace(-prf/2,prf/2,prtNum);
v0=fd*wavelength/2;%速度轴
subplot(121);
mesh(r0,v0,MTD_Signal_0);xlabel('距离m');ylabel('速度m/s');zlabel('幅度dB');title('0波束原始信号MTD');

MTD_Signal_simu= 20*log10(abs(MTD_Signal_simu)/max(max(abs(MTD_Signal_simu))));
subplot(122);
mesh(r0,v0,MTD_Signal_simu);xlabel('距离m');ylabel('速度m/s');zlabel('幅度dB');title('0波束仿真信号MTD');


%% 画出速度维
MTD_max=max(max(MTD_Signal_simu));
[vindex,rindex]=find(MTD_Signal_simu(:,:)==MTD_max);

figure(9);
subplot(211);plot(v0,(MTD_Signal_0(:,rindex))),xlabel('速度m/s'),ylabel('幅度dB');title('速度维');
subplot(212);plot(v0,(MTD_Signal_simu(:,rindex))),xlabel('速度m/s'),ylabel('幅度dB');title('速度维');

%% 画出距离维

figure(10);
subplot(211);plot(r0,(MTD_Signal_0(vindex,:))),xlabel('距离m'),ylabel('幅度dB');title('距离维');
subplot(212);plot(r0,(MTD_Signal_simu(vindex,:))),xlabel('距离m'),ylabel('幅度dB');title('距离维');






