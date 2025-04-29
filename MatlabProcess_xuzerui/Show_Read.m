function [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCode] = frameDataRead_A(orgDataFilePath,frameRInd)
%% 功能：读取一帧的数据, 有角码
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
%%
cj = sqrt(-1);
orgDataFilePath='C:\wangqinxuan\lss_data\PC_DATA\2\基带原始数据';
%%
% multiBeam = 1;   % 0-单波束； 1-多波束（两波束）
%% 文件大小参数
point_PRT = 1031;   % 每个PRT的采集点数
prtNum = 1536;     % 每帧信号的脉冲数据
bytesFrameHead = 24;       % 每个PRT帧头字节数
bytesFrameEnd = 8;         % 每个PRT帧尾字节数，1字节=8bit
bytesTotalEachFile = 190525440;    % 实际数据文件包含的总字节数

bytesTotalEachPRT = bytesFrameHead+bytesFrameEnd+12*point_PRT+4;    % 每个PRT数据总字节数,一个数据点8字节
bytesTotalEachFrame = bytesTotalEachPRT*prtNum;   % 每帧数据包含的总字节数

framesEachFile = 10;   % 每个新文件存储的帧数
%% 要读取的帧文件
frameRInd =25 ;  % 要显示的帧

% 计算该帧所在的数据文件编号
fileInd = fix((frameRInd-1)/framesEachFile)+1;  % 数据文件编号00000fileInd.bin

orgdataFileFullPath = dataFullPathGen(orgDataFilePath,fileInd);  % 数据文件全路径
%orgdataFileFullPath=00000fileInd.bin

% fprintf('第%d帧数据的存储数据文件编号：%d.\n',frameRInd,fileInd);

%% 读取帧文件
frameSkip = rem(frameRInd-1,framesEachFile);   % 在fileInd指示的文件中要跳过的帧数
dataFID = fopen(orgdataFileFullPath,'r');
fseek(dataFID, bytesTotalEachFrame*frameSkip,'bof');
echoData_Frame_Left = zeros(prtNum,point_PRT,'double');
echoData_Frame_Right = zeros(prtNum,point_PRT,'double');
% angleCodeSeries = [];
for i_prt = 1:prtNum
    
    % 跳过PRT传输内容的表头
    bagHead5 = fread(dataFID,1,'uint16');  % A5A5
    bagHead6 = fread(dataFID,1,'uint16');  % A5A5
        
    % 帧号
    frameInd1 = fread(dataFID,1,'uint16');  % 帧号 高位 2个字节
    frameInd2 = fread(dataFID,1,'uint16');  % 帧号 低位 2个字节
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
    
%%数据部分解析
            dataTemp = fread(dataFID,point_PRT*12,'uint8');  % 读取回波数据

            orgData_I_left3 = dataTemp(10:12:end);  % I路回波0
            orgData_Q_left3 = dataTemp(9:12:end);  % Q路回波0         
            orgData_I_right3 = dataTemp(12:12:end);  % I路回波0
            orgData_Q_right3 = dataTemp(11:12:end);  % Q路回波0
            
            orgData_I_left2 = dataTemp(6:12:end);  % I路回波1
            orgData_Q_left2 = dataTemp(5:12:end);  % Q路回波1            
            orgData_I_right2 = dataTemp(8:12:end);  % I路回波1
            orgData_Q_right2 = dataTemp(7:12:end);  % Q路回波1
            
            orgData_I_left1 = dataTemp(2:12:end);  % I路回波2
            orgData_Q_left1 = dataTemp(1:12:end);  % Q路回波2            
            orgData_I_right1 = dataTemp(4:12:end);  % I路回波2
            orgData_Q_right1 = dataTemp(3:12:end);  % Q路回波2
            
            orgData_I_left = dec2bin((orgData_I_left1*2^16+orgData_I_left2*2^8+orgData_I_left3),24);
            orgData_Q_left = dec2bin((orgData_Q_left1*2^16+orgData_Q_left2*2^8+orgData_Q_left3),24);
            orgData_I_right = dec2bin((orgData_I_right1*2^16+orgData_I_right2*2^8+orgData_I_right3),24);
            orgData_Q_right = dec2bin((orgData_Q_right1*2^16+orgData_Q_right2*2^8+orgData_Q_right3),24);
            
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
            
            echoData_Frame_Left(i_prt,:) = orgData_I_left0+cj*orgData_Q_left0;
            echoData_Frame_Right(i_prt,:) = orgData_I_right0+cj*orgData_Q_right0;  
            
            figure(15)
            
            subplot(221), plot(orgData_I_left0),title('左波束I路');
            subplot(222), plot(orgData_Q_left0),title('左波束-Q路');
            subplot(223), plot(orgData_I_right0),title('右波束I路');
            subplot(224), plot(orgData_Q_right0),title('右波束-Q路');
            
            %title(strcat('第',num2str(frameInd),'帧，第',num2str(i_prt-1),'%d脉冲回波'));
            fprintf('第%d帧，第%d脉冲回波\n',frameInd,prtInd);
            pause(0.05)
            
            
    
    fseek(dataFID, 8, 'cof');  % 跳过包尾信息，8个字节.
    
end
fclose(dataFID);