function [PeakDetectionoutput]=Function_CFAR1D_sub_fixCells(datamatrix,refCellNum,saveCellNum,T_CFAR,CFARmethod, rowCellsFix, colCellsFix)
% input:
%     datamatrix: ����CFAR�ľ��󣬶������ݽ��м��
%     refCellNum: �ο���Ԫ����,
%     saveCellNum:������Ԫ����
%     T_CFAR:���������ϵ��
%     CFARmethod;  % 0--ѡ��1--ѡС
%     rowCellsFix: ָ��Ҫ������е�����ֵ
%     colCellsFix��Ҫ���м��Ĳ�����Ԫ������
% output:
%   ��PeakDetectionoutput���������޵ĵط�Ϊ�������඼��0
%
% fuxiongjun, 2008-12-28. modified @2009-03-05
% Rui_W modified @2015-07-21
% CaiW  modified @2016.05.16����Function_CFAR1D_sub.m�������ϣ��Լ��ָ����Ԫ���м��

[RowNum_ASR,ColNum_ASR] = size(datamatrix);             
PeakDetectionoutput = zeros(RowNum_ASR,ColNum_ASR);     

len1 = length(rowCellsFix); % Ҫ�������������  len1<=RowNum_ASR
len2 = length(colCellsFix);  % Ҫ���ĵ�Ԫ len2<=ColNum_ASR

for ii = 1:len2
    y = colCellsFix(ii);
    
    if CFARmethod==0
        refL_average = zeros(len1,1);  % ��ʼ��
        refR_average = zeros(len1,1);  % ��ʼ��
    else
        refL_average = Inf*ones(len1,1);  % ��ʼ��
        refR_average = Inf*ones(len1,1);  % ��ʼ��
    end
    
    refL1 = y-(saveCellNum+refCellNum);% ��ο���Ԫ����߽�
    refL2 = y-saveCellNum-1;           % ��ο���Ԫ���ұ߽�
    refR1 = y+saveCellNum+1;           % �Ҳο���Ԫ����߽�
    refR2 = y+saveCellNum+refCellNum;  % �Ҳο���Ԫ���ұ߽�
    
    if refL1>=1              % ��ο���Ԫ�����������򶼲���
        refL_average = mean(datamatrix(rowCellsFix,refL1:refL2),2);  % ��ο���Ԫ��ƽ��
	else % ��ο���Ԫ��������,�����ұߵ�
        refL_average = mean(datamatrix(rowCellsFix,refR1:refR2),2);  
    end    
    if refR2<=ColNum_ASR         % �Ҳο���Ԫ�����������򶼲���
        refR_average = mean(datamatrix(rowCellsFix,refR1:refR2),2);    % �Ҳο���Ԫ��ƽ��
	else  % �Ҳο���Ԫ��������,������ߵ�
        refR_average = mean(datamatrix(rowCellsFix,refL1:refL2),2);
    end
        
    if CFARmethod==0
        ref_average_used = max(refL_average,refR_average);     % ѡ��    
    else
        ref_average_used = min(refL_average,refR_average);     % ѡС
    end
    threshold_CFAR = ref_average_used.*T_CFAR;           % �������� (DSP�����У�threshold_CFAR��ֻ��һ������������������.�����Ƿ�����ԣ�
    
    % flag=datamatrix(:,y)>=threshold_CFAR;
    flag = datamatrix(rowCellsFix,y)>=threshold_CFAR;   
    
%     if y==1 
%         flag1 = ones(len1,1);
%     else
%         flag1 = datamatrix(rowCellsFix,y)>=datamatrix(rowCellsFix,y-1);     % �����ݵķ�ֵ�б�
%     end
% 
%     if y==ColNum_ASR
%         flag2 = ones(len1,1);
%     else
%         flag2 = datamatrix(rowCellsFix,y)>=datamatrix(rowCellsFix,y+1);  % �����ݵķ�ֵ�б�
%     end
% 
% %     flag3_1 = datamatrix(:,y)>=[0;datamatrix(2:end,y)];
%     flag3_1 = datamatrix(:,y)>=[0;datamatrix(1:end-1,y)];   % �����ݵķ�ֵ�б�
%     flag3 = flag3_1(rowCellsFix);
%     
% %     flag4_1 = datamatrix(:,y)>=[datamatrix(1:end-1,y);0];
%     flag4_1 = datamatrix(:,y)>=[datamatrix(2:end,y);0];      % �����ݵķ�ֵ�б�
%     flag4 = flag4_1(rowCellsFix);

flag1 = 1;
flag2 = 1;
flag3 = 1;
flag4 = 1;

    PeakDetectionoutput(rowCellsFix,y)=flag.*flag1.*flag2.*flag3.*flag4;

end






