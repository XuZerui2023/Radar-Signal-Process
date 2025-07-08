% FUN_PLOT_CUMULATIVE_AZ_RANGE - 在一张距离-方位图上绘制所有CFAR检测到的目标点
%
% 输入参数:
%   detection_log - (struct array) 包含所有检测点详细信息的结构体数组。
%   params        - (struct) 包含雷达系统参数的结构体。
%   north_angle   - (scalar) 指北修正角（度）。
%   fix_angle     - (scalar) 固定偏移修正角（度）。
%
% 输出参数:
%   h_fig         - (figure handle) 所创建的图窗句柄。

function h_fig = fun_plot_cumulative_az_range(detection_log, params, north_angle, fix_angle)
%% 1. 创建图窗和坐标轴
h_fig = figure('Name', '累积CFAR检测结果 (距离-方位域)', 'NumberTitle', 'off', 'Position', [150, 150, 900, 600]);
ax = axes(h_fig);

%% 2. 从日志中提取绘图所需数据
% 提取原始角度、距离和信噪比信息
raw_angles_from_log = [detection_log.azimuth_deg];
all_ranges_m = [detection_log.range_m];
all_snr = [detection_log.snr];

%% 3. 对角度进行修正
% 调用我们之前创建的角度修正函数
% 注意：fun_correct_servo_angle需要的是原始整数值，而log里存的是乘以0.1之后的值，所以要除以0.1还原
corrected_angles_deg = fun_correct_servo_angle(raw_angles_from_log / 0.1, north_angle, fix_angle);

%% 4. 绘制所有检测点的散点图
% 使用 scatter 函数，将点的颜色映射到其信噪比(SNR)值
% X轴是修正后的方位角，Y轴是距离
scatter(ax, corrected_angles_deg, all_ranges_m, 36, all_snr, 'filled');

%% 5. 美化图形
xlabel(ax, '方位角 (度)');
ylabel(ax, '距离 (m)');
title(ax, sprintf('所有帧的累积CFAR检测结果 (共 %d 点)', length(detection_log)));
grid(ax, 'on');
xlim(ax, [-180, 180]); % 将方位角范围固定在-180到180度

% 添加颜色条并设置标签
c = colorbar(ax);
c.Label.String = '目标信噪比 (MTD幅度)';

end
