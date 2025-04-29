%% ���ܣ��Ӷ�����bin�ļ��ж�ȡ�ز��ź�������һ֡������, �н���
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

function [echoData_Frame_Left,echoData_Frame_Right,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCodeSeries] = frameDataRead_A(orgDataFilePath,frameRInd,prtNum)
%% �Ӻ��������ã������Կ�ע��
%frameRInd =1 ;    % Ҫ��ʾ��֡
% orgDataFilePath='G:\20220420�����¥�������źŲɼ�\2\2022��04��20��10ʱ52��09��\����ԭʼ����\bin'; % ������ԭʼ�ļ��洢·��
% prtNum = 1536;   % ��������
% frameRInd =1 ;   % Ҫ��ʾ��֡
% multiBeam = 1;   % 0-�������� 1-�ನ������������

%% �ļ���С�������ã���ʵ�ʲ������״����ƺ��ź�����������
cj = sqrt(-1);                     % ����������λ
point_PRT = 1031;                  % ����ÿ��PRT�еĲɼ�����
 
bytesFrameHead = 24;               % ÿ��PRT֡ͷ�ֽ���
bytesFrameEnd = 8;                 % ÿ��PRT֡β�ֽ�����1�ֽ�=8bit
bytesTotalEachFile = 190525440;    % ʵ�������ļ����������ֽ���

bytesTotalEachPRT = bytesFrameHead + bytesFrameEnd + 12 * point_PRT + 4;   % ÿ��PRT�������ֽ���,һ�����ݵ�8�ֽ�
bytesTotalEachFrame = bytesTotalEachPRT*prtNum;                            % ÿ֡���ݰ��������ֽ���

framesEachFile = 10;                                                       % ÿ��bin�ļ��洢��֡��

%% Ҫ��ȡ��֡�ļ�
%frameRInd =1 ;  % Ҫ��ʾ��֡

% �����֡���ڵ������ļ����
fileInd = fix((frameRInd-1)/framesEachFile)+1;                    % �����ļ����(�ļ�ȫ��)Ϊ 00000fileInd.bin �� orgdataFileFullPath=00000fileInd.bin
orgdataFileFullPath = dataFullPathGen(orgDataFilePath, fileInd);  % �����ļ�ȫ·��

fprintf('��%d֡���ݵĴ洢�����ļ�����ǣ�%d\n',frameRInd,fileInd);

%% ��ȡ֡�ļ�
frameSkip = rem(frameRInd-1,framesEachFile);                      % ��fileIndָʾ���ļ���Ҫ������֡��
dataFID = fopen(orgdataFileFullPath,'r');                         % �򿪶������ļ�
%fseek(dataFID, bytesTotalEachFrame*frameSkip,'bof');
echoData_Frame_Left = zeros(prtNum,point_PRT,'double');           % ��ʼ������һ֡�����ݾ���
echoData_Frame_Right = zeros(prtNum,point_PRT,'double');          % ��ʼ���Ҳ���һ֡�����ݾ���
angleCodeSeries = zeros(1,prtNum,'double');                       % ��ʼ���Ǳ�����������

for i_prt =1:prtNum
    
    % ����PRT�������ݵı�ͷ
    bagHead5 = fread(dataFID,1,'uint16');    % A5A5��ʮ���Ʊ�ʾ��42405������ȡ2�ֽڵ�����֡��ͷ����ʶ��������ȷ�����ݰ�����ʼλ��
    bagHead6 = fread(dataFID,1,'uint16');    % A5A5��ʮ���Ʊ�ʾ��42405������ȡ2�ֽڵ�����֡��ͷ����ʶ��������ȷ�����ݰ�����ʼλ��
        
    % ֡��
    frameInd1 = fread(dataFID,1,'uint16');   % ֡�� ��λ 2���ֽ�
    frameInd2 = fread(dataFID,1,'uint16');   % ֡�� ��λ 2���ֽ�
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
    angleCodeSeries(i_prt)=angleCode;

  
    % ���ݲ��ֽ������Ӷ����������ļ��ж�ȡһ֡�״�ز����ݣ������� I/Q ·����
            
            dataTemp = fread(dataFID,point_PRT*12,'uint8');  % ��ȡ�ز�����

            orgData_I_left3 = dataTemp(10:12:end);  % I·�ز�0������I·��λ �� 10 ���ֽڿ�ʼ��ÿ�� 12 ���ֽ�ȡһ�����ݣ������� 10 ���ֽ��ǵ� 1 ����� I ·��λ���� 22 ���ֽ��ǵ� 2 ����� I ·��λ�������Դ����ơ�
            orgData_Q_left3 = dataTemp(9:12:end);   % Q·�ز�0������Q·��λ         
            orgData_I_right3 = dataTemp(12:12:end); % I·�ز�0���Ҳ���I·��λ
            orgData_Q_right3 = dataTemp(11:12:end); % Q·�ز�0���Ҳ���Q·��λ
            
            orgData_I_left2 = dataTemp(6:12:end);   % I·�ز�1������I·��λ
            orgData_Q_left2 = dataTemp(5:12:end);   % Q·�ز�1������Q·��λ           
            orgData_I_right2 = dataTemp(8:12:end);  % I·�ز�1���Ҳ���I·��λ
            orgData_Q_right2 = dataTemp(7:12:end);  % Q·�ز�1���Ҳ���Q·��λ
            
            orgData_I_left1 = dataTemp(2:12:end);   % I·�ز�2������I·��λ
            orgData_Q_left1 = dataTemp(1:12:end);   % Q·�ز�2������Q·��λ           
            orgData_I_right1 = dataTemp(4:12:end);  % I·�ز�2���Ҳ���I·��λ
            orgData_Q_right1 = dataTemp(3:12:end);  % Q·�ز�2���Ҳ���Q·��λ
            
            orgData_I_left = dec2bin((orgData_I_left1*2^16+orgData_I_left2*2^8+orgData_I_left3),24);      % ���е�λ���Ϊ����I·
            orgData_Q_left = dec2bin((orgData_Q_left1*2^16+orgData_Q_left2*2^8+orgData_Q_left3),24);      % ���е�λ���Ϊ����Q·
            orgData_I_right = dec2bin((orgData_I_right1*2^16+orgData_I_right2*2^8+orgData_I_right3),24);  % ���е�λ���Ϊ�Ҳ���I·
            orgData_Q_right = dec2bin((orgData_Q_right1*2^16+orgData_Q_right2*2^8+orgData_Q_right3),24);  % ���е�λ���Ϊ�Ҳ���Q·
            
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
            
            echoData_Frame_Left(i_prt,:) = orgData_I_left0+cj*orgData_Q_left0;     % ���Ϊ��������I/Q�ź�
            echoData_Frame_Right(i_prt,:) = orgData_I_right0+cj*orgData_Q_right0;  % ���Ϊ�Ҳ�������I/Q�ź�
            
            % ÿ֡ÿprt�ź����Ҳ���ͼƬ��ʾ������Ӱ�촦��ʱ�䣬����ע�͵� 
            % figure(15)             
            % 
            % subplot(221), plot(orgData_I_left0),title('����I·');
            % subplot(222), plot(orgData_Q_left0),title('����-Q·');
            % subplot(223), plot(orgData_I_right0),title('�Ҳ���I·');
            % subplot(224), plot(orgData_Q_right0),title('�Ҳ���-Q·');
            % 
            % %title(strcat('��',num2str(frameRInd),'֡����',num2str(i_prt-1),'%d����ز�'));
            % fprintf('��%d֡����%d����ز�\n',frameInd,prtInd);
            % pause(0.000001)
            
    fseek(dataFID, 8, 'cof');  % ������β��Ϣ��8���ֽ�.
end

fclose(dataFID); 