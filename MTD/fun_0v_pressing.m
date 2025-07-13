% 对MTD结果进行零速压制，以抑制静止目标、地杂波
%
% 本函数接收一个距离-多普勒图（RDM），通过将零速通道及其附近
% 邻域的数值强制置零，来有效抑制来自地面、建筑物等静止目标的强回波（地杂波）。
% 这是MTD处理流程中提高动目标信噪比的关键一步。
%
% 输入参数:
%   MTD - (prtNum x point_prt double) 输入的距离-多普勒矩阵。其行代表速度维，列代表距离维。
%
% 输出参数:
%   MTD - (prtNum x point_prt double) 经过零速压制处理后的距离-多普勒矩阵。

function MTD = fun_0v_pressing(MTD) % 无噪回波幅度控制
% 1. 获取输入矩阵的维度
[prtNum,point_prt] = size(MTD);

% 2. 定位零速通道
zero_v_pos = round(prtNum/2);
% MTD(zero_v_pos-round(prtNum/150):zero_v_pos+round(prtNum/150),:)=mean(mean(abs(MTD)));

% 3. 执行零速压制
MTD(zero_v_pos-round(prtNum/150) : zero_v_pos+round(prtNum/150),:) = 0;

end
