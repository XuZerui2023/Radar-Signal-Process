function h_fig = fun_plot_summary_dashboard(detection_log, params, north_angle, fix_angle)
% FUN_PLOT_SUMMARY_DASHBOARD - 创建一个包含所有累积结果的综合分析仪表盘
%
% 本函数接收最终的检测日志，并在一个窗口中通过四个子图，从空间分布、
% 运动学特征和统计分布等多个角度对结果进行汇总展示。
%
% 输入参数:
%   detection_log - (struct array) 包含所有检测点详细信息的结构体数组。
%   params        - (struct) 包含雷达系统参数的结构体。
%   north_angle   - (scalar) 指北修正角（度）。
%   fix_angle     - (scalar) 固定偏移修正角（度）。
%
% 输出参数:
%   h_fig         - (figure handle) 所创建的图窗句柄。

%% 1. 创建图窗
h_fig = figure('Name', '累积检测结果综合分析仪表盘', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 800]);

%% 2. 从日志中提取绘图所需数据
raw_angles_from_log = [detection_log.azimuth_deg];
all_ranges_m = [detection_log.range_m];
all_velocities_ms = [detection_log.velocity_ms];
all_snr = [detection_log.snr];

% 对角度进行修正
corrected_angles_deg = fun_correct_servo_angle(raw_angles_from_log, north_angle, fix_angle);

%% 3. 绘制四个子图

% --- 子图 1: 累积PPI图 (空间位置分布) ---

ax1 = subplot(2, 2, 1, polaraxes);
polarscatter(ax1, deg2rad(corrected_angles_deg), all_ranges_m, 20, all_velocities_ms, 'filled', 'MarkerFaceAlpha', 0.6);
ax1.ThetaZeroLocation = 'top';
ax1.ThetaDir = 'clockwise';
ax1.ThetaLim = [-180 180];
% ax1.RLim = [0 max(range_to_plot)];
title(ax1, '累积目标位置距离-方位图 (颜色代表速度)');
c1 = colorbar(ax1);
c1.Label.String = '速度 (m/s)';

% --- 子图 2: 累积距离-速度图 (运动学特征) ---
ax2 = subplot(2, 2, 2);
scatter(ax2, all_ranges_m, all_velocities_ms, 20, all_snr, 'filled', 'MarkerFaceAlpha', 0.6);
grid(ax2, 'on');
xlabel(ax2, '距离 (m)');
ylabel(ax2, '速度 (m/s)');
title(ax2, '累积目标位置距离-速度图 (颜色代表SNR)');
c2 = colorbar(ax2);
c2.Label.String = '信噪比 (MTD幅度)';

% --- 子图 3: 速度直方图 (统计分布) ---
ax3 = subplot(2, 2, 3);
histogram(ax3, all_velocities_ms, 50); % 50个bins
grid(ax3, 'on');
xlabel(ax3, '速度 (m/s)');
ylabel(ax3, '检测点数');
title(ax3, '目标速度分布直方图');

% --- 子图 4: 距离直方图 (统计分布) ---
ax4 = subplot(2, 2, 4);
histogram(ax4, all_ranges_m, 50); % 50个bins
grid(ax4, 'on');
xlabel(ax4, '距离 (m)');
ylabel(ax4, '检测点数');
title(ax4, '目标距离分布直方图');

% 添加一个总标题
sgtitle(sprintf('所有 %d 帧的累积检测结果分析 (共 %d 点)', ...
        length(unique([detection_log.frame])), length(detection_log)));

end
