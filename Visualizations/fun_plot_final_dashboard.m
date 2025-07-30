function fun_plot_final_dashboard(filtered_log, config, north_angle, fix_angle, plot_option)
% FUN_PLOT_FINAL_DASHBOARD - 绘制最终结果的综合分析仪表盘
%
% 本函数接收经过筛选的最终目标日志，并根据指定的绘图选项，
% 生成包括RHI, PPI, RDM等多种视图。
%
% 输入参数:
%   filtered_log  - (struct array) 经过筛选后的最终目标日志。
%   config        - (struct) 全局配置结构体。
%   north_angle   - (scalar) 指北修正角（度）。
%   fix_angle     - (scalar) 固定偏移修正角（度）。
%   plot_option   - (string) 指定要绘制的图形类型。

%% 1. 从日志中提取绘图所需数据
% --- 提取所有需要的数据列 ---
raw_angles = [filtered_log.azimuth_deg];
all_ranges = [filtered_log.range_m];
all_velocities = [filtered_log.velocity_ms];
all_elevations = [filtered_log.elevation_deg];
all_heights = [filtered_log.height_m];
all_snr = [filtered_log.snr];

% --- 对方位角进行修正 ---
corrected_azimuths = fun_correct_servo_angle(raw_angles, north_angle, fix_angle);

%% 2. 根据绘图选项，生成不同视图
% 使用 switch 语句来控制绘图逻辑
switch plot_option
    case 'summary'
        % --- 绘制包含4个核心视图的综合仪表盘 ---
        h_fig = figure('Name', '最终结果综合分析仪表盘', 'NumberTitle', 'off', 'Position', [100, 100, 1400, 1000]);
        
        % 子图1: PPI (距离-方位图)
        ax1 = subplot(2, 2, 1, polaraxes);
        polarscatter(ax1, deg2rad(corrected_azimuths), all_ranges, 25, all_heights, 'filled', 'MarkerFaceAlpha', 0.7);
        ax1.ThetaZeroLocation = 'top'; ax1.ThetaDir = 'clockwise'; ax1.ThetaLim = [0 360];
        title(ax1, '平面位置图 (PPI) - 颜色代表高度');
        c1 = colorbar(ax1); c1.Label.String = '高度 (m)';
        
        % 子图2: 距离-速度图
        ax3 = subplot(2, 2, 2);
        scatter(ax3, all_ranges, all_velocities, 25, all_snr, 'filled', 'MarkerFaceAlpha', 0.7);
        grid(ax3, 'on'); xlabel(ax3, '距离 (m)'); ylabel(ax3, '速度 (m/s)');
        title(ax3, '距离-速度图 - 颜色代表SNR');
        c3 = colorbar(ax3); c3.Label.String = '信噪比';
        
        % 子图3: RHI (距离-高度图)
        ax2 = subplot(2, 2, 3);
        scatter(ax2, all_ranges, all_heights, 25, all_velocities, 'filled', 'MarkerFaceAlpha', 0.7);
        grid(ax2, 'on'); xlabel(ax2, '距离 (m)'); ylabel(ax2, '高度 (m)');
        title(ax2, '距离-高度图 (RHI) - 颜色代表速度');
        c2 = colorbar(ax2); c2.Label.String = '速度 (m/s)';
        
        % 子图4: 距离-俯仰角图
        ax4 = subplot(2, 2, 4);
        scatter(ax4, all_ranges, all_elevations, 25, all_velocities, 'filled', 'MarkerFaceAlpha', 0.7);
        grid(ax4, 'on'); xlabel(ax4, '距离 (m)'); ylabel(ax4, '俯仰角 (度)');
        title(ax4, '距离-俯仰角图 - 颜色代表速度');
        c4 = colorbar(ax4); c4.Label.String = '速度 (m/s)';
        
        sgtitle(sprintf('最终检测结果汇总 (共 %d 点)', length(filtered_log)));

    case 'rhi'
        % --- 单独绘制距离-高度图 ---
        figure('Name', '距离-高度图 (RHI)', 'NumberTitle', 'off');
        scatter(all_ranges, all_heights, 36, all_velocities, 'filled');
        grid on; xlabel('距离 (m)'); ylabel('高度 (m)');
        title(sprintf('累积检测点 距离-高度 分布 (共 %d 点)', length(filtered_log)));
        c = colorbar; c.Label.String = '速度 (m/s)';
        
    % --- 其他绘图选项可以按需添加 ---
    case 'ppi'
        figure('Name', '平面位置图 (PPI)', 'NumberTitle', 'off');
        pax = polaraxes;
        polarscatter(pax, deg2rad(corrected_azimuths), all_ranges, 36, all_heights, 'filled');
        pax.ThetaZeroLocation = 'top'; pax.ThetaDir = 'clockwise'; pax.ThetaLim = [0 360];
        title(sprintf('累积检测点 平面位置 分布 (共 %d 点)', length(filtered_log)));
        c = colorbar; c.Label.String = '高度 (m)';
        
    otherwise
        warning('未知的绘图选项: %s。', plot_option);
end

end
