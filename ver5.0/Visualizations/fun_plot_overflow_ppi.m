function [overflow_prt_indices, overflow_range_indices] = fun_plot_overflow_ppi(frame_to_load, h_fig, raw_iq_data, servo_angle, plot_params)
% FUN_PLOT_OVERFLOW_PPI - 对单帧原始I/Q数据进行溢出分析并用极坐标图可视化
%
% 输入参数:
%   h_fig         - (figure handle)
%   用于绘图的图窗句柄。主程序通过传递这个句柄，确保所有绘图都在同一个窗口刷新，而不是创建新窗口。
%   raw_iq_data   - (complex 3D matrix) 单帧的原始I/Q数据 (prtNum x point_PRT x channel_num)。
%   servo_angle   - (double vector) 与数据帧对应的伺服角度序列。
%   plot_params   - (struct) 包含所有绘图和分析所需参数的结构体。

%% 0. 激活并清空指定的图窗
figure(h_fig);    % 使用主函数传入的句柄来激活目标图窗
clf;              % 清空当前图窗的内容，为新的绘图做准备

%% 1. 从参数结构体中获取所需参数
% 将所有配置从一个结构体中取出，增强了函数的通用性。
channel_to_plot = plot_params.channel_to_plot;             % 获取用户想要分析的具体物理通道号
SATURATION_THRESHOLD = plot_params.SATURATION_THRESHOLD;   % 获取主函数设置的DDC饱和的检测门限值
range_to_plot = plot_params.range_to_plot;                 % 获取用户想要在图上显示的距离范围（以距离单元计）
point_PRT = plot_params.point_PRT;                         % 获取一个PRT的总距离单元数

%% 2. 数据准备与溢出检测
% --- 提取指定通道的I和Q分量 ---
iq_channel_data = raw_iq_data(:, :, channel_to_plot);
i_data = real(iq_channel_data);
q_data = imag(iq_channel_data);

% --- 计算信号幅度 ---
amplitude = abs(iq_channel_data);

% --- 查找溢出点 ---
overflow_mask_i = abs(i_data) >= SATURATION_THRESHOLD;     % 创建一个逻辑矩阵，I路溢出的位置为1。
overflow_mask_q = abs(q_data) >= SATURATION_THRESHOLD;     % 创建一个逻辑矩阵，Q路溢出的位置为1。
overflow_mask = overflow_mask_i | overflow_mask_q;         % 使用逻辑"或"操作，合并两个矩阵。

% 使用 find 函数返回所有非零元素（即值为1）的行、列索引。
[overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
% fprintf('  > 在通道 %d 中共发现 %d 个溢出点。\n', channel_to_plot, numel(overflow_prt_indices));

%% 3. 极坐标图（PPI）可视化
% --- 创建一个极坐标轴 ---
pax = polaraxes;                 % 创建一个极坐标系作为绘图区域。
pax.ThetaZeroLocation = 'top';   % 将0度方向设置在图的正上方，模拟罗盘的北方。
pax.ThetaDir = 'clockwise';      % 设置角度的增加方向为顺时针，符合雷达扫描的习惯。
pax.ThetaLim = [0 360];          % 将角度范围限定在0到360度。

% --- 准备用于绘图的数据 ---
angles_rad = deg2rad(servo_angle);                 % polarscatter/polarplot函数需要使用弧度制，因此将角度从度转换为弧度。
ranges = 1:point_PRT;                              % 创建一个代表距离单元索引的向量。
% num_ranges = min(max_range_to_plot, point_PRT);  % 确定实际要绘制的距离单元数量，避免图像过于拥挤。

amplitude_to_plot = amplitude(:, range_to_plot);   % 从总幅度数据中，只截取需要绘制的部分。

% --- 绘制背景幅度图 ---
[THETA_grid, RHO_grid] = meshgrid(angles_rad, ranges(range_to_plot));
polarscatter(pax, THETA_grid(:), RHO_grid(:), 10, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
colorbar;
title(sprintf('帧%d, 通道%d 幅度与溢出点分布', frame_to_load, channel_to_plot));

% --- 标记溢出点 ---
if ~isempty(overflow_prt_indices)
    valid_overflow = overflow_range_indices <= max(range_to_plot);
    overflow_angles = angles_rad(overflow_prt_indices(valid_overflow));
    overflow_ranges = overflow_range_indices(valid_overflow);
    
    hold(pax, 'on');
    polarplot(pax, overflow_angles, overflow_ranges, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
    hold(pax, 'off');
    legend('信号点', '溢出点', 'Location', 'southoutside');
end

% 设置极坐标图的径向（距离）范围
pax.RLim = [0 max(range_to_plot)];

end
