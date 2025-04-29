function [PeakDetectionoutput]=Function_CFAR1D_sub_fixCells(datamatrix,refCellNum,saveCellNum,T_CFAR,CFARmethod, rowCellsFix, colCellsFix)
% input:
%     datamatrix: 待做CFAR的矩阵，对行数据进行检测
%     refCellNum: 参考单元点数,
%     saveCellNum:保护单元点数
%     T_CFAR:　检测门限系数
%     CFARmethod;  % 0--选大；1--选小
%     rowCellsFix: 指定要处理的行的索引值
%     colCellsFix：要进行检测的采样单元的索引
% output:
%   　PeakDetectionoutput：大于门限的地方为１，其余都是0
%
% fuxiongjun, 2008-12-28. modified @2009-03-05
% Rui_W modified @2015-07-21
% CaiW  modified @2016.05.16　在Function_CFAR1D_sub.m　基础上，对检测指定单元进行检测

[RowNum_ASR,ColNum_ASR] = size(datamatrix);             
PeakDetectionoutput = zeros(RowNum_ASR,ColNum_ASR);     

len1 = length(rowCellsFix); % 要处理的数据条数  len1<=RowNum_ASR
len2 = length(colCellsFix);  % 要检测的单元 len2<=ColNum_ASR

for ii = 1:len2
    y = colCellsFix(ii);
    
    if CFARmethod==0
        refL_average = zeros(len1,1);  % 初始化
        refR_average = zeros(len1,1);  % 初始化
    else
        refL_average = Inf*ones(len1,1);  % 初始化
        refR_average = Inf*ones(len1,1);  % 初始化
    end
    
    refL1 = y-(saveCellNum+refCellNum);% 左参考单元的左边界
    refL2 = y-saveCellNum-1;           % 左参考单元的右边界
    refR1 = y+saveCellNum+1;           % 右参考单元的左边界
    refR2 = y+saveCellNum+refCellNum;  % 右参考单元的右边界
    
    if refL1>=1              % 左参考单元点数不够，则都不用
        refL_average = mean(datamatrix(rowCellsFix,refL1:refL2),2);  % 左参考单元的平均
	else % 左参考单元点数不够,则用右边的
        refL_average = mean(datamatrix(rowCellsFix,refR1:refR2),2);  
    end    
    if refR2<=ColNum_ASR         % 右参考单元点数不够，则都不用
        refR_average = mean(datamatrix(rowCellsFix,refR1:refR2),2);    % 右参考单元的平均
	else  % 右参考单元点数不够,则用左边的
        refR_average = mean(datamatrix(rowCellsFix,refL1:refL2),2);
    end
        
    if CFARmethod==0
        ref_average_used = max(refL_average,refR_average);     % 选大    
    else
        ref_average_used = min(refL_average,refR_average);     % 选小
    end
    threshold_CFAR = ref_average_used.*T_CFAR;           % 生成门限 (DSP程序中，threshold_CFAR可只用一个变量，不必用数组.这里是方便测试）
    
    % flag=datamatrix(:,y)>=threshold_CFAR;
    flag = datamatrix(rowCellsFix,y)>=threshold_CFAR;   
    
%     if y==1 
%         flag1 = ones(len1,1);
%     else
%         flag1 = datamatrix(rowCellsFix,y)>=datamatrix(rowCellsFix,y-1);     % 行数据的峰值判别
%     end
% 
%     if y==ColNum_ASR
%         flag2 = ones(len1,1);
%     else
%         flag2 = datamatrix(rowCellsFix,y)>=datamatrix(rowCellsFix,y+1);  % 行数据的峰值判别
%     end
% 
% %     flag3_1 = datamatrix(:,y)>=[0;datamatrix(2:end,y)];
%     flag3_1 = datamatrix(:,y)>=[0;datamatrix(1:end-1,y)];   % 列数据的峰值判别
%     flag3 = flag3_1(rowCellsFix);
%     
% %     flag4_1 = datamatrix(:,y)>=[datamatrix(1:end-1,y);0];
%     flag4_1 = datamatrix(:,y)>=[datamatrix(2:end,y);0];      % 列数据的峰值判别
%     flag4 = flag4_1(rowCellsFix);

flag1 = 1;
flag2 = 1;
flag3 = 1;
flag4 = 1;

    PeakDetectionoutput(rowCellsFix,y)=flag.*flag1.*flag2.*flag3.*flag4;

end






