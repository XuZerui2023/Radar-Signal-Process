function [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCode] = frameDataRead_A(orgDataFilePath,frameRInd)
%% ���ܣ���ȡһ֡������, �н���
% ���룺
%     frameRInd�� ��Ҫ�����֡���
% �����
%     echoData_Frame_Left: ����һ֡����, �߲�λ����
%     echoData_Frame_Right: ����һ֡����, �Ͳ�λ����
%     frameInd:    ֡��
%     modFlag:     ����ģʽ, 2���ֽ�.1-����1�� 9-�ز�ģ��
%     beamPosNum:  ��λ�ţ� 1���ֽ�. 0~10(11����λ)
%     beamNums:    ��ֵΪ�� ˫����-2
%     freInd:      ��ǰƵ��, 2���ֽ�. F1~F11
%     prtInd:      PRT��, 2���ֽڡ�
%     angleCode��  �Ǳ���
%%
cj = sqrt(-1);
orgDataFilePath='C:\wangqinxuan\lss_data\PC_DATA\2\����ԭʼ����';
%%
% multiBeam = 1;   % 0-�������� 1-�ನ������������
%% �ļ���С����
point_PRT = 1031;   % ÿ��PRT�Ĳɼ�����
prtNum = 1536;     % ÿ֡�źŵ���������
bytesFrameHead = 24;       % ÿ��PRT֡ͷ�ֽ���
bytesFrameEnd = 8;         % ÿ��PRT֡β�ֽ�����1�ֽ�=8bit
bytesTotalEachFile = 190525440;    % ʵ�������ļ����������ֽ���

bytesTotalEachPRT = bytesFrameHead+bytesFrameEnd+12*point_PRT+4;    % ÿ��PRT�������ֽ���,һ�����ݵ�8�ֽ�
bytesTotalEachFrame = bytesTotalEachPRT*prtNum;   % ÿ֡���ݰ��������ֽ���

framesEachFile = 10;   % ÿ�����ļ��洢��֡��
%% Ҫ��ȡ��֡�ļ�
frameRInd =25 ;  % Ҫ��ʾ��֡

% �����֡���ڵ������ļ����
fileInd = fix((frameRInd-1)/framesEachFile)+1;  % �����ļ����00000fileInd.bin

orgdataFileFullPath = dataFullPathGen(orgDataFilePath,fileInd);  % �����ļ�ȫ·��
%orgdataFileFullPath=00000fileInd.bin

% fprintf('��%d֡���ݵĴ洢�����ļ���ţ�%d.\n',frameRInd,fileInd);

%% ��ȡ֡�ļ�
frameSkip = rem(frameRInd-1,framesEachFile);   % ��fileIndָʾ���ļ���Ҫ������֡��
dataFID = fopen(orgdataFileFullPath,'r');
fseek(dataFID, bytesTotalEachFrame*frameSkip,'bof');
echoData_Frame_Left = zeros(prtNum,point_PRT,'double');
echoData_Frame_Right = zeros(prtNum,point_PRT,'double');
% angleCodeSeries = [];
for i_prt = 1:prtNum
    
    % ����PRT�������ݵı�ͷ
    bagHead5 = fread(dataFID,1,'uint16');  % A5A5
    bagHead6 = fread(dataFID,1,'uint16');  % A5A5
        
    % ֡��
    frameInd1 = fread(dataFID,1,'uint16');  % ֡�� ��λ 2���ֽ�
    frameInd2 = fread(dataFID,1,'uint16');  % ֡�� ��λ 2���ֽ�
    frameInd = frameInd1*2^16+frameInd2;
    
    % ����ģʽ
    modFlag = fread(dataFID,1,'uint16');     % ����ģʽ, 2���ֽ�.1-����1�� 9-�ز�ģ��
    beamPosNum = fread(dataFID,1,'uint8');   % ��λ�ţ� 1���ֽ�. 0~10(11����λ)
    beamNums = fread(dataFID,1,'uint8');     % ��ֵΪ�� ˫����-2
    
    freInd = fread(dataFID,1,'uint16');      % ��ǰƵ��, 2���ֽ�. F0~F20(21��)
    prtInd = fread(dataFID,1,'uint16');      % PRT��, 2���ֽڡ� 0~4095
    
    % �Ǳ���    
    fseek(dataFID, 10, 'cof'); 
    % angleCode = fread(dataFID,1,'uint16')/10;  % ��
    angleCode1 = fread(dataFID,1,'uint8'); 
    angleCode2 = fread(dataFID,1,'uint8')*2^7; 
    angleCode = (angleCode1+angleCode2)*360/16384;
    
%%���ݲ��ֽ���
            dataTemp = fread(dataFID,point_PRT*12,'uint8');  % ��ȡ�ز�����

            orgData_I_left3 = dataTemp(10:12:end);  % I·�ز�0
            orgData_Q_left3 = dataTemp(9:12:end);  % Q·�ز�0         
            orgData_I_right3 = dataTemp(12:12:end);  % I·�ز�0
            orgData_Q_right3 = dataTemp(11:12:end);  % Q·�ز�0
            
            orgData_I_left2 = dataTemp(6:12:end);  % I·�ز�1
            orgData_Q_left2 = dataTemp(5:12:end);  % Q·�ز�1            
            orgData_I_right2 = dataTemp(8:12:end);  % I·�ز�1
            orgData_Q_right2 = dataTemp(7:12:end);  % Q·�ز�1
            
            orgData_I_left1 = dataTemp(2:12:end);  % I·�ز�2
            orgData_Q_left1 = dataTemp(1:12:end);  % Q·�ز�2            
            orgData_I_right1 = dataTemp(4:12:end);  % I·�ز�2
            orgData_Q_right1 = dataTemp(3:12:end);  % Q·�ز�2
            
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
            
            subplot(221), plot(orgData_I_left0),title('����I·');
            subplot(222), plot(orgData_Q_left0),title('����-Q·');
            subplot(223), plot(orgData_I_right0),title('�Ҳ���I·');
            subplot(224), plot(orgData_Q_right0),title('�Ҳ���-Q·');
            
            %title(strcat('��',num2str(frameInd),'֡����',num2str(i_prt-1),'%d����ز�'));
            fprintf('��%d֡����%d����ز�\n',frameInd,prtInd);
            pause(0.05)
            
            
    
    fseek(dataFID, 8, 'cof');  % ������β��Ϣ��8���ֽ�.
    
end
fclose(dataFID);