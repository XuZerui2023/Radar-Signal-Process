% FUN_PLOT_OVERFLOW_PPI_v3.m 对单帧I/Q数据进行可视化，并支持溢出点驻留显示
%
% v3更新：
%   1. 接收一个包含所有历史溢出点信息的结构体数组 `overflow_log`。
%   2. 增加一个 `persist_display` 开关，用于控制是否绘制历史溢出点。

function fun_plot_overflow_ppi_v3(h_fig, raw_iq_data, servo_angle, plot_params)
%% 0. 激活并清空图窗
figure(h_fig);
clf;

%% 1. 获取参数
channel_to_plot = plot_params.channel_to_plot;
range_to_plot = plot_params.range_to_plot;
point_PRT = plot_params.point_PRT;
frame_to_load = plot_params.frame_to_load;
persist_display = plot_params.persist_display;
overflow_log = plot_params.overflow_log;

%% 2. 准备绘图数据
iq_channel_data = raw_iq_data(:, :, channel_to_plot);
amplitude = abs(iq_channel_data);
angles_in_degrees = servo_angle ;  % 这里注意，如果使用 伺服角修正函数 fun_correct_servo_angle.m 处理过则不需要 * 0.01
angles_rad = deg2rad(angles_in_degrees);
ranges = 1:point_PRT;
amplitude_to_plot = amplitude(:, range_to_plot);

%% 3. 极坐标图（PPI）可视化
%ax = axes(h_fig);
pax = polaraxes;
pax.ThetaZeroLocation = 'top';
pax.ThetaDir = 'clockwise';
pax.ThetaLim = [-180 180];
pax.RLim = [0 max(range_to_plot)];

% --- 绘制背景幅度图 ---
[THETA_grid, RHO_grid] = meshgrid(angles_rad, ranges(range_to_plot));
polarscatter(pax, THETA_grid(:), RHO_grid(:), 10, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
%scatter(ax, THETA_grid(:), RHO_grid(:), 10, 'r', 'filled');
colorbar;
title(sprintf('帧 #%d, 通道 #%d 幅度与溢出点分布', frame_to_load, channel_to_plot));
hold(pax, 'on'); % 保持图形，准备叠加溢出点

%% 4. 标记溢出点
if ~isempty(overflow_log)
    % 从总日志中提取所有点的角度和距离
    all_angles_deg = [overflow_log.angle_deg];
    all_ranges_bin = [overflow_log.range_bin];
    all_frames = [overflow_log.frame];
    
    % --- 根据开关决定如何绘图 ---
    if persist_display
        % 驻留模式：绘制所有历史点
        
        % 筛选出在绘图范围内的历史点
        valid_history = ismember(all_ranges_bin, range_to_plot);
        history_angles_rad = deg2rad(all_angles_deg(valid_history));
        history_ranges_bin = all_ranges_bin(valid_history);
        
        % 将历史溢出点用半透明的灰色小点表示
        polarplot(pax, history_angles_rad, history_ranges_bin, '.', 'Color', [0.5 0.5 0.5 0.5]);
        
        % 将当前帧的溢出点用醒目的红色'x'标记在最上层
        is_current_frame = (all_frames == frame_to_load);
        current_valid = valid_history & is_current_frame;
        current_angles_rad = deg2rad(all_angles_deg(current_valid));
        current_ranges_bin = all_ranges_bin(current_valid);
        polarplot(pax, current_angles_rad, current_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        
        legend('信号点', '历史溢出点', '当前帧溢出点', 'Location', 'southoutside');
        
    else
        % 非驻留模式：只绘制当前帧的溢出点
        is_current_frame = (all_frames == frame_to_load);
        valid_current = ismember(all_ranges_bin, range_to_plot) & is_current_frame;
        
        current_angles_rad = deg2rad(all_angles_deg(valid_current));
        current_ranges_bin = all_ranges_bin(valid_current);
        
        polarplot(pax, current_angles_rad, current_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        legend('信号点', '当前帧溢出点', 'Location', 'southoutside');
    end
end

hold(pax, 'off');

end
