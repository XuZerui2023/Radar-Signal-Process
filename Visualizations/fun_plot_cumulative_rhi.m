function h_fig = fun_plot_cumulative_rhi(detection_log, params)
% FUN_PLOT_CUMULATIVE_RHI - 在一张距离-高度图上绘制所有CFAR检测到的目标点
%
% 本函数是 fun_plot_cumulative_az_range.m 的修改版本，专门用于
% 可视化目标的垂直剖面信息 (距离 vs 高度)。
%
% 输入参数:
%   detection_log - (struct array) 包含所有检测点详细信息的结构体数组。
%                   该结构体必须包含 .range_m, .height_m, 和 .velocity_ms 字段。
%   params        - (struct) 包含雷达系统参数的结构体 (当前未使用，为未来扩展保留)。
%
% 输出参数:
%   h_fig         - (figure handle) 所创建的图窗句柄。

%% 1. 创建图窗和坐标轴
h_fig = figure('Name', '累积检测结果 (距离-高度图)', 'NumberTitle', 'off', 'Position', [200, 200, 900, 600]);
ax = axes(h_fig);

%% 2. 从日志中提取绘图所需数据
fprintf('正在从日志中提取距离、高度和速度数据...\n');
% --- 提取距离数据作为X轴 ---
all_ranges_m = [detection_log.range_m];

% --- 提取我们新计算出的高度数据作为Y轴 ---
all_heights_m = [detection_log.height_m];

% --- 提取速度数据，用于为散点图着色，增加信息维度 ---
all_velocities_ms = [detection_log.velocity_ms];

% 检查数据是否为空
if isempty(all_ranges_m)
    title(ax, '日志中无有效数据点用于绘制RHI图');
    warning('输入到 fun_plot_cumulative_rhi 的日志为空或不包含所需字段。');
    return;
end

%% 3. 绘制所有检测点的散点图
% 使用 scatter 函数，将点的颜色映射到其速度值
% X轴: 距离 (m)
% Y轴: 高度 (m)
% 颜色: 速度 (m/s)
scatter(ax, all_ranges_m, all_heights_m, 36, all_velocities_ms, 'filled', 'MarkerFaceAlpha', 0.7);

%% 4. 美化图形
xlabel(ax, '距离 (m)');
ylabel(ax, '高度 (m)');
title(ax, sprintf('累积检测点 距离-高度 分布 (共 %d 点)', length(detection_log)));
grid(ax, 'on');
axis(ax, 'tight'); % 自动调整坐标轴范围以紧密包围数据

% 添加颜色条并设置标签
c = colorbar(ax);
c.Label.String = '目标速度 (m/s)';

end
