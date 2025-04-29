%% 功能：从二进制bin文件中读取回波信号数据中一帧的数据, 有角码
% 输入：
%     frameRInd： 需要处理的帧编号
% 输出：
%     echoData_Frame_Left: 左波束一帧数据, 高波位数据
%     echoData_Frame_Right: 左波束一帧数据, 低波位数据
%     frameInd:    帧号
%     modFlag:     工作模式, 2个字节.1-波形1； 9-回波模拟
%     beamPosNum:  波位号， 1个字节. 0~10(11个波位)
%     beamNums:    数值为： 双波束-2
%     freInd:      当前频率, 2个字节. F1~F11
%     prtInd:      PRT号, 2个字节。
%     angleCode：  角编码

function [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCodeSeries] = frameDataRead_A(orgDataFilePath,frameRInd,prtNum)
%% 子函数测试用，不测试可注释
%frameRInd =1 ;    % 要显示的帧
% orgDataFilePath='G:\20220420气象局楼顶基带信号采集\2\2022年04月20日10时52分09秒\基带原始数据\bin'; % 二进制原始文件存储路径
% prtNum = 1536;   % 脉冲数量
% frameRInd =1 ;   % 要显示的帧
% multiBeam = 1;   % 0-单波束； 1-多波束（两波束）

%% 文件大小参数设置（由实际采样的雷达体制和信号特征决定）
cj = sqrt(-1);                     % 定义虚数单位
point_PRT = 1031;                  % 定义每个PRT中的采集点数
 
bytesFrameHead = 24;               % 每个PRT帧头字节数
bytesFrameEnd = 8;                 % 每个PRT帧尾字节数，1字节=8bit
bytesTotalEachFile = 190525440;    % 实际数据文件包含的总字节数

bytesTotalEachPRT = bytesFrameHead + bytesFrameEnd + 12 * point_PRT + 4;   % 每个PRT数据总字节数,一个数据点8字节
bytesTotalEachFrame = bytesTotalEachPRT*prtNum;                            % 每帧数据包含的总字节数

framesEachFile = 10;                                                       % 每个bin文件存储的帧数

%% 要读取的帧文件
%frameRInd =1 ;  % 要显示的帧

% 计算该帧所在的数据文件编号
fileInd = fix((frameRInd-1)/framesEachFile)+1;                    % 数据文件编号(文件全名)为 00000fileInd.bin 即 orgdataFileFullPath=00000fileInd.bin
orgdataFileFullPath = dataFullPathGen(orgDataFilePath, fileInd);  % 数据文件全路径

fprintf('第%d帧数据的存储数据文件编号是：%d\n',frameRInd,fileInd);

%% 读取帧文件
frameSkip = rem(frameRInd-1,framesEachFile);                      % 在fileInd指示的文件中要跳过的帧数
dataFID = fopen(orgdataFileFullPath,'r');                         % 打开二进制文件
%fseek(dataFID, bytesTotalEachFrame*frameSkip,'bof');
echoData_Frame_Left = zeros(prtNum,point_PRT,'double');           % 初始化左波束一帧的数据矩阵
echoData_Frame_Right = zeros(prtNum,point_PRT,'double');          % 初始化右波束一帧的数据矩阵
angleCodeSeries = zeros(1,prtNum,'double');                       % 初始化角编码序列向量

for i_prt =1:prtNum
    
    % 跳过PRT传输内容的表头
    bagHead5 = fread(dataFID,1,'uint16');    % A5A5（十进制表示是42405），读取2字节的数据帧的头部标识符，用于确认数据包的起始位置
    bagHead6 = fread(dataFID,1,'uint16');    % A5A5（十进制表示是42405），读取2字节的数据帧的头部标识符，用于确认数据包的起始位置
        
    % 帧号
    frameInd1 = fread(dataFID,1,'uint16');   % 帧号 高位 2个字节
    frameInd2 = fread(dataFID,1,'uint16');   % 帧号 低位 2个字节
    frameInd = frameInd1*2^16+frameInd2;
    
    % 工作模式
    modFlag = fread(dataFID,1,'uint16');     % 工作模式, 2个字节.1-波形1； 9-回波模拟
    beamPosNum = fread(dataFID,1,'uint8');   % 波位号， 1个字节. 0~10(11个波位)
    beamNums = fread(dataFID,1,'uint8');     % 数值为： 双波束-2
    
    freInd = fread(dataFID,1,'uint16');      % 当前频率, 2个字节. F0~F20(21个)
    prtInd = fread(dataFID,1,'uint16');      % PRT号, 2个字节。 0~4095
    
    % 角编码    
    fseek(dataFID, 10, 'cof'); 
    % angleCode = fread(dataFID,1,'uint16')/10;  % 度
    angleCode1 = fread(dataFID,1,'uint8'); 
    angleCode2 = fread(dataFID,1,'uint8')*2^7; 
    angleCode = (angleCode1+angleCode2)*360/16384;
    angleCodeSeries(i_prt)=angleCode;

  
    % 数据部分解析：从二进制数据文件中读取一帧雷达回波数据，并解析 I/Q 路数据
            
            dataTemp = fread(dataFID,point_PRT*12,'uint8');  % 读取回波数据

            orgData_I_left3 = dataTemp(10:12:end);  % I路回波0，左波束I路高位 第 10 个字节开始，每隔 12 个字节取一个数据，即：第 10 个字节是第 1 个点的 I 路高位；第 22 个字节是第 2 个点的 I 路高位；……以此类推。
            orgData_Q_left3 = dataTemp(9:12:end);   % Q路回波0，左波束Q路高位         
            orgData_I_right3 = dataTemp(12:12:end); % I路回波0，右波束I路高位
            orgData_Q_right3 = dataTemp(11:12:end); % Q路回波0，右波束Q路高位
            
            orgData_I_left2 = dataTemp(6:12:end);   % I路回波1，左波束I路中位
            orgData_Q_left2 = dataTemp(5:12:end);   % Q路回波1，左波束Q路中位           
            orgData_I_right2 = dataTemp(8:12:end);  % I路回波1，右波束I路中位
            orgData_Q_right2 = dataTemp(7:12:end);  % Q路回波1，右波束Q路中位
            
            orgData_I_left1 = dataTemp(2:12:end);   % I路回波2，左波束I路低位
            orgData_Q_left1 = dataTemp(1:12:end);   % Q路回波2，左波束Q路低位           
            orgData_I_right1 = dataTemp(4:12:end);  % I路回波2，右波束I路低位
            orgData_Q_right1 = dataTemp(3:12:end);  % Q路回波2，右波束Q路低位
            
            orgData_I_left = dec2bin((orgData_I_left1*2^16+orgData_I_left2*2^8+orgData_I_left3),24);      % 高中低位组合为左波束I路
            orgData_Q_left = dec2bin((orgData_Q_left1*2^16+orgData_Q_left2*2^8+orgData_Q_left3),24);      % 高中低位组合为左波束Q路
            orgData_I_right = dec2bin((orgData_I_right1*2^16+orgData_I_right2*2^8+orgData_I_right3),24);  % 高中低位组合为右波束I路
            orgData_Q_right = dec2bin((orgData_Q_right1*2^16+orgData_Q_right2*2^8+orgData_Q_right3),24);  % 高中低位组合为右波束Q路
            
            orgData_I_left0=zeros(point_PRT,1);
            orgData_Q_left0=zeros(point_PRT,1);
            orgData_I_right0=zeros(point_PRT,1);
            orgData_Q_right0=zeros(point_PRT,1);
           
            for i = 1:point_PRT
                    orgData_I_left0(i)=bin2dec(orgData_I_left(i,:));
                    if(orgData_I_left0(i)>2^23)
                        orgData_I_left0(i)=bin2dec(orgData_I_left(i,:))-2^24;
                    end
                    
                    orgData_Q_left0(i)=bin2dec(orgData_Q_left(i,:));
                    if(orgData_Q_left0(i)>2^23)
                        orgData_Q_left0(i)=bin2dec(orgData_Q_left(i,:))-2^24;
                    end
                    
                    orgData_I_right0(i)=bin2dec(orgData_I_right(i,:));
                    if(orgData_I_right0(i)>2^23)
                        orgData_I_right0(i)=bin2dec(orgData_I_right(i,:))-2^24;
                    end
                    
                    orgData_Q_right0(i)=bin2dec(orgData_Q_right(i,:));
                    if(orgData_Q_right0(i)>2^23)
                        orgData_Q_right0(i)=bin2dec(orgData_Q_right(i,:))-2^24;
                    end
            end
            
            echoData_Frame_Left(i_prt,:) = orgData_I_left0+cj*orgData_Q_left0;     % 组合为左波束复数I/Q信号
            echoData_Frame_Right(i_prt,:) = orgData_I_right0+cj*orgData_Q_right0;  % 组合为右波束复数I/Q信号
            
            % 每帧每prt信号左右波束图片显示，极大影响处理时间，建议注释掉 
            % figure(15)             
            % 
            % subplot(221), plot(orgData_I_left0),title('左波束I路');
            % subplot(222), plot(orgData_Q_left0),title('左波束-Q路');
            % subplot(223), plot(orgData_I_right0),title('右波束I路');
            % subplot(224), plot(orgData_Q_right0),title('右波束-Q路');
            % 
            % %title(strcat('第',num2str(frameRInd),'帧，第',num2str(i_prt-1),'%d脉冲回波'));
            % fprintf('第%d帧，第%d脉冲回波\n',frameInd,prtInd);
            % pause(0.000001)
            
    fseek(dataFID, 8, 'cof');  % 跳过包尾信息，8个字节.
end

fclose(dataFID); 