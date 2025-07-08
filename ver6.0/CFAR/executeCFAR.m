function [cfarResultFlag_Matrix,cfarResultFlag_MatrixV] = executeCFAR(echo_MTD_sum_short,CFAR_params)
% ִ��CFAR����
% ���룺
%     echo_MTD_sum_short: MTD������-�����ղ�����Ԫ����-���������Ԫ(2048,62)
%     refCells_R: ����ά �ο���Ԫ�� 5
%     saveCells_R: ����ά ������Ԫ�� 7
%     T_CFAR_R: ����ά���龯��ƻ����� 7
%     CFARmethod_R: 0--ѡ��1--ѡС 0
%     refCells_V: �ٶ�ά �ο���Ԫ�� 5
%     saveCells_V: �ٶ�ά ������Ԫ�� 7
%     T_CFAR_V: �ٶ�ά���龯��ƻ����� 7
%     CFARmethod_V: 0--ѡ��1--ѡС 0
%     MTD_0_num: �Ӳ��۳����� 6
%     rCFARDetect_Flag: �Ƿ�ִ�о���ά��CFAR��� 1
%
% �����
%     cfarResultFlag_Matrix: CFAR�����ָʾ���� (2048,62)
%     cfarResultFlag_MatrixV (2048,62)

%% CFAR��������
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

%% ȡ���Ӳ�����Χ������ݽ��м��
[vCellNum_org,rCellNum_org] = size(echo_MTD_sum_short);
% echo_mtd_abs_used = echo_MTD_sum_short(MTD_0_num+2:mtd_FFT_num-MTD_0_num,:);
echo_mtd_abs_used = echo_MTD_sum_short(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:);
[vCellNum,rCellNum] = size(echo_mtd_abs_used);

%% ��-������(�ٶ�)ά���
% Function_CFAR1D_sub.m ���н��м��
cfarresult_V = Function_CFAR1D_sub(echo_mtd_abs_used.',refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V).';

cfarResultFlag_MatrixV = zeros(vCellNum_org,rCellNum_org,'double');
cfarResultFlag_MatrixV(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:) = cfarresult_V;
%% ��-�����ٶȼ�������о�����
cfarResultFlag_Matrix = zeros(vCellNum_org,rCellNum_org,'double');

if rCFARDetect_Flag
    [vCell_row, rCell_col] = find(cfarresult_V);  % �ٶ�ά�����
    rangeCellNums = 1;   % ���ڶ������ٶ�ά���������Ŀ�����λ��������rangeCellNums����м�⣬�����rangeCellNums*2+1�㡣
    rRangeCells = -rangeCellNums:rangeCellNums;

    if ~isempty(vCell_row)
        targetNum_v = length(vCell_row);   % �������ٶ�ά�����Ŀ����
        vCell_row1 = [];
        rCell_col2 = [];

        for mm = 1:targetNum_v
            vCell_currentInd = vCell_row(mm);   % Ŀ�����ڶ����ղ�����Ԫ
            rCell_currentInd = rCell_col(mm);   % Ŀ�����ھ��������Ԫ����ֵ����������о���ά��⣩

            vCellsFix1 = 1;  % ÿ�μ��һ��
            rCellsFix1 = rRangeCells+rCell_currentInd;  % Ҫ���ľ��������Ԫ

            if ~(max(rCellsFix1)<=rCellNum && min(rCellsFix1)>0)
                ind1 = find(rCellsFix1>rCellNum);
                rCellsFix1(ind1) = [];
                ind2 = find(rCellsFix1<=0);
                rCellsFix1(ind2) = [];
            end

            dataUsedTemp = echo_mtd_abs_used(vCell_currentInd,:);  % ÿ��ֻ���һ���ٶȵ�Ԫ�ڵ�Ŀ��

            detectionFlag_R = Function_CFAR1D_sub_fixCells(dataUsedTemp, refCells_R, saveCells_R, T_CFAR_R, CFARmethod_R, vCellsFix1,rCellsFix1);

            % ����Ŀ������λ��
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

        % �γɼ��ָʾ����
        cfarResult_R = zeros(vCellNum,rCellNum,'double');
        if ~isempty(vCell_row1)
            lenTemp = length(vCell_row1);
            for mm = 1:lenTemp
                cfarResult_R(vCell_row1(mm),rCell_col2(mm)) = 1;  % ����
            end
        end
    else
        cfarResult_R = zeros(vCellNum,rCellNum,'double');
    end

    cfarResultFlag_Matrix(MTD_0v_num+2:vCellNum_org-MTD_0v_num,:) = cfarResult_R;
else
    cfarResultFlag_Matrix = cfarResultFlag_MatrixV;
end

