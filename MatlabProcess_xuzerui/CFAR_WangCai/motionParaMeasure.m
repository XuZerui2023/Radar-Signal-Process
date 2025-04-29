function [rEstSeries,vEstSeries,eleAngleEstSeries] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_Matrix_short,extraDots,...
    rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num)

%% ���롢�ٶȡ��ǶȲ���
[vCellNum,rCellNum] = size(cfarResultFlag_Matrix_short);
[vCell_Ind, rCell_Ind] = find(cfarResultFlag_Matrix_short);  % ����Ŀ��ľ��뵥Ԫ���ٶȵ�Ԫ����

cellsExtend = -extraDots:extraDots;
% �������������ʼ��
rEstSeries = [];  % �������ֵ
vEstSeries = [];  % �ٶȲ���ֵ
eleAngleEstSeries = [];  % �ǶȲ���ֵ��������

if ~isempty(vCell_Ind) % ����Ŀ��
    targetNum = length(vCell_Ind);   % �������ٶ�ά�����Ŀ����
    
    for mm = 1:targetNum
        vCell_currentInd = vCell_Ind(mm);   % Ŀ�����ڶ����ղ�����Ԫ
        rCell_currentInd = rCell_Ind(mm);   % Ŀ�����ھ��������Ԫ
        
        % ----------------------------- ������� -----------------------
        rCellsFix = cellsExtend+rCell_currentInd;  % Ҫ���ľ��������Ԫ
        
        if min(rCellsFix)<=0  % ����:���Ŀ����������ʼλ�ø���
            indTemp = find(rCellsFix==1);
            rCellsFix = rCellsFix(indTemp)+(0:extraDots*2);
        end
        
        if max(rCellsFix)>rCellNum  % ����:���Ŀ�������ݽ���λ�ø���
            indTemp = find(rCellsFix==rCellNum);
            rCellsFix = rCellsFix(indTemp)-(0:extraDots*2);
        end
        rCellsFix = sort(rCellsFix);   % �ɴ�С����
        
        % ��ֵ
        mtdDataUsed_r = echo_MTD_sum_short(vCell_currentInd,rCellsFix);  % ȡ��Ŀ������λ�ø��������ݽ��в�ֵ
        rCellsFixQ = rCellsFix(1):1/rInterpTimes:rCellsFix(end);   % ����ά��ֵ����
        mtdDataUsedQ_r = interp1(rCellsFix-rCellsFix(1),mtdDataUsed_r,rCellsFixQ-rCellsFix(1),'spline');
        [M1,I1] = max(mtdDataUsedQ_r);
        if ~isempty(I1)
            % rCellMax = rCellsFixQ(I1);     % ����ֵ����λ��
            rCellMax = rCellsFixQ(I1(1));     % ����ֵ����λ��
            rEst = rScale_short(rCell_currentInd) + (rCellMax-rCell_currentInd)*deltaR;   % Ŀ���������
        else
            rEst = [];
        end
        
        % ----------------------------- �ٶȲ��� -----------------------
        vCellsFix = cellsExtend+vCell_currentInd;  % Ҫ�����ٶȲ�����Ԫ
        
        if min(vCellsFix)<=(MTD_0_num+1)  % ����:���Ŀ����������ʼλ�ø�����������գ�
            indTemp = find(vCellsFix==(MTD_0_num+2));
            vCellsFix = vCellsFix(indTemp)+(0:extraDots*2);
        end
        
        if max(vCellsFix)>vCellNum-MTD_0_num  % ����:���Ŀ�������ݽ���λ�ø���
            indTemp = find(vCellsFix==(vCellNum-MTD_0_num));
            vCellsFix = vCellsFix(indTemp)-(0:extraDots*2);
        end
        vCellsFix = sort(vCellsFix);
        
        % ��ֵ
        mtdDataUsed_v = echo_MTD_sum_short(vCellsFix,rCell_currentInd);  % ȡ��Ŀ������λ�ø��������ݽ��в�ֵ
        vCellsFixQ = vCellsFix(1):1/vInterpTimes:vCellsFix(end);   % ����ά��ֵ����
        mtdDataUsedQ_v = interp1(vCellsFix-vCellsFix(1),mtdDataUsed_v,vCellsFixQ-vCellsFix(1),'spline');
        [M2,I2] = max(mtdDataUsedQ_v);
        if ~isempty(I2) && ~isempty(rEst)
            % vCellMax = vCellsFixQ(I2);     % ����ֵ����λ��
            vCellMax = vCellsFixQ(I2(1));     % ����ֵ����λ��
            vEst = vScale(fix(vCellMax)) - (vCellMax-fix(vCellMax))*deltaV;   % Ŀ������ٶ�
        else
            vEst = [];
        end
        % ----------------------------- �����ǶȲ��� -----------------------
        if ~isempty(vEst) || ~isempty(rEst)
            amp_sum = echo_MTD_sum_short(vCell_currentInd,rCell_currentInd);   % �ͷ���
            amp_diff = echo_MTD_diff_short(vCell_currentInd,rCell_currentInd);  % �����
            amp_ratio = amp_diff/amp_sum;   % ���ȱ�ֵ
            eleAngleEst = beamPosNum*beamAngleStep+2.5-amp_ratio*kValues(freInd+1,beamPosNum+1)+eleAngleComp+eleAngleSysErr; % ��λ��degree
        else
            eleAngleEst = [];
        end
        %  �����ݸ���
        rEstSeries = [rEstSeries;rEst];
        vEstSeries = [vEstSeries;vEst];
        eleAngleEstSeries = [eleAngleEstSeries;eleAngleEst];
    end
end