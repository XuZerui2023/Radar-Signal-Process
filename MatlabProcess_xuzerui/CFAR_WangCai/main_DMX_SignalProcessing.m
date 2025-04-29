%% DMX�źŴ���
% Date: 2018.04.11
% ��6kmģʽ�����ݽ����źŴ���

clear; close all

%% Define constant
cj = sqrt(-1);
c  =  2.99792458e8;       % ��Ų������ٶ�

PI2 = 2*pi;
MHz = 1e+6;     % frequency unit(MHz)
us  = 1e-6;     % time unit(us)
ns  = 1e-9;     % time unit(ns)
KHz = 1e+3;     % frequency unit(KHz)
GHz = 1e+9;     % frequency unit(GHz)

%% �ز������ļ�·������
orgDataSavePath = '.\';
orgDataFolderName = '2018��06��12��17ʱ40��29��';
orgDataSubFolderName = '����ԭʼ����';
% orgDataFilePath = fullfile(orgDataSavePath,orgDataFolderName,orgDataSubFolderName);
orgDataFilePath = 'G:\���ֻ�������';
fileTotalNums = 13;   % �����ļ�����
framesEachFile = 10;   % ÿ���ļ��洢������֡��

%% ϵͳ����
fs = 12.5*MHz;             % ������
ts = 1/fs;
deltaR = c*ts/2;

flag_Mode = 1;     % 1-����1
switch flag_Mode
    case 1  % ����1
        tao1  = 0.56*us;             % ����������
        tao2  = 5.04*us;             % ����������
        prt   = 52.08*us;
        prf   = 1/prt;
        B     = 10*MHz;             % ����
        K1    = B/tao1;             % �������Ƶб��
        K2    = B/tao2;             % �������Ƶб��
        % �����ļ���С����
        point_PRT = 566;   % ÿ��PRT�Ĳɼ�����
        prtNum = 1536;     % ÿ֡�źŵ���������
        point_short = 62;                          % ���������
        point_long = point_PRT-point_short;        % ���������
        FFT_num = 512;           % ��������ѹ����
        mtd_FFT_num = 2048;      % MTD����
    case 2
        
    otherwise
        
end
%% �źŴ����������
% -------------------  ����֡��Χ --------------------
frameS = 1;
frameE = 20;
if frameE>fileTotalNums*framesEachFile
    frameE = fileTotalNums*framesEachFile;
end
framesProcessTotal = frameE-frameS+1;    % Ҫ�������֡��

% -------------------  ��ѹ���� --------------------
% �����壺FIR�˲�����  �����壺��ѹ
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9];

% ����ѹ������
refDataFileFlag = 1;
rofPowerNorm = 1;     % �ο��ź�������һ��
if refDataFileFlag    % ʵ�ɲ�������
    load('refDDCDataMF1.mat')
    matchWaveform2 = refData.';
else   % ������沨������
    t2 = -tao2/2:ts:tao2/2-ts; 
    matchWaveform2 = exp(cj*pi*K2*t2.^2); % �˲���ʱ��
end

if rofPowerNorm
    matchWaveform2 = matchWaveform2/norm(matchWaveform2);
end

len2 = length(matchWaveform2);

winType = 3; % ����ѹ���Ӵ���1-hamming��2-hanning 3- kaiser; 4-blackman
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
matchF2_fun = conj(fft(matchWaveform2.*mfWh.',FFT_num)); % Ƶ��ƥ���˲���
matchF2_Matrix = repmat(matchF2_fun,prtNum,1);

% -------------------  MTD���� --------------------
MTD_win_TYPE = 1; % ��ʱ��γ�Ӵ���1-hamming��2-hanning 3- kaiser; 4-blackman
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

MTD_V = 1;    % �Ӳ����ٶȷ�Χ
% -------------------------- CFAR���� -------------------------------
% �ٶ�ά��
refCells_V = 5;    % �ٶ�ά �ο���Ԫ��
saveCells_V = 7;   % �ٶ�ά ������Ԫ��
T_CFAR_V = 7;      % �ٶ�ά���龯��ƻ�����
CFARmethod_V = 0;  % 0--ѡ��1--ѡС
% ����ά
rCFARDetect_Flag = 1;   % ����άCFAR��������־�� 0-�� 1-��
refCells_R = 5;    % ����ά �ο���Ԫ��
saveCells_R = 7;   % ����ά ������Ԫ��
T_CFAR_R = 7;      % ����ά���龯��ƻ�����
CFARmethod_R = 0;  % 0--ѡ��1--ѡС

% -------------------------- ϵͳ��� -------------------------------
rSysErr_short = 0;         % ����ϵͳ���
rSysErr_long = 62*12;
rMeasureErr_short = 297;
rMeasureErr_long = 92;

% -------------------------- ������ٶȲ������� -------------------------------
extraDots = 2;         % ��ֵʱʹ�õ����ݵ���
rInterpTimes = 8;      % ����ά��ֵ����
vInterpTimes = 4;      % �ٶ�ά��ֵ����

% ----------------------- ���S����Kֵ ---------------------------
eleAngleComp = 0;        % �ǶȲ���ֵ
eleAngleSysErr = 0;      % �Ƕ�ϵͳ���ֵ
beamAngleStep = 5;       % ���ڲ����ǶȲ�

sysNum = 2;
kValues = angle_KvalueGen(sysNum);  


%% ָ���ǲ���
northAngle = 29.01;
angleE1 = 5.9;

%% ���ݶ�ȡ�ʹ���
% ����ֵ�����ʼ��
hBar = waitbar(0,'Please wait...');
frameNum = 0;
angleCodeSeries = [];
for iFrame = frameS:frameE
%     
    % iFrame = 203;   % Ҫ�����֡��
    frameNum = frameNum+1;
    waitbar(frameNum/framesProcessTotal,hBar);
    
    % ---------------------------------- ��ȡ���� ---------------------------------
    % ��ȡһ֡������
    [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCode] = frameDataRead_A(orgDataFilePath,iFrame);
%     echoData_Frame_Left=echoData_Frame_Right=(1536,566)
    angleCode = rem(angleCode+northAngle+angleE1,360);   % �����Ƕ����
    angleCodeSeries = [angleCodeSeries,angleCode];
    
    fc = freValueGen(freInd);  % ��Ƶ
    lamda = c/fc;              % ����
    % ����
    rScale_short = (0:point_short-1)*deltaR+rSysErr_short-rMeasureErr_short;   % ������
    rScale_long = (0:FFT_num-1)*deltaR+rSysErr_long-rMeasureErr_long;   % ������
    
    % �ٶ�
    deltaDoppler = prf/mtd_FFT_num;
    deltaV = lamda*deltaDoppler/2;  
    fScale = fftshift((-mtd_FFT_num/2:mtd_FFT_num/2-1)*deltaDoppler);
    vScale = -lamda*fScale/2;
    
    % ---------------------------------- �����������ݲ𿪴��� ---------------------------------
    echoData_Frame_Left_short = echoData_Frame_Left(:,1:point_short);
    echoData_Frame_Left_long = echoData_Frame_Left(:,point_short+1:end);
    
    echoData_Frame_Right_short = echoData_Frame_Right(:,1:point_short);
    echoData_Frame_Right_long = echoData_Frame_Right(:,point_short+1:end);
    %% ����ѹ��
    % ---------------------------------- ����������FIR�˲� ---------------------------------
    echoData_MF_Left_short = filter(filter_coef,1,echoData_Frame_Left_short.').';
    echoData_MF_Right_short = filter(filter_coef,1,echoData_Frame_Right_short.').';
    
    % ---------------------------------- ������������ѹ�� ---------------------------------
    echoData_FFT_Left_long = fft(echoData_Frame_Left_long,FFT_num,2);
    echoData_FFT_Right_long = fft(echoData_Frame_Right_long,FFT_num,2);
    echoData_MF_Left_long = ifft(echoData_FFT_Left_long.*matchF2_Matrix,[],2);
    echoData_MF_Right_long = ifft(echoData_FFT_Right_long.*matchF2_Matrix,[],2);
    
    %% MTD
    echo_MTD_Left_short = fft(echoData_MF_Left_short.*mtdWh_short,mtd_FFT_num,1);
    echo_MTD_Right_short = fft(echoData_MF_Right_short.*mtdWh_short,mtd_FFT_num,1);
    
    echo_MTD_Left_long = fft(echoData_MF_Left_long.*mtdWh_long,mtd_FFT_num,1);
    echo_MTD_Right_long = fft(echoData_MF_Right_long.*mtdWh_long,mtd_FFT_num,1);
    
    % ��
    echo_MTD_sum_short = abs(echo_MTD_Left_short)+abs(echo_MTD_Right_short);
    echo_MTD_sum_long = abs(echo_MTD_Left_long)+abs(echo_MTD_Right_long);
    
    % ��
    echo_MTD_diff_short = abs(echo_MTD_Right_short)-abs(echo_MTD_Left_short);
    echo_MTD_diff_long = abs(echo_MTD_Right_long)-abs(echo_MTD_Left_long);
        
    %% CFAR���
    % �Ӳ��۳�
    MTD_0_num = floor(MTD_V/deltaV);    
    zeroSetFlagMTD = [1:MTD_0_num+1, mtd_FFT_num-MTD_0_num+1:mtd_FFT_num];
    echo_MTD_sum_short(zeroSetFlagMTD,:) = 0;
    echo_MTD_sum_long(zeroSetFlagMTD,:) = 0;
    
    % ���
    [cfarResultFlag_Matrix_short,cfarResultFlag_MatrixV_short] = executeCFAR(echo_MTD_sum_short,refCells_R,saveCells_R,...
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % ������
    
    [cfarResultFlag_Matrix_long,cfarResultFlag_MatrixV_long] = executeCFAR(echo_MTD_sum_long,refCells_R,saveCells_R,...
        T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % ������

    %% ���롢�ٶȡ��ǶȲ���
    % ������
    [rEstSeries1,vEstSeries1,eleAngleEstSeries1] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_Matrix_short,extraDots,...
        rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num);  
    
    % ������
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
        xlabel('֡��'),ylabel('��������(m)');box on
        
        subplot(132),hold on
        estDataLen2 = length(vEstSeries);
        scatter(iFrame*ones(estDataLen2,1),vEstSeries,'rs');
        xlabel('֡��'),ylabel('�����ٶ�(m/s)');box on
        
        subplot(133),hold on
        estDataLen3 = length(eleAngleEstSeries);
        scatter(iFrame*ones(estDataLen3,1),eleAngleEstSeries,'rs');
        xlabel('֡��'),ylabel('����������(degree)');box on
    end
end
close(hBar);




