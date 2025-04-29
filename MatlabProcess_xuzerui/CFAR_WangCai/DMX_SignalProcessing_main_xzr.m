%% DMX信号处理主程序代码
% Date: 2018.04.11
% 该代码用于雷达信号处理，主要任务是：
% 1. 读取雷达回波数据（左波束数据矩阵为高波位数据，右波束数据矩阵为低波位的数据）
% 2. 进行匹配滤波（脉冲压缩）
% 3. 进行MTD（运动目标检测）
% 4. CFAR（恒虚警检测）
% 5. 计算目标的运动参数（距离、速度、角度）
% 6. 读取GPS数据，并与雷达数据对比
% 本程序中目标靠近:速度为负值，多普勒为正(I、Q两路数据读反了，已经改正)。应为速度为正值，多普勒为负
% Date: 2018.04.14 1）添加误差补偿变量 rGPSErr_short,rGPSErr_long； 2）添加GPS对比曲线; 
%         4） 修改了CFAR检测执行函数    
% Date: 2018.05.07 改变MF匹配滤波器系数，将脉压后目标位置从脉冲后沿可以改到前沿.但程序处理时，近处距离混叠到末尾距离处了


clear; close all


%% Define constant（单位转换）
cj = sqrt(-1);
c  = 2.99792458e8;       % 电磁波传播速度

PI2 = 2*pi;    % 2π
MHz = 1e+6;    % 频率单位：MHz -> Hz
us  = 1e-6;    % 时间单位：微秒 -> 秒
ns  = 1e-9;    % 时间单位：纳秒 -> 秒
KHz = 1e+3;    % 频率单位：KHz -> Hz
GHz = 1e+9;    % 频率单位：GHz -> Hz

%% 绘图与计算结果使能
plotFlag = 0;             % 是否绘制数据图像（0 = 不绘制，1 = 绘制）
resultDataSaveFlag = 1;   % 是否保存计算结果（0 = 不保存，1 = 保存）

%% 回波数据文件路径设置     % 该部分定义了不同数据文件的存储路径，使用不同的文件夹存储不同时间采集的数据
% orgDataSavePath = 'F:\DataResave_20180409';
% orgDataFolderName = '2018年04月09日17时54分22秒';  % 车辆，有GPS，定点
% orgDataFolderName = '2018年04月09日18时00分46秒';  % 车辆，有GPS，扇扫

% orgDataSavePath = 'F:\DataResave_20180504';
% orgDataFolderName = '2018年05月04日18时18分46秒';

% 有角编码，目前使用的数据路径
orgDataSavePath = 'G:\部分基带数据';
% orgDataFolderName = '2019年04月30日11时05分59秒';
orgDataFolderName = [];

% orgDataSubFolderName = '基带原始数据'; % 设定数据子文件夹
orgDataSubFolderName = [];
orgDataFilePath = fullfile(orgDataSavePath,orgDataFolderName,orgDataSubFolderName); % 组合完整的数据路径

fileTotalNums = 104;    % 数据文件个数
framesEachFile = 104;   % 每个文件包含 10 帧雷达数据


%% 设定差分GPS数据文件
dataGPSFileFlag = 0;    % 如果有差分GPS数据文件. 将在结果图上添加GPS数值进行对比

% if dataGPSFileFlag
%     GPSFilePath = 'f:\天津试验20180409\20180409\点迹航迹文件\gps实测数据3号\';
%     GPSFileName = '2018-04-09 17-44-14_com.txt';
%     
% %     GPSFilePath = 'f:\数据采集说明20180409\20180409\点迹航迹文件\gps实测数据4号\';
% %     GPSFileName = '2018-04-09 17-53-02_com.txt';
%     
%     GPSFileFullPath = fullfile(GPSFilePath,GPSFileName);
%     
%     GPSDataCols         =   5;                                               %GPS数据列数
%     
%     % 下面两个变量不同实验需要特定计算。（建议仅读取目标运动范围内的数据）
%     START_LINE_GPS      =	171;                                               % GPS文件读取起始行
%     LINE_NUM_GPS        =	154;                                               % GPS文件读取的行数
%     
%     % 将GPS时间序列转化为 帧号表示的序列后，与雷达回波信号的帧差
%     framesShift = 616-663;
% end

if dataGPSFileFlag                                                             % 检查是否启用了 GPS 数据处理
    GPSFilePath = 'f:\天津试验20180409\20180504\采集18\';                       % GPS 数据文件所在的文件夹路径
    GPSFileName = '2018-05-04 17-51-28_com.txt';                               % GPS 数据文件名称
       
    GPSFileFullPath = fullfile(GPSFilePath,GPSFileName);                       % 组合成完整路径
    
    GPSDataCols         =   5;                                                 % GPS数据列数
    
    % 下面两个变量不同实验需要特定计算。（建议仅读取目标运动范围内的数据），定义 GPS 数据的读取范围（起始行 + 读取行数）
    START_LINE_GPS      =	1127;                                              % GPS文件读取起始行
    LINE_NUM_GPS        =	77;                                                % GPS文件读取的行数
    
    % 将GPS时间序列转化为帧号表示的序列后，与雷达回波信号的帧差，计算雷达数据与 GPS 数据的时间偏移量，以便后续进行对齐
    framesShift = 616-530;
end

%% 系统参数
fs = 12.5*MHz;                              % 设定雷达系统的采样率
ts = 1/fs;                                  % 设定雷达系统的采样间隔（时间轴）
deltaR = c*ts/2;                            % 计算距离分辨率（基于光速和采样率）

flag_Mode = 1;                              % 设定雷达工作模式, 2个字节：1-长短脉冲； 9-回波模拟
switch flag_Mode                              
    case 1  % 波形1
        tao1  = 0.56*us;                    % 短脉冲脉宽
        tao2  = 5.04*us;                    % 长脉冲脉宽
        prt   = 52.08*us;                   % 脉冲重复时间（PRT = 52.08 微秒）
        prf   = 1/prt;                      % 脉冲重复频率
        
        B     = 10*MHz;                     % 带宽
        K1    = B/tao1;                     % 短脉冲调频斜率
        K2    = B/tao2;                     % 长脉冲调频斜率
        
        % 数据文件大小参数
        point_PRT = 566;                    % 每个PRT周期内的采集点数
        prtNum = 1536;                      % 每帧信号的脉冲周期PRT数量，累积脉冲数量，以提高检测精度
        
        % 设定短脉冲何长脉冲采样点数
        point_short = 62;                   % 短脉冲点数（采样点数较少）
        point_long = point_PRT-point_short; % 长脉冲点数
        
        % 设定FFT点数（用于匹配滤波）
        FFT_num = 512;                      % 长脉冲脉冲压缩FFT点数，较大的点数会提高频率分辨率
        mtd_FFT_num = 2048;                 % MTD（运动目标检测）FFT点数
   
    
    case 2
        
    otherwise
        
end

%% 信号处理参数设置
% -------------------  处理帧范围 --------------------
frameS = 1;                                 % 设定要处理的起始帧号
frameE = 90;                                % 设定要处理的结束帧号
if frameE>fileTotalNums*framesEachFile 
    frameE = fileTotalNums*framesEachFile;  % 如果结束帧号超过了可用的总帧数，则限制其范围
end

framesProcessTotal = frameE-frameS+1;       % 计算要处理的总帧数

% -------------------  脉压参数 --------------------
% 短脉冲：使用FIR滤波器滤波处理；  
% 长脉冲：使用脉冲压缩（匹配滤波）
% FIR滤波器参数
% Wn = 0.2;        % 滤波器的截止频率
% order_fir = 35;  % 滤波器阶数（影响滤波器的长度）
% filter_coef = fir1(order_fir,Wn,'low'); % 设计低通滤波器（FIR）
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9]; % 直接定义 FIR 滤波器系数
% freqz(filter_coef,1,512);    % 计算 FIR 滤波器的频率响应
% fvtool(filter_coef,1);       % 可视化 FIR 滤波器的特性


% 匹配滤波器（脉冲压缩）参数
% 匹配滤波器的生成方式：1.从外部文件加载（refDBFDataMF1.mat 或 refDDCDataMF1.mat）；2.自己计算（使用 LFM 公式生成）

refDataFileFlag = 1;           % 是否使用已采集的数据作为匹配滤波器的参考信号
rofPowerNorm = 1;              % 是否对匹配滤波器参考信号能量归一化
if refDataFileFlag             % 采用外部采集数据作为参考信号
%   load('refDBFDataMF1.mat')
    load('refDDCDataMF1.mat')  % 读取匹配滤波器参考数据
    matchWaveform2 = refData.';% 参考信号转置，适用于后续计算
else
    t2 = -tao2/2:ts:tao2/2-ts; % 如果不使用外部文件，则生成线性调频（LFM）匹配滤波器
    matchWaveform2 = exp(cj*pi*K2*t2.^2); % 计算LFM信号（滤波器时域）
end

if rofPowerNorm
    matchWaveform2 = matchWaveform2/norm(matchWaveform2); % 匹配滤波器进行归一化处理
end

% t2 = -tao2/2:ts:tao2/2-ts;
% matchWaveform2 = exp(cj*pi*K2*t2.^2); % 滤波器时域
% ---- Debug：把匹配滤波器的I、Q交换，查看长脉冲脉压结果. ------
% ---- 经过证实：回波数据的I、Q取反了，这样的话，靠近雷达的目标速度为正值 ----
% matchWaveform2Temp = exp(cj*pi*K2*t2.^2);
% matchWaveform2 = imag(matchWaveform2Temp)+cj*real(matchWaveform2Temp);

% -------------------  匹配滤波器加窗处理，可以减少频谱泄露，提高匹配滤波效果  --------------------
len2 = length(matchWaveform2); % 获取匹配滤波器波形的长度

winType = 3; % 脉冲压缩加窗：1-hamming；2-hanning 3- kaiser; 4-blackman；5-bohman；6-nuttall；7-parzen
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

%---------------  计算匹配滤波器的频域响应  ----------------
% matchF2_fun = fft(conj(matchWaveform2.*mfWh.'),FFT_num); % 频域匹配滤波器,峰值在脉冲后沿
matchF2_fun = conj(fft(matchWaveform2.*mfWh.',FFT_num));   % 频域匹配滤波器,峰值在脉冲前沿
% matchF2_fun = imag(matchF2_fun)+cj*real(matchF2_fun);

matchF2_Matrix = repmat(matchF2_fun,prtNum,1);             % 复制匹配滤波器 FFT 矩阵，使其适用于所有脉冲数据

% -------------------  MTD参数（优化多普勒分析，提高速度分辨率）--------------------
MTD_win_TYPE = 1; % 慢时间维加窗：1-hamming；2-hanning 3- kaiser; 4-blackman；其他窗函数
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
mtdWh_short = repmat(mtdWh,1,point_short);     % 扩展窗口，使其适用于短脉冲数据
mtdWh_long = repmat(mtdWh,1,FFT_num);          % 扩展窗口，使其适用于长脉冲数据

MTD_V = 1;    % 杂波区速度范围，低速区域（静态目标和杂波）设定阈值，排除低速目标

% -------------------------- 设定 CFAR 参数（自适应目标检测，避免噪声影响） -------------------------------
% 速度维度
refCells_V  = 5;           % 速度维 参考单元数（计算背景噪声功率）
saveCells_V = 7;           % 速度维 保护单元数（防止目标影响背景噪声计算）
T_CFAR_V = 7;              % 速度维恒虚警标称化因子（速度维 CFAR 阈值因子）
CFARmethod_V = 0;          % 速度维 CFAR 方法（采用 Cell-Averaging（CA-CFAR）方法）：0--选大；1--选小

vCFARResult_Flag = 1;      % 1 -- 保存仅速度维检测时的测量结果；0 -- 存储完整的距离、速度、角度数据

% 距离维
rCFARDetect_Flag = 1;      % 是否进行距离维CFAR检测操作标志。 0--否； 1--是
refCells_R = 5;            % 距离维 参考单元数
saveCells_R = 7;           % 距离维 保护单元数
T_CFAR_R = 7;              % 距离维恒虚警标称化因子（距离维 CFAR 阈值因子）
CFARmethod_R = 0;          % 距离维 CFAR 方法（采用 Cell-Averaging（CA-CFAR）方法）：0--选大；1--选小

% --------------------------  系统误差补偿  ----------------------------------
rSysErr_short = 0;         % 短脉冲距离系统误差（m）
rSysErr_long = 62 * 12;    % 长脉冲距离系统误差（m）
rMeasureErr_short = 297;   % 短脉冲测量误差（m）
rMeasureErr_long = 92;     % 长脉冲测量误差（m）

% -------------------------- 距离和速度测量参数 -------------------------------
extraDots = 2;             % 插值时使用的数据点数
rInterpTimes = 8;          % 距离维插值倍数（提高距离精度）
vInterpTimes = 4;          % 速度维插值倍数（提高速度精度）
 
% ----------------------- 测角S曲线K值 ---------------------------
eleAngleComp = 0;          % 俯仰角误差补偿值
eleAngleSysErr = 0;        % 俯仰角系统误差值
beamAngleStep = 5;         % 相邻波束之间的角度间隔（单位：度）

sysNum = 2;                % 设定雷达系统数量（多雷达协同使用时可调）
kValues = angle_KvalueGen(sysNum);  % 计算角度修正系数


%% 雷达系统指北角补偿
northAngle = 29.01;        % 雷达系统的指北角误差补偿（单位：度）
angleE1 = 5.9;             % 额外的角度误差补偿值（单位：度）


%% 数据读取和处理
% 测量值矩阵初始化
% 初始化测量值存储结构
if vCFARResult_Flag        % 仅存储速度维 CFAR 结果
    resultEst_Struct = struct('iFrame',[],'angleCode',[],'rEstSeries1',[],'vEstSeries1',[],'eleAngleEstSeries1',[],...
        'aziAngleEstSeries1',[],'rEstSeries2',[],'vEstSeries2',[],'eleAngleEstSeries2',[],'aziAngleEstSeries2',[]);

else                       % 存储完整的距离、速度、角度数据
    resultEst_Struct = struct('iFrame',[],'angleCode',[],'rEstSeries1',[],'vEstSeries1',[],'eleAngleEstSeries1',[],...
        'aziAngleEstSeries1',[],'rEstSeries2',[],'vEstSeries2',[],'eleAngleEstSeries2',[],'aziAngleEstSeries2',[],...
        'rEstSeriesV1',[],'vEstSeriesV1',[],'eleAngleEstSeriesV1',[],'aziAngleEstSeriesV1',[],'rEstSeriesV2',[],...
        'vEstSeriesV2',[],'eleAngleEstSeriesV2',[],'aziAngleEstSeriesV2',[]);
end

% UI界面初始化进度条
hBar = waitbar(0,'Please wait...');

% 初始化帧计数
frameNum = 0;
angleCodeSeries = [];            % 存储每帧对应的角编码值

for iFrame = frameS:frameE       % 循环处理每一帧数据    
   
    % iFrame = 203;              % 要处理的帧数
    frameNum = frameNum+1;       % 更新当前处理帧数
    waitbar(frameNum / framesProcessTotal, hBar); % 更新进度条
    
    % ---------------------------------- 读取一帧雷达回波的数据 ---------------------------------
    tic                          % 开始计时，测量数据读取时间
%     [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd] = frameDataRead(orgDataFilePath,iFrame);
%     angleCode = [];
    
    % 包含角编码的数据读取
    [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCode] = frameDataRead_A(orgDataFilePath,iFrame);
    
    % 角度补偿
    angleCode = rem(angleCode+northAngle+angleE1,360);   % 补偿角度误差
    angleCodeSeries = [angleCodeSeries,angleCode];       % 存储角度编码数据
   
    % 计算雷达的载频和波长
    fc = freValueGen(freInd);                            % 计算当前帧的载频（中心频率）
    lamda = c/fc;                                        % 计算雷达信号的波长
    
    % 计算短脉冲和长脉冲的距离尺度，标定距离
    rScale_short = (0:point_short-1)*deltaR+rSysErr_short-rMeasureErr_short;      % 短脉冲
    rScale_long = (0:FFT_num-1)*deltaR+rSysErr_long-rMeasureErr_long;             % 长脉冲
    
    % 计算多普勒频率和速度尺度，速度标定
    deltaDoppler = prf / mtd_FFT_num;                                             % 计算多普勒频率分辨率
    deltaV = lamda * deltaDoppler / 2;                                            % 计算速度分辨率
    % vScale = (-prtNum/2:prtNum/2-1)*deltaV;                                     % 速度标定
    % fScale = (-prtNum/2:prtNum/2-1)*deltaDoppler;                               % 多普勒频率标定
    fScale = fftshift((-mtd_FFT_num/2:mtd_FFT_num/2-1)*deltaDoppler);             % 计算多普勒频谱刻度
    vScale = -lamda*fScale/2;                                                     % 计算速度刻度（多普勒频移公式）
    
    % ---------------------------------- 长短脉冲数据拆分 -----------------------------------
    % 长短脉冲回波 拆开
    echoData_Frame_Left_short = echoData_Frame_Left(:,1:point_short);             % 从左波束（高波位）数据 echoData_Frame_Left 中取出前 point_short 个数据点，即短脉冲数据
    echoData_Frame_Left_long = echoData_Frame_Left(:,point_short+1:end);          % 从左波束（高波位）数据 echoData_Frame_Left 中取出 ponit_short+1 之后的所有数据点，即长脉冲数据
    
    echoData_Frame_Right_short = echoData_Frame_Right(:,1:point_short);           % 从右波束（低波位）数据 echoData_Frame_Right 中取出前 point_short 个数据点，即短脉冲数据
    echoData_Frame_Right_long = echoData_Frame_Right(:,point_short+1:end);        % 从右波束（低波位）数据 echoData_Frame_Right 中取出 ponit_short+1 之后的所有数据点，即长脉冲数据
    
    fprintf('回波数据读取耗时：%f\n',toc)
    
     
     %% 脉冲压缩
    tic % 计算脉冲压缩处理时间
    % --------------------- 使用FIR滤波器对短脉冲数据进行处理，以提高信号质量 ------------------------------
    echoData_MF_Left_short = filter(filter_coef,1,echoData_Frame_Left_short.').';   % 对短脉冲左波束进行滤波
    echoData_MF_Right_short = filter(filter_coef,1,echoData_Frame_Right_short.').'; % 对短脉冲右波束进行滤波
    
    % --------------------------  使用匹配滤波器对长脉冲数据脉冲压缩  ---------------------------------
    % 长脉冲频域数据
    echoData_FFT_Left_long = fft(echoData_Frame_Left_long,FFT_num,2);               % 求长脉冲左波束频谱
    echoData_FFT_Right_long = fft(echoData_Frame_Right_long,FFT_num,2);             % 求长脉冲右波束频谱
     
    % 长脉冲脉压数据
    echoData_MF_Left_long = ifft(echoData_FFT_Left_long.*matchF2_Matrix,[],2);      % 对长脉冲左波束信号频域匹配滤波后再反变换
    echoData_MF_Right_long = ifft(echoData_FFT_Right_long.*matchF2_Matrix,[],2);    % 对长脉冲右波束信号频域匹配滤波后再反变换
    
    fprintf('脉冲压缩耗时：%f\n',toc) % 输出脉冲压缩处理时间
    
    if plotFlag
        figure(50), % 绘图 长短脉冲滤波后频谱
        subplot(221),plot(abs(echoData_MF_Left_short(1,:)),'k');title('左波束，短脉冲') % 绘制短脉冲左波束FIR滤波后的频谱
        subplot(222),plot(abs(echoData_MF_Left_long(1,:)),'k');title('右波束，长脉冲')  % 绘制长脉冲左波束匹配滤波后的频谱
        subplot(223),plot(abs(echoData_MF_Right_short(1,:)),'k');title('左波束，短脉冲')% 绘制短脉冲右波束FIR滤波后的频谱
        subplot(224),plot(abs(echoData_MF_Right_long(1,:)),'k');title('右波束，长脉冲') % 绘制长脉冲右波束匹配滤波后的频谱
        
        figure(51), % 转换为分贝
        subplot(221),plot(20*log10(abs(echoData_MF_Left_short(1,:))),'k');title('左波束，短脉冲') % 绘制短脉冲左波束FIR滤波后的频谱（dB）
        subplot(222),plot(20*log10(abs(echoData_MF_Left_long(1,:))),'k');title('右波束，长脉冲')  % 绘制长脉冲左波束匹配滤波后的频谱（dB）
        subplot(223),plot(20*log10(abs(echoData_MF_Right_short(1,:))),'k');title('左波束，短脉冲')% 绘制短脉冲右波束FIR滤波后的频谱（dB）
        subplot(224),plot(20*log10(abs(echoData_MF_Right_long(1,:))),'k');title('右波束，长脉冲') % 绘制长脉冲右波束匹配滤波后的频谱（dB）
        
        % ------------------------ 选取要显示的脉冲信号进行脉冲压缩结果展示 -------------------------------
        prtShow = 50; % 选取第50个脉冲进行频谱和脉冲压缩结果展示
        strSho = strcat('帧号-',num2str(iFrame),',脉冲号-',num2str(prtShow-1));  % 生成显示的标题信息
        
        % ----------
        fScale_Fast = (-FFT_num/2:FFT_num/2-1)*fs/FFT_num;                      % 频轴       
        % figure,plot(fScale_Fast/1e6,abs(fftshift(echoData_FFT_Left_long(1,:))))
        % xlabel('频率(MHz)'),ylabel('幅度')        
        figure
        plot(fScale_Fast/1e6,20*log10(abs(fftshift(echoData_FFT_Left_long(prtShow,:)))))
        xlabel('频率(MHz)'),ylabel('幅度(dB)');
        title(strcat('回波频谱：',strSho));
        
        figure
        plot(fScale_Fast/1e6,20*log10(fftshift(abs(matchF2_fun))))
        xlabel('频率(MHz)'),ylabel('幅度(dB)')
        title('匹配滤波器参考信号的频谱')
                
        figure
        plot(20*log10(abs(echoData_MF_Left_long(prtShow,:))));
        xlabel('采样'),ylabel('幅度(dB)')
        title(strcat('脉压结果:',strSho))
        
        % ----------
        fScale_Fast1 = (0:FFT_num-1)*fs/FFT_num;
        figure
        plot(fScale_Fast1/1e6,20*log10(abs((echoData_FFT_Left_long(prtShow,:)))))
        xlabel('频率(MHz)'),ylabel('幅度(dB)');
        title(strcat('回波频谱：',strSho));
        
        figure
        plot(fScale_Fast1/1e6,20*log10((abs(matchF2_fun))))
        xlabel('频率(MHz)'),ylabel('幅度(dB)')
        title('匹配滤波器参考信号的频谱')
                
        figure,plot(20*log10(abs(echoData_MF_Left_long(prtShow,:))));
        xlabel('采样'),ylabel('幅度(dB)')
        title(strcat('脉压结果:',strSho))
    end
    
    %% MTD 动目标检测
    tic % 开始计时，计算 MTD 处理的时间
    
    % 对短脉冲和长脉冲数据进行 MTD 处理（多普勒 FFT 变换）
    echo_MTD_Left_short = fft(echoData_MF_Left_short.*mtdWh_short,mtd_FFT_num,1);
    echo_MTD_Right_short = fft(echoData_MF_Right_short.*mtdWh_short,mtd_FFT_num,1);
    
    echo_MTD_Left_long = fft(echoData_MF_Left_long.*mtdWh_long,mtd_FFT_num,1);
    echo_MTD_Right_long = fft(echoData_MF_Right_long.*mtdWh_long,mtd_FFT_num,1);
    
    % 计算短脉冲和长脉冲的回波信号总和（左右波束相加）
    echo_MTD_sum_short = abs(echo_MTD_Left_short)+abs(echo_MTD_Right_short);
    echo_MTD_sum_long = abs(echo_MTD_Left_long)+abs(echo_MTD_Right_long);
    
    % 计算短脉冲和长脉冲的差分（右波束 - 左波束）
    echo_MTD_diff_short = abs(echo_MTD_Right_short)-abs(echo_MTD_Left_short);
    echo_MTD_diff_long = abs(echo_MTD_Right_long)-abs(echo_MTD_Left_long);
    
    fprintf('MTD耗时：%f\n',toc) % 输出 MTD 处理的时间
    
    if plotFlag % 绘图 —— 可视化矩阵（多普勒频谱可视化）
        figure(52)     
        subplot(121)
        imagesc(echo_MTD_sum_short);
        title('短脉冲,MTD和矩阵')
        subplot(122)
        imagesc(echo_MTD_sum_long); 
        title('长脉冲,MTD和波束')
        
        figure(53)     
        subplot(121)
        imagesc(20*log10(echo_MTD_sum_short));
        title('短脉冲,MTD和矩阵')
        subplot(122)
        imagesc(20*log10(echo_MTD_sum_long)); 
        title('长脉冲,MTD和波束')   
        
        figure(54)
        subplot(121)
        imagesc(rScale_short,ifftshift(fScale),20*log10(fftshift(echo_MTD_sum_short,1)));    
        xlabel('距离(m)');ylabel('多普勒频率(Hz)');title('短脉冲,MTD和矩阵');
        subplot(122)
        imagesc(rScale_long,ifftshift(fScale),20*log10(fftshift(echo_MTD_sum_long,1))); 
        xlabel('距离(m)');
        ylabel('多普勒频率(Hz)');
        title('长脉冲,MTD和波束'); 
    end
    
    %% CFAR检测
    tic % 开始计算CFAR时间
    
    % 杂波扣除
    MTD_0_num = floor(MTD_V/deltaV);   % 计算需要清除的低速杂波区域的数量，这些区域对应的频率区间会被设置为 0，从而排除低速目标；floor用于向下取整
    zeroSetFlagMTD = [1:MTD_0_num+1, mtd_FFT_num-MTD_0_num+1:mtd_FFT_num]; % 生成杂波区域的索引，表示在频谱中需要被清除的杂波区域的索引
    echo_MTD_sum_short(zeroSetFlagMTD,:) = 0;                              % 清除短脉冲数据中杂波区域的值，将这些位置的值设为 0，排除低速目标。
    echo_MTD_sum_long(zeroSetFlagMTD,:) = 0;                               % 清除长脉冲数据中杂波区域的值，将这些位置的值设为 0，排除低速目标
    
    % 检测
    [cfarResultFlag_Matrix_short,cfarResultFlag_MatrixV_short] = executeCFAR(echo_MTD_sum_short,refCells_R,saveCells_R,...  
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 调用executeCFAR 函数做短脉冲CFAR
    
    [cfarResultFlag_Matrix_long,cfarResultFlag_MatrixV_long] = executeCFAR(echo_MTD_sum_long,refCells_R,saveCells_R,...
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 调用executeCFAR 函数做长脉冲CFAR
    
    if plotFlag
        figure(60)     
        subplot(121)
        imagesc(cfarResultFlag_Matrix_short);
        title('短脉冲,CFAR检测结果指示矩阵');
        subplot(122)
        imagesc(cfarResultFlag_Matrix_long);
        title('长脉冲,CFAR检测结果指示矩阵');  
    end

    fprintf('CFAR耗时：%f\n',toc)

    %% 距离、速度、角度参数的测量估计
    tic
    % 短脉冲
    [rEstSeries1,vEstSeries1,eleAngleEstSeries1] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_Matrix_short,extraDots,...
        rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);  
     
    % 长脉冲
    [rEstSeries2,vEstSeries2,eleAngleEstSeries2] = motionParaMeasure(echo_MTD_sum_long,echo_MTD_diff_long,cfarResultFlag_Matrix_long,extraDots,...
        rScale_long,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);
    
    fprintf('运动参数估计耗时：%f\n',toc)
    
    % 结果保存：将计算得到的结果保存到 resultEst_Struct 结构体中
    resultEst_Struct(frameNum).iFrame = iFrame;                          % 当前帧号
    resultEst_Struct(frameNum).rEstSeries1 = rEstSeries1;                % 短脉冲的距离估计序列
    resultEst_Struct(frameNum).vEstSeries1 = vEstSeries1;                % 短脉冲的速度估计序列
    resultEst_Struct(frameNum).eleAngleEstSeries1 = eleAngleEstSeries1;  % 短脉冲的俯仰角估计序列
    resultEst_Struct(frameNum).aziAngleEstSeries1 = [];                  % 短脉冲的方位角估计序列，未使用
    resultEst_Struct(frameNum).rEstSeries2 = rEstSeries2;                % 长脉冲的距离估计序列
    resultEst_Struct(frameNum).vEstSeries2 = vEstSeries2;                % 长脉冲的速度估计序列
    resultEst_Struct(frameNum).eleAngleEstSeries2 = eleAngleEstSeries2;  % 长脉冲的俯仰角估计序列
    resultEst_Struct(frameNum).aziAngleEstSeries2 = [];                  % 长脉冲的方位角估计序列，未使用
    resultEst_Struct(frameNum).angleCode = angleCode;                    % 存储角度编码
     
    % 短脉冲（没用上，因为 vCFARResult_Flag = 1）
    [rEstSeriesV1,vEstSeriesV1,eleAngleEstSeriesV1] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_MatrixV_short,extraDots,...
        rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);
    
    % 长脉冲（没用上，因为 vCFARResult_Flag = 1）
    [rEstSeriesV2,vEstSeriesV2,eleAngleEstSeriesV2] = motionParaMeasure(echo_MTD_sum_long,echo_MTD_diff_long,cfarResultFlag_MatrixV_long,extraDots,...
        rScale_long,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);
   
    % 结果保存（没用上，因为 vCFARResult_Flag = 1）
    resultEst_Struct(frameNum).iFrame = iFrame;
    resultEst_Struct(frameNum).rEstSeriesV1 = rEstSeriesV1;
    resultEst_Struct(frameNum).vEstSeriesV1 = vEstSeriesV1;
    resultEst_Struct(frameNum).eleAngleEstSeriesV1 = eleAngleEstSeriesV1;
    resultEst_Struct(frameNum).aziAngleEstSeriesV1 = [];
    resultEst_Struct(frameNum).rEstSeriesV2 = rEstSeriesV2;
    resultEst_Struct(frameNum).vEstSeriesV2 = vEstSeriesV2;
    resultEst_Struct(frameNum).eleAngleEstSeriesV2 = eleAngleEstSeriesV2;
    resultEst_Struct(frameNum).aziAngleEstSeriesV2 = [];
    
    %% 
    rEstSeries = [rEstSeries1;rEstSeries2];                         % 长短脉冲距离估计
    vEstSeries = [vEstSeries1;vEstSeries2];                         % 长短脉冲速度估计
    eleAngleEstSeries = [eleAngleEstSeries1;eleAngleEstSeries2];    % 长短脉冲角度估计
    
    if ~isempty(rEstSeries)
        estDataLen1 = length(rEstSeries);
        figure(70)
        subplot(131)
        hold on;
        scatter(iFrame*ones(estDataLen1,1),rEstSeries,'rs');
        xlabel('帧号');
        ylabel('测量距离(m)');
        box on;
        
        subplot(132)
        hold on;
        estDataLen2 = length(vEstSeries);
        scatter(iFrame*ones(estDataLen2,1),vEstSeries,'rs');
        xlabel('帧号');
        ylabel('测量速度(m/s)');
        box on;
        
        subplot(133)
        hold on;
        estDataLen3 = length(eleAngleEstSeries);
        scatter(iFrame*ones(estDataLen3,1),eleAngleEstSeries,'rs');
        xlabel('帧号');
        ylabel('测量俯仰角(degree)');
        box on;
    end
%     toc
end       % 一帧结束

close(hBar);



% GPS数据读取和显示
if dataGPSFileFlag
    [T_GPS,R_GPS_Radar,V_GPS_Radar,A_GPS,H_GPS] = GPSDataReadParse(GPSFileFullPath,GPSDataCols,START_LINE_GPS,LINE_NUM_GPS);
     
    frameTimeRadar = prt*prtNum;   % 雷达回波帧积累时间
    frameIndSerie = (T_GPS-T_GPS(1))/frameTimeRadar;
    frameIndGPS = frameIndSerie+framesShift;
        
    
    % 去除无效的GPS数值
    gpsInd1 = find(R_GPS_Radar ==0);
    gpsInd2 = find(V_GPS_Radar ==0);
    gpsInd3 = unique([gpsInd1;gpsInd2]);
    
    if ~isempty(gpsInd3)
        T_GPS(gpsInd3) = [];
        R_GPS_Radar(gpsInd3) = [];
        V_GPS_Radar(gpsInd3) = [];
        A_GPS(gpsInd3) = [];
        H_GPS(gpsInd3) = [];
        frameIndGPS(gpsInd3) = [];
    end
    
    
    
    figure(70)
    subplot(131)
    hold on;
    plot(frameIndGPS,R_GPS_Radar,'b->');
    
    subplot(132)
    hold on;
    plot(frameIndGPS,V_GPS_Radar,'b->');
    
end

%% 结果保存
if resultDataSaveFlag    
    resultFileDataName = strcat('resultData_',clockValueGet,'.mat');  %
    resultFileDataPath = fullfile('./detectResultData',resultFileDataName);
    save(resultFileDataPath,'orgDataFilePath','filter_coef','winType','MTD_win_TYPE','MTD_V',...
        'refCells_V','saveCells_V','T_CFAR_V','CFARmethod_V','refCells_R','saveCells_R','T_CFAR_R','CFARmethod_R',...
        'frameS','frameE','framesProcessTotal','rSysErr_short','rSysErr_long','extraDots',...
        'rInterpTimes','vInterpTimes','eleAngleComp','eleAngleSysErr','beamAngleStep','resultEst_Struct',...
        'vCFARResult_Flag','rCFARDetect_Flag','angleCodeSeries','rMeasureErr_short','rMeasureErr_long');
end



