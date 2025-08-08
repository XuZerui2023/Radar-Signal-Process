function fun_plot_overflow_ppi_v5(h_fig, raw_iq_data, servo_angle, plot_params)
% FUN_PLOT_OVERFLOW_DASHBOARD - 统一的溢出点可视化仪表盘
%
% v1.1 更新:
% - 新增 'summary' 绘图模式，可以在同一个窗口中并排显示PPI图和距离-方位图。
% - 优化了代码结构，将绘图逻辑封装在更小的本地函数中。
%
% 输入参数:
%   h_fig         - (figure handle) 用于绘图的图窗句柄。
%   raw_iq_data   - (complex 3D matrix / []) 单帧原始I/Q数据，或在累积模式下为空[]。
%   servo_angle   - (double vector / []) 【已修正】的角度序列，或在累积模式下为空[]。
%   plot_params   - (struct) 包含所有绘图和分析所需参数的结构体。

%% 1. 清空整个图窗并获取参数
% figure(h_fig);
% clf; % 清空整个figure，为新的坐标轴做准备

plot_mode = plot_params.plot_mode;

%% 2. 根据绘图模式选择并执行绘图逻辑
switch plot_mode
    case 'ppi'
        % --- 模式A: 单独绘制极坐标PPI图 ---
        fig1 = figure(1);
        pax = polaraxes(fig1);
        pax.ThetaZeroLocation = 'top';
        pax.ThetaDir = 'clockwise';
        pax.ThetaLim = [0 360];
        pax.RLim = [0 max(plot_params.range_to_plot)];
        draw_ppi_content(pax, raw_iq_data, servo_angle, plot_params);
        
    case 'az_range'
        % --- 模式B: 单独绘制直角坐标距离-方位图 ---
        fig2 = figure(2);
        ax = axes(fig2);
        draw_az_range_content(ax, raw_iq_data, servo_angle, plot_params);
        
    case 'summary'
        % --- 【新增】模式C: 显示PPI图和距离-方位图 ---

        % 在第一个子图中绘制PPI图
        fig1 = figure(1);
        pax = polaraxes(fig1);
        pax.ThetaZeroLocation = 'top';
        pax.ThetaDir = 'clockwise';
        pax.ThetaLim = [0 360];
        pax.RLim = [0 max(plot_params.range_to_plot)];
        draw_ppi_content(pax, raw_iq_data, servo_angle, plot_params);
        
        % 在第二个子图中绘制距离-方位图
        fig2 = figure(2);
        ax = axes(fig2);
        draw_az_range_content(ax, raw_iq_data, servo_angle, plot_params);
        
    otherwise
        warning('未知的绘图模式: %s', plot_mode);
end

end

%% ========================================================================
% 本地绘图核心函数 (Local Helper Functions)
% ========================================================================

function draw_ppi_content(pax, raw_iq_data, servo_angle, plot_params)
    % --- 专门负责绘制PPI图 ---
    
    % 1. 获取参数
    channel_to_plot = plot_params.channel_to_plot;
    range_to_plot = plot_params.range_to_plot;
    point_PRT = plot_params.point_PRT;
    frame_to_load = plot_params.frame_to_load;
    persist_display = plot_params.persist_display;
    overflow_log = plot_params.overflow_log;

    % 2. 准备数据和设置标题
    hold(pax, 'on');
    legend_items = []; legend_texts = {};

    if ~isempty(raw_iq_data) % 动态模式
        iq_channel_data = raw_iq_data(:, :, channel_to_plot);
        amplitude = abs(iq_channel_data);
        amplitude_to_plot = amplitude(:, range_to_plot);
        angles_rad = deg2rad(servo_angle);
        ranges = 1:point_PRT;
        [THETA_grid, RHO_grid] = meshgrid(angles_rad, ranges(range_to_plot));
        h_scatter = polarscatter(pax, THETA_grid(:), RHO_grid(:), 10, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
        if ~isempty(h_scatter), legend_items(end+1) = h_scatter; legend_texts{end+1} = '信号点'; end
        colorbar(pax);
        title(pax, sprintf('PPI图 (帧 #%d, 通道 #%d)', frame_to_load, channel_to_plot));
    else % 累积模式
        title(pax, sprintf('累积溢出点PPI图 (通道 #%d)', channel_to_plot));
    end

    % 3. 标记溢出点
    if ~isempty(overflow_log)
        all_angles_deg = [overflow_log.angle_deg];
        all_ranges_bin = [overflow_log.range_bin];
        all_frames = [overflow_log.frame];
        
        if frame_to_load ~= -1 && persist_display % 动态模式 + 驻留
            valid_history = ismember(all_ranges_bin, range_to_plot);
            h_hist = polarplot(pax, deg2rad(all_angles_deg(valid_history)), all_ranges_bin(valid_history), '.', 'Color', [0.5 0.5 0.5 0.5]);
            if ~isempty(h_hist), legend_items(end+1) = h_hist; legend_texts{end+1} = '历史溢出点'; end

            is_current_frame = (all_frames == frame_to_load);
            current_valid = valid_history & is_current_frame;
            h_curr = polarplot(pax, deg2rad(all_angles_deg(current_valid)), all_ranges_bin(current_valid), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
            if ~isempty(h_curr), legend_items(end+1) = h_curr; legend_texts{end+1} = '当前帧溢出点'; end
        else % 累积模式或非驻留动态模式
            is_current_frame = (all_frames == frame_to_load);
            if frame_to_load == -1, points_to_plot_mask = true(size(all_frames)); else, points_to_plot_mask = is_current_frame; end
            valid_points = ismember(all_ranges_bin, range_to_plot) & points_to_plot_mask;
            h_cum = polarplot(pax, deg2rad(all_angles_deg(valid_points)), all_ranges_bin(valid_points), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
            if ~isempty(h_cum), legend_items(end+1) = h_cum; legend_texts{end+1} = '溢出点'; end
        end
    end
    
    % 4. 显示图例
    if ~isempty(legend_items), legend(pax, legend_items, legend_texts, 'Location', 'southoutside'); end
    hold(pax, 'off');
end

function draw_az_range_content(ax, raw_iq_data, servo_angle, plot_params)
    % --- 专门负责绘制距离-方位图 ---

    % 1. 获取参数
    channel_to_plot = plot_params.channel_to_plot;
    range_to_plot = plot_params.range_to_plot;
    point_PRT = plot_params.point_PRT;
    frame_to_load = plot_params.frame_to_load;
    persist_display = plot_params.persist_display;
    overflow_log = plot_params.overflow_log;

    % 2. 准备数据和设置标题
    hold(ax, 'on');
    legend_items = []; legend_texts = {};

    if ~isempty(raw_iq_data) % 动态模式
        iq_channel_data = raw_iq_data(:, :, channel_to_plot);
        amplitude = abs(iq_channel_data);
        amplitude_to_plot = amplitude(:, range_to_plot);
        [X_grid, Y_grid] = meshgrid(servo_angle, range_to_plot);
        h_scatter = scatter(ax, X_grid(:), Y_grid(:), 10, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
        if ~isempty(h_scatter), legend_items(end+1) = h_scatter; legend_texts{end+1} = '信号点'; end
        colorbar(ax);
        title(ax, sprintf('距离-方位图 (帧 #%d, 通道 #%d)', frame_to_load, channel_to_plot));
    else % 累积模式
        title(ax, sprintf('累积溢出点 距离-方位图 (通道 #%d)', channel_to_plot));
    end

    % 3. 标记溢出点
    if ~isempty(overflow_log)
        all_angles_deg = [overflow_log.angle_deg];
        all_ranges_bin = [overflow_log.range_bin];
        all_frames = [overflow_log.frame];
        
        if frame_to_load ~= -1 && persist_display % 动态模式 + 驻留
            valid_history = ismember(all_ranges_bin, range_to_plot);
            h_hist = plot(ax, all_angles_deg(valid_history), all_ranges_bin(valid_history), '.', 'Color', [0.5 0.5 0.5 0.5]);
            if ~isempty(h_hist), legend_items(end+1) = h_hist; legend_texts{end+1} = '历史溢出点'; end

            is_current_frame = (all_frames == frame_to_load);
            current_valid = valid_history & is_current_frame;
            h_curr = plot(ax, all_angles_deg(current_valid), all_ranges_bin(current_valid), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
            if ~isempty(h_curr), legend_items(end+1) = h_curr; legend_texts{end+1} = '当前帧溢出点'; end
        else % 累积模式或非驻留动态模式
            is_current_frame = (all_frames == frame_to_load);
            if frame_to_load == -1, points_to_plot_mask = true(size(all_frames)); else, points_to_plot_mask = is_current_frame; end
            valid_points = ismember(all_ranges_bin, range_to_plot) & points_to_plot_mask;
            h_cum = plot(ax, all_angles_deg(valid_points), all_ranges_bin(valid_points), 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
            if ~isempty(h_cum), legend_items(end+1) = h_cum; legend_texts{end+1} = '溢出点'; end
        end
    end

    % 4. 美化图形
    xlabel(ax, '方位角 (度)');
    ylabel(ax, '距离单元');
    grid(ax, 'on');
    xlim(ax, [-180, 180]);
    
    if ~isempty(legend_items), legend(ax, legend_items, legend_texts, 'Location', 'southoutside'); end
    hold(ax, 'off');
end
