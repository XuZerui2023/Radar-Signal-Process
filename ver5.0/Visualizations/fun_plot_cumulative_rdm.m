function h_fig = fun_plot_cumulative_rdm(detection_log, params)
% FUN_PLOT_CUMULATIVE_RDM - 在一张距离-速度图上绘制所有CFAR检测到的目标点
%
% 输入参数:
%   detection_log - (struct array) 包含所有检测点详细信息的结构体数组。
%   params        - (struct) 包含雷达系统参数的结构体。
%
% 输出参数:
%   h_fig         - (figure handle) 所创建的图窗句柄。

%% 1. 创建图窗和坐标轴
h_fig = figure('Name', '累积CFAR检测结果 (距离-速度域)', 'NumberTitle', 'off', 'Position', [150, 150, 900, 600]);
ax = axes(h_fig);

%% 2. 从日志中提取绘图所需数据
all_ranges_m = [detection_log.range_m];
all_velocities_ms = [detection_log.velocity_ms];
all_snr = [detection_log.snr]; % 提取信噪比信息

%% 3. 绘制所有检测点的散点图
% 使用 scatter 函数，将点的大小或颜色映射到其信噪比(SNR)值
% 第三个参数 '20' 是散点的大小
% 第四个参数可以指定颜色或选 all_snr（目标检测点信号幅值大小映射到颜色上，蓝->红）
scatter(ax, all_ranges_m, all_velocities_ms, 20, 'r', 'filled');

%% 4. 美化图形
xlabel(ax, '距离 (m)');
ylabel(ax, '速度 (m/s)');
title(ax, sprintf('所有帧的累积CFAR检测结果 (共 %d 点)', length(detection_log)));
grid(ax, 'on');

% 添加颜色条并设置标签
c = colorbar(ax);
c.Label.String = '目标信噪比 (MTD幅度)';

end
