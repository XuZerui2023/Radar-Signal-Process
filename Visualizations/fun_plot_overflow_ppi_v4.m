function fun_plot_overflow_ppi_v4(pax, raw_iq_data, servo_angle, plot_params)
% FUN_PLOT_OVERFLOW_PPI_v5.m
%
% v4.0 更新:
% - 修复了当没有溢出点可绘制时，向图例列表赋值空句柄导致的"元素数目不同"错误。
% - 对所有绘图句柄在添加到图例前都增加了非空检查，提高了代码的稳健性。
%
% 输入参数:
%   pax           - (polaraxes handle) 用于绘图的极坐标轴句柄。
%   raw_iq_data   - (complex 3D matrix / []) 单帧原始I/Q数据，或在累积模式下为空[]。
%   servo_angle   - (double vector / []) 【已修正】的角度序列，或在累积模式下为空[]。
%   plot_params   - (struct) 包含所有绘图和分析所需参数的结构体。

%% 1. 清空上一次的绘图内容
cla(pax); % 只清空传入的坐标轴

%% 2. 获取参数
channel_to_plot = plot_params.channel_to_plot;
range_to_plot = plot_params.range_to_plot;
point_PRT = plot_params.point_PRT;
frame_to_load = plot_params.frame_to_load;
persist_display = plot_params.persist_display;
overflow_log = plot_params.overflow_log;

%% 3. 绘制背景和设置标题
hold(pax, 'on'); % 从一开始就保持图形
legend_items = [];
legend_texts = {};

% --- 根据 raw_iq_data 是否为空来判断模式 ---
if ~isempty(raw_iq_data)
    % --- 动态模式：绘制背景幅度图 ---
    iq_channel_data = raw_iq_data(:, :, channel_to_plot);
    amplitude = abs(iq_channel_data);
    angles_rad = deg2rad(servo_angle); 
    ranges = 1:point_PRT;
    amplitude_to_plot = amplitude(:, range_to_plot);
    
    [THETA_grid, RHO_grid] = meshgrid(angles_rad, ranges(range_to_plot));
    h_scatter = polarscatter(pax, THETA_grid(:), RHO_grid(:), 10, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
    
    % 【修正】只有在确实画了散点图后才添加图例项
    if ~isempty(h_scatter)
        legend_items(end+1) = h_scatter;
        legend_texts{end+1} = '信号点';
    end
    
    colorbar(pax);
    title(pax, sprintf('帧 #%d, 通道 #%d 幅度与溢出点分布', frame_to_load, channel_to_plot));
else
    % --- 累积模式：不绘制背景，只设置标题 ---
    title(pax, sprintf('所有帧累积溢出点分布 (通道 #%d)', channel_to_plot));
end

%% 4. 标记溢出点
if ~isempty(overflow_log)
    all_angles_deg = [overflow_log.angle_deg];
    all_ranges_bin = [overflow_log.range_bin];
    all_frames = [overflow_log.frame];
    
    if frame_to_load ~= -1 && persist_display % 动态模式 + 驻留显示
        % 绘制历史溢出点
        valid_history = ismember(all_ranges_bin, range_to_plot);
        history_angles_rad = deg2rad(all_angles_deg(valid_history));
        history_ranges_bin = all_ranges_bin(valid_history);
        h_hist = polarplot(pax, history_angles_rad, history_ranges_bin, '.', 'Color', [0.5 0.5 0.5 0.5]);
        % 【修正】增加非空检查
        if ~isempty(h_hist)
            legend_items(end+1) = h_hist;
            legend_texts{end+1} = '历史溢出点';
        end
        
        % 绘制当前帧溢出点
        is_current_frame = (all_frames == frame_to_load);
        current_valid = valid_history & is_current_frame;
        current_angles_rad = deg2rad(all_angles_deg(current_valid));
        current_ranges_bin = all_ranges_bin(current_valid);
        h_curr = polarplot(pax, current_angles_rad, current_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        % 【修正】增加非空检查
        if ~isempty(h_curr)
            legend_items(end+1) = h_curr;
            legend_texts{end+1} = '当前帧溢出点';
        end

    elseif frame_to_load ~= -1 && ~persist_display % 动态模式 + 不驻留
        is_current_frame = (all_frames == frame_to_load);
        valid_current = ismember(all_ranges_bin, range_to_plot) & is_current_frame;
        current_angles_rad = deg2rad(all_angles_deg(valid_current));
        current_ranges_bin = all_ranges_bin(valid_current);
        h_curr = polarplot(pax, current_angles_rad, current_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        % 【修正】增加非空检查
        if ~isempty(h_curr)
            legend_items(end+1) = h_curr;
            legend_texts{end+1} = '当前帧溢出点';
        end
        
    else % 累积模式 (frame_to_load == -1)
        valid_points = ismember(all_ranges_bin, range_to_plot);
        all_angles_rad = deg2rad(all_angles_deg(valid_points));
        all_ranges = all_ranges_bin(valid_points);
        h_cum = polarplot(pax, all_angles_rad, all_ranges, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        % 【修正】增加非空检查
        if ~isempty(h_cum)
            legend_items(end+1) = h_cum;
            legend_texts{end+1} = '累积溢出点';
        end
    end
end

%% 5. 显示图例
if ~isempty(legend_items)
    legend(pax, legend_items, legend_texts, 'Location', 'southoutside');
end
hold(pax, 'off');

end
