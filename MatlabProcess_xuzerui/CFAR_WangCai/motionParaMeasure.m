function [rEstSeries,vEstSeries,eleAngleEstSeries] = motionParaMeasure(echo_MTD_sum_short,echo_MTD_diff_short,cfarResultFlag_Matrix_short,extraDots,...
    rScale_short,deltaR,rInterpTimes,vScale,deltaV,vInterpTimes,kValues,beamPosNum,beamAngleStep,freInd,eleAngleComp,eleAngleSysErr,MTD_0_num)

%% 距离、速度、角度测量
[vCellNum,rCellNum] = size(cfarResultFlag_Matrix_short);
[vCell_Ind, rCell_Ind] = find(cfarResultFlag_Matrix_short);  % 存在目标的距离单元和速度单元索引

cellsExtend = -extraDots:extraDots;
% 测量结果变量初始化
rEstSeries = [];  % 距离测量值
vEstSeries = [];  % 速度测量值
eleAngleEstSeries = [];  % 角度测量值（俯仰）

if ~isempty(vCell_Ind) % 存在目标
    targetNum = length(vCell_Ind);   % 多普勒速度维检测后的目标数
    
    for mm = 1:targetNum
        vCell_currentInd = vCell_Ind(mm);   % 目标所在多普勒采样单元
        rCell_currentInd = rCell_Ind(mm);   % 目标所在距离采样单元
        
        % ----------------------------- 距离测量 -----------------------
        rCellsFix = cellsExtend+rCell_currentInd;  % 要检测的距离采样单元
        
        if min(rCellsFix)<=0  % 纠错:如果目标在数据起始位置附近
            indTemp = find(rCellsFix==1);
            rCellsFix = rCellsFix(indTemp)+(0:extraDots*2);
        end
        
        if max(rCellsFix)>rCellNum  % 纠错:如果目标在数据结束位置附近
            indTemp = find(rCellsFix==rCellNum);
            rCellsFix = rCellsFix(indTemp)-(0:extraDots*2);
        end
        rCellsFix = sort(rCellsFix);   % 由大到小排序
        
        % 插值
        mtdDataUsed_r = echo_MTD_sum_short(vCell_currentInd,rCellsFix);  % 取出目标所在位置附近的数据进行插值
        rCellsFixQ = rCellsFix(1):1/rInterpTimes:rCellsFix(end);   % 距离维插值变量
        mtdDataUsedQ_r = interp1(rCellsFix-rCellsFix(1),mtdDataUsed_r,rCellsFixQ-rCellsFix(1),'spline');
        [M1,I1] = max(mtdDataUsedQ_r);
        if ~isempty(I1)
            % rCellMax = rCellsFixQ(I1);     % 幅度值最大的位置
            rCellMax = rCellsFixQ(I1(1));     % 幅度值最大的位置
            rEst = rScale_short(rCell_currentInd) + (rCellMax-rCell_currentInd)*deltaR;   % 目标测量距离
        else
            rEst = [];
        end
        
        % ----------------------------- 速度测量 -----------------------
        vCellsFix = cellsExtend+vCell_currentInd;  % 要检测的速度采样单元
        
        if min(vCellsFix)<=(MTD_0_num+1)  % 纠错:如果目标在数据起始位置附近（零多普勒）
            indTemp = find(vCellsFix==(MTD_0_num+2));
            vCellsFix = vCellsFix(indTemp)+(0:extraDots*2);
        end
        
        if max(vCellsFix)>vCellNum-MTD_0_num  % 纠错:如果目标在数据结束位置附近
            indTemp = find(vCellsFix==(vCellNum-MTD_0_num));
            vCellsFix = vCellsFix(indTemp)-(0:extraDots*2);
        end
        vCellsFix = sort(vCellsFix);
        
        % 插值
        mtdDataUsed_v = echo_MTD_sum_short(vCellsFix,rCell_currentInd);  % 取出目标所在位置附近的数据进行插值
        vCellsFixQ = vCellsFix(1):1/vInterpTimes:vCellsFix(end);   % 距离维插值变量
        mtdDataUsedQ_v = interp1(vCellsFix-vCellsFix(1),mtdDataUsed_v,vCellsFixQ-vCellsFix(1),'spline');
        [M2,I2] = max(mtdDataUsedQ_v);
        if ~isempty(I2) && ~isempty(rEst)
            % vCellMax = vCellsFixQ(I2);     % 幅度值最大的位置
            vCellMax = vCellsFixQ(I2(1));     % 幅度值最大的位置
            vEst = vScale(fix(vCellMax)) - (vCellMax-fix(vCellMax))*deltaV;   % 目标测量速度
        else
            vEst = [];
        end
        % ----------------------------- 俯仰角度测量 -----------------------
        if ~isempty(vEst) || ~isempty(rEst)
            amp_sum = echo_MTD_sum_short(vCell_currentInd,rCell_currentInd);   % 和幅度
            amp_diff = echo_MTD_diff_short(vCell_currentInd,rCell_currentInd);  % 差幅度
            amp_ratio = amp_diff/amp_sum;   % 幅度比值
            eleAngleEst = beamPosNum*beamAngleStep+2.5-amp_ratio*kValues(freInd+1,beamPosNum+1)+eleAngleComp+eleAngleSysErr; % 单位：degree
        else
            eleAngleEst = [];
        end
        %  总数据更新
        rEstSeries = [rEstSeries;rEst];
        vEstSeries = [vEstSeries;vEst];
        eleAngleEstSeries = [eleAngleEstSeries;eleAngleEst];
    end
end