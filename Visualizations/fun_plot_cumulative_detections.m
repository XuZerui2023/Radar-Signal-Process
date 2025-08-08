% FUN_PLOT_CUMULATIVE_DETECTIONS - 在一张PPI图上绘制所有CFAR检测到的目标点
%
% 输入参数:
%   detection_log - (struct array) 包含所有检测点详细信息的结构体数组。
%   params        - (struct) 包含雷达系统参数的结构体。
%   north_angle   - (scalar) 指北修正角（度）。
%   fix_angle     - (scalar) 固定偏移修正角（度）。
%
% 输出参数:
%   h_fig         - (figure handle) 所创建的图窗句柄。
%

function h_fig = fun_plot_cumulative_detections(detection_log, params, north_angle, fix_angle)
%% 1. 创建图窗和极坐标轴
h_fig = figure('Name', '累积CFAR检测结果', 'NumberTitle', 'off', 'Position', [100, 100, 800, 800]);
% ax = axes(h_fig);
pax = polaraxes;
pax.ThetaZeroLocation = 'top';
pax.ThetaDir = 'clockwise';
pax.ThetaLim = [0 360];

%% 2. 从日志中提取绘图所需数据
raw_angles = [detection_log.azimuth_deg];
all_ranges_m = [detection_log.range_m];
all_velocities_ms = [detection_log.velocity_ms];

% --- 【新增】根据速度阈值筛选目标点 ---
fprintf('绘图前原始检测点数: %d\n', length(all_velocities_ms));
% 创建一个逻辑掩码(mask)，速度大于2或小于-2的位置为true
velocity_mask = (all_velocities_ms > 2) | (all_velocities_ms < -2);

% 应用这个掩码，只保留符合速度条件的目标点数据
raw_angles_from_log = raw_angles(velocity_mask);
all_ranges_m = all_ranges_m(velocity_mask);
all_velocities_ms = all_velocities_ms(velocity_mask);

%% 3. 对角度进行修正
% 调用我们之前创建的角度修正函数
corrected_angles_deg = fun_correct_servo_angle(raw_angles_from_log, north_angle, fix_angle);
angles_rad = deg2rad(corrected_angles_deg);

%% 4. 绘制所有检测点的散点图
% 使用 polarscatter 函数，将点的颜色映射到其速度值
% 第三个参数 '36' 是散点的大小
scatter_plot = polarscatter(pax, angles_rad, all_ranges_m, 36, all_velocities_ms, 'filled');
% scatter(ax, all_ranges_m, corrected_angles_deg, 20, 'r', 'filled');      % 把散点图改成对应的直方图（距离-方位）
% 设置散点的透明度，便于观察重叠点
scatter_plot.MarkerFaceAlpha = 0.6;

%% 5. 美化图形
title(sprintf('所有帧的累积CFAR检测结果 (共 %d 点)', length(detection_log)));
% 设置距离轴的范围
max_range = max(all_ranges_m);
if isempty(max_range) || max_range == 0, max_range = 1000; end
pax.RLim = [0, max_range * 1.1];

% 添加颜色条并设置标签
c = colorbar(pax);
c.Label.String = '目标速度 (m/s)';

end
