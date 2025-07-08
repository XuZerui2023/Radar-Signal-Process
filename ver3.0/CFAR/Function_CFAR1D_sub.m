function [PeakDetectionoutput]=Function_CFAR1D_sub(datamatrix,refCellNum,saveCellNum,T_CFAR,CFARmethod)
% input:
% datamatrix: 待做CFAR的矩阵，
% refCellNum: 参考单元点数,
% saveCellNum:保护单元点数
% T_CFAR:检测门限
% CFARmethod;  % 0--选大；1--选小；
% output:
% PeakDetectionoutput：峰值点处有正值，其余都是0
%
% fuxiongjun, 2008-12-28. modified @2009-03-05
% Rui_W modified @2015-07-21

[RowNum_ASR,ColNum_ASR]=size(datamatrix);             
PeakDetectionoutput=zeros(RowNum_ASR,ColNum_ASR);     

for y=1:ColNum_ASR
    if CFARmethod==0
        refL_average=zeros(RowNum_ASR,1);  % 初始化
        refR_average=zeros(RowNum_ASR,1);  % 初始化
    else
        refL_average=Inf*ones(RowNum_ASR,1);  % 初始化
        refR_average=Inf*ones(RowNum_ASR,1);  % 初始化
    end
    refL1=y-(saveCellNum+refCellNum);% 左参考单元的左边界
    refL2=y-saveCellNum-1;           % 左参考单元的右边界
    refR1=y+saveCellNum+1;           % 右参考单元的左边界
    refR2=y+saveCellNum+refCellNum;  % 右参考单元的右边界
    
    if refL1>=1          
        refL_average=mean(datamatrix(:,refL1:refL2),2);  % 左参考单元的平均
    else % 左参考单元点数不够,则用检测点右边的数据估计杂波水平
        refL_average = mean(datamatrix(:,refR1:refR2),2);   
    end
    if refR2<=ColNum_ASR         
        refR_average=mean(datamatrix(:,refR1:refR2),2);    % 右参考单元的平均
    else  % 右参考单元点数不够,则用检测点左边的数据估计杂波水平
        refR_average=mean(datamatrix(:,refL1:refL2),2);
    end
    if CFARmethod==0
        ref_average_used=max(refL_average,refR_average);     % 选大    
    else
        ref_average_used=min(refL_average,refR_average);     % 选小
    end
    threshold_CFAR=ref_average_used.*T_CFAR;           % 生成门限 (DSP程序中，threshold_CFAR可只用一个变量，不必用数组.这里是方便测试）
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
    
    % 这里将会删掉许有效的检测点
    % flag3=datamatrix(:,y)>=[0;datamatrix(1:end-1,y)];
    % flag4=datamatrix(:,y)>=[datamatrix(2:end,y);0];    
    flag3 = 1;
    flag4 = 1;

    PeakDetectionoutput(:,y)=flag.*flag1.*flag2.*flag3.*flag4;
end






