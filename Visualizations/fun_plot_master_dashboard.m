function fun_plot_master_dashboard(filtered_log, params, north_angle, fix_angle, plot_option)
% FUN_PLOT_MASTER_DASHBOARD - 绘制最终结果的综合分析仪表盘
%
% 本函数接收经过筛选的最终目标日志，并根据指定的绘图选项，
% 生成包括RHI, PPI, 3D视图等多种可视化。
%
% 输入参数:
%   filtered_log  - (struct array) 经过筛选后的最终目标日志。
%   params        - (struct) 包含雷达系统参数的结构体。
%   north_angle   - (scalar) 指北修正角（度）。
%   fix_angle     - (scalar) 固定偏移修正角（度）。
%   plot_option   - (string) 指定要绘制的图形类型。

%% 1. 从日志中提取绘图所需数据
raw_azimuths = [filtered_log.azimuth_deg];
all_ranges = [filtered_log.range_m];
all_velocities = [filtered_log.velocity_ms];
all_elevations = [filtered_log.elevation_deg];
all_heights = [filtered_log.height_m];
all_snr = [filtered_log.snr];

% 对方位角进行修正
corrected_azimuths = fun_correct_servo_angle(raw_azimuths, north_angle, fix_angle);

%% 2. 根据绘图选项，生成不同视图
switch plot_option
    case 'summary'
        % --- 绘制包含多个核心视图的综合仪表盘 ---
        %figure('Name', '最终结果综合分析仪表盘', 'NumberTitle', 'off', 'Position', [100, 100, 1400, 1000]);
        
        % 子图1: PPI (距离-方位图)
        fig1 = figure(1);
        ax1 = polaraxes(fig1);
        polarscatter(ax1, deg2rad(corrected_azimuths), all_ranges, 20, all_heights, 'filled', 'MarkerFaceAlpha', 0.7); % polarscatter 期望输入的是弧度
        ax1.ThetaZeroLocation = 'top'; ax1.ThetaDir = 'clockwise'; ax1.ThetaLim = [0 360];
        title(ax1, '平面位置图 (PPI) - 颜色代表高度');
        c1 = colorbar(ax1); c1.Label.String = '高度 (m)';
        
        % 子图2: RHI (距离-高度图)
        fig2 = figure(2);
        ax2 = axes(fig2);
        scatter(ax2, all_ranges, all_heights, 20, all_velocities, 'filled', 'MarkerFaceAlpha', 0.7);
        grid(ax2, 'on'); xlabel(ax2, '距离 (m)'); ylabel(ax2, '高度 (m)');
        title(ax2, '距离-高度图 (RHI) - 颜色代表速度');
        c2 = colorbar(ax2); c2.Label.String = '速度 (m/s)';
        
        % 子图3: 距离-速度图
        fig3 = figure(3);
        ax3 = axes(fig3);
        scatter(ax3, all_ranges, all_velocities, 20, all_snr, 'filled', 'MarkerFaceAlpha', 0.7);
        grid(ax3, 'on'); xlabel(ax3, '距离 (m)'); ylabel(ax3, '速度 (m/s)');
        title(ax3, '距离-速度图 - 颜色代表SNR');
        c3 = colorbar(ax3); c3.Label.String = '信噪比';
        
        % 子图4: 三维空间图
        fig4 = figure(4);
        ax4 = axes(fig4);
        az_rad = deg2rad(corrected_azimuths);
        el_rad = deg2rad(all_elevations);
        x = all_ranges .* cos(el_rad) .* sin(az_rad); %
        y = all_ranges .* cos(el_rad) .* cos(az_rad); %
        z = all_heights; % z就是高度
        scatter3(ax4, x, y, z, 20, all_velocities, 'filled');
        grid(ax4, 'on'); xlabel(ax4, 'X (m)'); ylabel(ax4, 'Y (m)'); zlabel(ax4, 'Z/高度 (m)');
        title(ax4, '三维空间分布图 - 颜色代表速度');
        c4 = colorbar(ax4); c4.Label.String = '速度 (m/s)';
        axis(ax4, 'equal'); view(3);

        sgtitle(sprintf('最终检测结果汇总 (共 %d 点)', length(filtered_log)));

    % --- 在此可以添加其他独立的绘图选项 ---
    case 'rhi'
        figure('Name', '距离-高度图 (RHI)', 'NumberTitle', 'off');
        scatter(all_ranges, all_heights, 36, all_velocities, 'filled');
        grid on; xlabel('距离 (m)'); ylabel('高度 (m)');
        title(sprintf('累积检测点 距离-高度 分布 (共 %d 点)', length(filtered_log)));
        c = colorbar; c.Label.String = '速度 (m/s)';
    
    case ''
    otherwise
        warning('未知的绘图选项: %s。', plot_option);
end

end
