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

function MTD = fun_0v_pressing(MTD, config) % 无噪回波幅度控制

% 1. 获取输入矩阵的维度和系统参数
[prtNum, point_prt] = size(MTD); 
velocity_resolution = config.cfar.deltaV;   % 速度分辨率大小，也是一个速度参考单元的大小
suppress_velocity_ms = config.cfar.MTD_V;   % 【可调参数】定义要抑制的速度范围，这里主控函数中设置为 -3m/s 到 +3m/s

% 2. 计算需要抑制的速度单元数量
notch_width_bins = ceil(suppress_velocity_ms / velocity_resolution);
% fprintf('  > 速度分辨率: %.3f m/s, 抑制凹口宽度: %d 单元.\n', velocity_resolution, notch_width_bins);

% 3. 定位零速通道
zero_v_pos = round(prtNum/2) + 1;

% 4. 定义抑制范围，并进行边界检查
start_bin = max(1, zero_v_pos - notch_width_bins);
end_bin = min(prtNum, zero_v_pos + notch_width_bins);
suppress_range = start_bin:end_bin;

% 5. 执行零速压制
MTD(suppress_range, :) = 0;    % 相当于164速度单元到168速度单元

end
