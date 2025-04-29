%% DMX信号处理
% Date: 2018.04.11
% 对6km模式的数据进行信号处理

clear; close all

%% Define constant
cj = sqrt(-1);
c  =  2.99792458e8;       % 电磁波传播速度

PI2 = 2*pi;
MHz = 1e+6;     % frequency unit(MHz)
us  = 1e-6;     % time unit(us)
ns  = 1e-9;     % time unit(ns)
KHz = 1e+3;     % frequency unit(KHz)
GHz = 1e+9;     % frequency unit(GHz)

%% 回波数据文件路径设置
orgDataSavePath = '.\';
orgDataFolderName = '2018年06月12日17时40分29秒';
orgDataSubFolderName = '基带原始数据';
% orgDataFilePath = fullfile(orgDataSavePath,orgDataFolderName,orgDataSubFolderName);
orgDataFilePath = 'G:\部分基带数据';
fileTotalNums = 13;   % 数据文件个数
framesEachFile = 10;   % 每个文件存储的数据帧数

%% 系统参数
fs = 12.5*MHz;             % 采样率
ts = 1/fs;
deltaR = c*ts/2;

flag_Mode = 1;     % 1-波形1
switch flag_Mode
    case 1  % 波形1
        tao1  = 0.56*us;             % 短脉冲脉宽
        tao2  = 5.04*us;             % 长脉冲脉宽
        prt   = 52.08*us;
        prf   = 1/prt;
        B     = 10*MHz;             % 带宽
        K1    = B/tao1;             % 短脉冲调频斜率
        K2    = B/tao2;             % 长脉冲调频斜率
        % 数据文件大小参数
        point_PRT = 566;   % 每个PRT的采集点数
        prtNum = 1536;     % 每帧信号的脉冲数据
        point_short = 62;                          % 短脉冲点数
        point_long = point_PRT-point_short;        % 长脉冲点数
        FFT_num = 512;           % 长脉冲脉压点数
        mtd_FFT_num = 2048;      % MTD点数
    case 2
        
    otherwise
        
end
%% 信号处理参数设置
% -------------------  处理帧范围 --------------------
frameS = 1;
frameE = 20;
if frameE>fileTotalNums*framesEachFile
    frameE = fileTotalNums*framesEachFile;
end
framesProcessTotal = frameE-frameS+1;    % 要处理的总帧数

% -------------------  脉压参数 --------------------
% 短脉冲：FIR滤波处理；  长脉冲：脉压
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9];

% 脉冲压缩参数
refDataFileFlag = 1;
rofPowerNorm = 1;     % 参考信号能量归一化
if refDataFileFlag    % 实采波形数据
    load('refDDCDataMF1.mat')
    matchWaveform2 = refData.';
else   % 理想仿真波形数据
    t2 = -tao2/2:ts:tao2/2-ts; 
    matchWaveform2 = exp(cj*pi*K2*t2.^2); % 滤波器时域
end

if rofPowerNorm
    matchWaveform2 = matchWaveform2/norm(matchWaveform2);
end

len2 = length(matchWaveform2);

winType = 3; % 脉冲压缩加窗：1-hamming；2-hanning 3- kaiser; 4-blackman
switch winType
    case 1 % hamming
        mfWh = hamming(len2);
    case 2 % hanning
        mfWh = hann(len2);
    case 3 % kaiser
        betaMF = 4.5;
        mfWh = kaiser(len2,betaMF);
    case 4 % blackman
        mfWh = blackman(len2);
    case 5 % bohmanwin
        mfWh = bohmanwin(len2);
    case 6 % nuttallwin
        mfWh = nuttallwin(len2);
    case 7 % parzenwin
        mfWh = parzenwin(len2);
    otherwise
        mfWh = ones(len2,1,'double');
end
matchF2_fun = conj(fft(matchWaveform2.*mfWh.',FFT_num)); % 频域匹配滤波器
matchF2_Matrix = repmat(matchF2_fun,prtNum,1);

% -------------------  MTD参数 --------------------
MTD_win_TYPE = 1; % 慢时间纬加窗：1-hamming；2-hanning 3- kaiser; 4-blackman
switch MTD_win_TYPE
    case 1 % hamming
        mtdWh = hamming(prtNum);
    case 2 % hanning
        mtdWh = hann(prtNum);
    case 3 % kaiser
        betaMTD = 4.5;
        mtdWh = kaiser(prtNum,betaMTD);
    case 4 % blackman
        mtdWh = blackman(prtNum);
    case 5 % bohmanwin
        mtdWh = bohmanwin(prtNum);
    case 6 % nuttallwin
        mtdWh = nuttallwin(prtNum);
    case 7 % parzenwin
        mtdWh = parzenwin(prtNum);
    otherwise
        mtdWh = ones(prtNum,1,'double');
end
mtdWh_short = repmat(mtdWh,1,point_short);
mtdWh_long = repmat(mtdWh,1,FFT_num);

MTD_V = 1;    % 杂波区速度范围
% -------------------------- CFAR参数 -------------------------------
% 速度维度
refCells_V = 5;    % 速度维 参考单元数
saveCells_V = 7;   % 速度维 保护单元数
T_CFAR_V = 7;      % 速度维恒虚警标称化因子
CFARmethod_V = 0;  % 0--选大；1--选小
% 距离维
rCFARDetect_Flag = 1;   % 距离维CFAR检测操作标志。 0-否； 1-是
refCells_R = 5;    % 距离维 参考单元数
saveCells_R = 7;   % 距离维 保护单元数
T_CFAR_R = 7;      % 距离维恒虚警标称化因子
CFARmethod_R = 0;  % 0--选大；1--选小

% -------------------------- 系统误差 -------------------------------
rSysErr_short = 0;         % 距离系统误差
rSysErr_long = 62*12;
rMeasureErr_short = 297;
rMeasureErr_long = 92;

% -------------------------- 距离和速度测量参数 -------------------------------
extraDots = 2;         % 插值时使用的数据点数
rInterpTimes = 8;      % 距离维插值倍数
vInterpTimes = 4;      % 速度维插值倍数

% ----------------------- 测角S曲线K值 ---------------------------
eleAngleComp = 0;        % 角度补偿值
eleAngleSysErr = 0;      % 角度系统误差值
beamAngleStep = 5;       % 相邻波束角度差

sysNum = 2;
kValues = angle_KvalueGen(sysNum);  


%% 指北角补偿
northAngle = 29.01;
angleE1 = 5.9;

%% 数据读取和处理
% 测量值矩阵初始化
hBar = waitbar(0,'Please wait...');
frameNum = 0;
angleCodeSeries = [];
for iFrame = frameS:frameE
%     
    % iFrame = 203;   % 要处理的帧数
    frameNum = frameNum+1;
    waitbar(frameNum/framesProcessTotal,hBar);
    
    % ---------------------------------- 读取数据 ---------------------------------
    % 读取一帧的数据
    [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCode] = frameDataRead_A(orgDataFilePath,iFrame);
%     echoData_Frame_Left=echoData_Frame_Right=(1536,566)
    angleCode = rem(angleCode+northAngle+angleE1,360);   % 补偿角度误差
    angleCodeSeries = [angleCodeSeries,angleCode];
    
    fc = freValueGen(freInd);  % 载频
    lamda = c/fc;              % 波长
    % 距离
    rScale_short = (0:point_short-1)*deltaR+rSysErr_short-rMeasureErr_short;   % 短脉冲
    rScale_long = (0:FFT_num-1)*deltaR+rSysErr_long-rMeasureErr_long;   % 长脉冲
    
    % 速度
    deltaDoppler = prf/mtd_FFT_num;
    deltaV = lamda*deltaDoppler/2;  
    fScale = fftshift((-mtd_FFT_num/2:mtd_FFT_num/2-1)*deltaDoppler);
    vScale = -lamda*fScale/2;
    
    % ---------------------------------- 长短脉冲数据拆开处理 ---------------------------------
    echoData_Frame_Left_short = echoData_Frame_Left(:,1:point_short);
    echoData_Frame_Left_long = echoData_Frame_Left(:,point_short+1:end);
    
    echoData_Frame_Right_short = echoData_Frame_Right(:,1:point_short);
    echoData_Frame_Right_long = echoData_Frame_Right(:,point_short+1:end);
    %% 脉冲压缩
    % ---------------------------------- 短脉冲数据FIR滤波 ---------------------------------
    echoData_MF_Left_short = filter(filter_coef,1,echoData_Frame_Left_short.').';
    echoData_MF_Right_short = filter(filter_coef,1,echoData_Frame_Right_short.').';
    
    % ---------------------------------- 长脉冲数据脉压缩 ---------------------------------
    echoData_FFT_Left_long = fft(echoData_Frame_Left_long,FFT_num,2);
    echoData_FFT_Right_long = fft(echoData_Frame_Right_long,FFT_num,2);
    echoData_MF_Left_long = ifft(echoData_FFT_Left_long.*matchF2_Matrix,[],2);
    echoData_MF_Right_long = ifft(echoData_FFT_Right_long.*matchF2_Matrix,[],2);
    
    %% MTD
    echo_MTD_Left_short = fft(echoData_MF_Left_short.*mtdWh_short,mtd_FFT_num,1);
    echo_MTD_Right_short = fft(echoData_MF_Right_short.*mtdWh_short,mtd_FFT_num,1);
    
    echo_MTD_Left_long = fft(echoData_MF_Left_long.*mtdWh_long,mtd_FFT_num,1);
    echo_MTD_Right_long = fft(echoData_MF_Right_long.*mtdWh_long,mtd_FFT_num,1);
    
    % 和
    echo_MTD_sum_short = abs(echo_MTD_Left_short)+abs(echo_MTD_Right_short);
    echo_MTD_sum_long = abs(echo_MTD_Left_long)+abs(echo_MTD_Right_long);
    
    % 差
    echo_MTD_diff_short = abs(echo_MTD_Right_short)-abs(echo_MTD_Left_short);
    echo_MTD_diff_long = abs(echo_MTD_Right_long)-abs(echo_MTD_Left_long);
        
    %% CFAR检测
    % 杂波扣除
    MTD_0_num = floor(MTD_V/deltaV);    
    zeroSetFlagMTD = [1:MTD_0_num+1, mtd_FFT_num-MTD_0_num+1:mtd_FFT_num];
    echo_MTD_sum_short(zeroSetFlagMTD,:) = 0;
    echo_MTD_sum_long(zeroSetFlagMTD,:) = 0;
    
    % 检测
    [cfarResultFlag_Matrix_short,cfarResultFlag_MatrixV_short] = executeCFAR(echo_MTD_sum_short,refCells_R,saveCells_R,...
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 短脉冲
    
    [cfarResultFlag_Matrix_long,cfarResultFlag_MatrixV_long] = executeCFAR(echo_MTD_sum_long,refCells_R,saveCells_R,...
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 长脉冲

    %% 距离、速度、角度测量
    % 短脉冲
    [rEstSeries1,vEstSeries1,eleAngleEstSeries1] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_Matrix_short,extraDots,...
        rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);  
    
    % 长脉冲
    [rEstSeries2,vEstSeries2,eleAngleEstSeries2] = motionParaMeasure(echo_MTD_sum_long,echo_MTD_diff_long,cfarResultFlag_Matrix_long,extraDots,...
        rScale_long,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);
       
    %%
    rEstSeries = [rEstSeries1;rEstSeries2];
    vEstSeries = [vEstSeries1;vEstSeries2];
    eleAngleEstSeries = [eleAngleEstSeries1;eleAngleEstSeries2];
    
    if ~isempty(rEstSeries)
        estDataLen1 = length(rEstSeries);
        figure(70),
        subplot(131),hold on
        scatter(iFrame*ones(estDataLen1,1),rEstSeries,'rs');
        xlabel('帧号'),ylabel('测量距离(m)');box on
        
        subplot(132),hold on
        estDataLen2 = length(vEstSeries);
        scatter(iFrame*ones(estDataLen2,1),vEstSeries,'rs');
        xlabel('帧号'),ylabel('测量速度(m/s)');box on
        
        subplot(133),hold on
        estDataLen3 = length(eleAngleEstSeries);
        scatter(iFrame*ones(estDataLen3,1),eleAngleEstSeries,'rs');
        xlabel('帧号'),ylabel('测量俯仰角(degree)');box on
    end
end
close(hBar);




