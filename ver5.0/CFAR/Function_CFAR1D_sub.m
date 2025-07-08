function [PeakDetectionoutput]=Function_CFAR1D_sub(datamatrix,refCellNum,saveCellNum,T_CFAR,CFARmethod)
% input:
% datamatrix: ����CFAR�ľ���
% refCellNum: �ο���Ԫ����,
% saveCellNum:������Ԫ����
% T_CFAR:�������
% CFARmethod;  % 0--ѡ��1--ѡС��
% output:
% PeakDetectionoutput����ֵ�㴦����ֵ�����඼��0
%
% fuxiongjun, 2008-12-28. modified @2009-03-05
% Rui_W modified @2015-07-21

[RowNum_ASR,ColNum_ASR]=size(datamatrix);             
PeakDetectionoutput=zeros(RowNum_ASR,ColNum_ASR);     

for y=1:ColNum_ASR
    if CFARmethod==0
        refL_average=zeros(RowNum_ASR,1);  % ��ʼ��
        refR_average=zeros(RowNum_ASR,1);  % ��ʼ��
    else
        refL_average=Inf*ones(RowNum_ASR,1);  % ��ʼ��
        refR_average=Inf*ones(RowNum_ASR,1);  % ��ʼ��
    end
    refL1=y-(saveCellNum+refCellNum);% ��ο���Ԫ����߽�
    refL2=y-saveCellNum-1;           % ��ο���Ԫ���ұ߽�
    refR1=y+saveCellNum+1;           % �Ҳο���Ԫ����߽�
    refR2=y+saveCellNum+refCellNum;  % �Ҳο���Ԫ���ұ߽�
    
    if refL1>=1          
        refL_average=mean(datamatrix(:,refL1:refL2),2);  % ��ο���Ԫ��ƽ��
    else % ��ο���Ԫ��������,���ü����ұߵ����ݹ����Ӳ�ˮƽ
        refL_average = mean(datamatrix(:,refR1:refR2),2);   
    end
    if refR2<=ColNum_ASR         
        refR_average=mean(datamatrix(:,refR1:refR2),2);    % �Ҳο���Ԫ��ƽ��
    else  % �Ҳο���Ԫ��������,���ü�����ߵ����ݹ����Ӳ�ˮƽ
        refR_average=mean(datamatrix(:,refL1:refL2),2);
    end
    if CFARmethod==0
        ref_average_used=max(refL_average,refR_average);     % ѡ��    
    else
        ref_average_used=min(refL_average,refR_average);     % ѡС
    end
    threshold_CFAR=ref_average_used.*T_CFAR;           % �������� (DSP�����У�threshold_CFAR��ֻ��һ������������������.�����Ƿ�����ԣ�
    flag=datamatrix(:,y)>=threshold_CFAR;

    %     if y==1
    %         flag1=ones(RowNum_ASR,1);
    %     else
    %         flag1=datamatrix(:,y)>=datamatrix(:,y-1);
    %     end
    %
    %     if y==ColNum_ASR
    %         flag2=ones(RowNum_ASR,1);
    %     else
    %         flag2=datamatrix(:,y)>=datamatrix(:,y+1);
    %     end
    flag1 = 1;
    flag2 = 1;
    
    % ���ｫ��ɾ������Ч�ļ���
    % flag3=datamatrix(:,y)>=[0;datamatrix(1:end-1,y)];
    % flag4=datamatrix(:,y)>=[datamatrix(2:end,y);0];    
    flag3 = 1;
    flag4 = 1;

    PeakDetectionoutput(:,y)=flag.*flag1.*flag2.*flag3.*flag4;
end






