function [cfarResultFlag_Matrix,cfarResultFlag_MatrixV] = executeCFAR(echo_MTD_sum_short,CFAR_params)
% 执行CFAR操作
% 输入：
%     echo_MTD_sum_short: MTD矩阵，行-多普勒采样单元；列-距离采样单元(2048,62)
%     refCells_R: 距离维 参考单元数 5
%     saveCells_R: 距离维 保护单元数 7
%     T_CFAR_R: 距离维恒虚警标称化因子 7
%     CFARmethod_R: 0--选大；1--选小 0
%     refCells_V: 速度维 参考单元数 5
%     saveCells_V: 速度维 保护单元数 7
%     T_CFAR_V: 速度维恒虚警标称化因子 7
%     CFARmethod_V: 0--选大；1--选小 0
%     MTD_0_num: 杂波扣除点数 6
%     rCFARDetect_Flag: 是否执行距离维的CFAR检测 1
%
% 输出：
%     cfarResultFlag_Matrix: CFAR检测结果指示矩阵 (2048,62)
%     cfarResultFlag_MatrixV (2048,62)

%% CFAR参数传递
refCells_R = CFAR_params.refCells_R;
saveCells_R = CFAR_params.saveCells_R;
T_CFAR_R = CFAR_params.T_CFAR_R;
CFARmethod_R = CFAR_params.CFARmethod_R;
refCells_V = CFAR_params.refCells_V;
saveCells_V = CFAR_params.saveCells_V;
T_CFAR_V = CFAR_params.T_CFAR_V;
CFARmethod_V = CFAR_params.CFARmethod_V;
MTD_0v_num = CFAR_params.MTD_0v_num;
rCFARDetect_Flag = CFAR_params.rCFARDetect_Flag;

%% 取出杂波区范围外的数据进行检测
[vCellNum_org,rCellNum_org] = size(echo_MTD_sum_short);
% echo_mtd_abs_used = echo_MTD_sum_short(MTD_0_num+2:mtd_FFT_num-MTD_0_num,:);
echo_mtd_abs_used = echo_MTD_sum_short(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:);
[vCellNum,rCellNum] = size(echo_mtd_abs_used);

%% 先-多普勒(速度)维检测
% Function_CFAR1D_sub.m 按行进行检测
cfarresult_V = Function_CFAR1D_sub(echo_mtd_abs_used.',refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V).';

cfarResultFlag_MatrixV = zeros(vCellNum_org,rCellNum_org,'double');
cfarResultFlag_MatrixV(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:) = cfarresult_V;
%% 后-基于速度检测结果进行距离检测
cfarResultFlag_Matrix = zeros(vCellNum_org,rCellNum_org,'double');

if rCFARDetect_Flag
    [vCell_row, rCell_col] = find(cfarresult_V);  % 速度维检测结果
    rangeCellNums = 1;   % 基于多普勒速度维检测结果，对目标距离位置上左右rangeCellNums点进行检测，共检测rangeCellNums*2+1点。
    rRangeCells = -rangeCellNums:rangeCellNums;

    if ~isempty(vCell_row)
        targetNum_v = length(vCell_row);   % 多普勒速度维检测后的目标数
        vCell_row1 = [];
        rCell_col2 = [];

        for mm = 1:targetNum_v
            vCell_currentInd = vCell_row(mm);   % 目标所在多普勒采样单元
            rCell_currentInd = rCell_col(mm);   % 目标所在距离采样单元（初值，待下面进行距离维检测）

            vCellsFix1 = 1;  % 每次检测一行
            rCellsFix1 = rRangeCells+rCell_currentInd;  % 要检测的距离采样单元

            if ~(max(rCellsFix1)<=rCellNum && min(rCellsFix1)>0)
                ind1 = find(rCellsFix1>rCellNum);
                rCellsFix1(ind1) = [];
                ind2 = find(rCellsFix1<=0);
                rCellsFix1(ind2) = [];
            end

            dataUsedTemp = echo_mtd_abs_used(vCell_currentInd,:);  % 每次只检测一个速度单元内的目标

            detectionFlag_R = Function_CFAR1D_sub_fixCells(dataUsedTemp, refCells_R, saveCells_R, T_CFAR_R, CFARmethod_R, vCellsFix1,rCellsFix1);

            % 更新目标所在位置
            nonZeroInd = find(detectionFlag_R);
            if ~isempty(nonZeroInd)
                vCell_row1 = [vCell_row1,vCell_currentInd];

                if length(nonZeroInd)>1
                    [M,I]  = max(dataUsedTemp(nonZeroInd));
                    rCell_col2 = [rCell_col2,nonZeroInd(I(1))];
                else
                    rCell_col2 = [rCell_col2,nonZeroInd];
                end
            end
        end

        % 形成检测指示矩阵
        cfarResult_R = zeros(vCellNum,rCellNum,'double');
        if ~isempty(vCell_row1)
            lenTemp = length(vCell_row1);
            for mm = 1:lenTemp
                cfarResult_R(vCell_row1(mm),rCell_col2(mm)) = 1;  % 更新
            end
        end
    else
        cfarResult_R = zeros(vCellNum,rCellNum,'double');
    end

    cfarResultFlag_Matrix(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:) = cfarResult_R;
else
    cfarResultFlag_Matrix = cfarResultFlag_MatrixV;
end

