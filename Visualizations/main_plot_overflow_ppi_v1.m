% main_plot_overflow_ppi_v1.m 文件
% 此函数用于在 main_get_iq_data.m 文件提取信号文件的原始iq数据后绘制ppi图像显示溢出点
% 这版本是手动选择单帧进行处理的
% 修改记录
% date       by      version   modify
% 25/06/26   XZR      v1.0      创建


clc, clear, close all;
%% 1. 用户配置区
% --- 指定要分析的文件 ---
n_exp = 3;
frame_to_load = 30; % 指定要加载和分析的帧编号
% --- 溢出检测阈值 ---
% 对于16位有符号ADC，其最大值为 2^15 - 1 = 32767。
% 我们可以设置一个略小于此值的阈值来检测饱和/溢出。
SATURATION_THRESHOLD = 32760;

% --- 绘图参数 ---
channel_to_plot = 1; % 指定要分析和显示的物理通道 (1 到 16)
max_range_to_plot = 3000; % 只显示最近3000个距离单元的数据，避免图像过于拥挤

% 加载雷达距离单元参数
% 注意：这里的point_PRT应与数据生成时 Sig_Config 中的定义一致
point_PRT = 3404;

%% 3. 加载数据

% [mat_filename, mat_pathname] = uigetfile;    % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
% if isequal(mat_pathname, 0)
%     disp('用户取消了文件选择。');
%     return;
% else
%     fullFile = fullfile(mat_pathname, mat_filename);
%     disp(['已选择文件路径: ', fullFile]);
% end
bath_path = 'D:\MATLAB workplace\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\3\raw_iq_data'; 

% 构建文件名部分
filename = ['frame_', num2str(frame_to_load), '.mat']; 
fullFile = fullfile(bath_path, filename);

if exist(fullFile, 'file')
    fprintf('正在加载文件: %s\n', fullFile);
    % 假设您已将原始I/Q数据以 'raw_iq_data' 变量名保存
    % 如果没有，您需要先修改第一阶段的代码来保存它

    load_data = load(fullFile, 'raw_iq_data', 'servo_angle');

    if ~isfield(load_data, 'raw_iq_data')
        error('错误: .mat文件中未找到 "raw_iq_data" 变量。请先修改第一阶段代码以保存原始I/Q数据。');
    end
    raw_iq_data = load_data.raw_iq_data; % 维度: (prtNum, channel_num)
    servo_angle = load_data.servo_angle; % 维度: (1, prtNum)
else
    error('数据文件不存在: %s', fullFile);
end

%% 4. 数据准备与溢出检测
% --- 提取指定通道的I和Q分量 ---
iq_channel_data = raw_iq_data(:, :, channel_to_plot); % 提取单个通道数据
i_data = real(iq_channel_data);
q_data = imag(iq_channel_data);

% --- 计算信号幅度 ---
amplitude = abs(iq_channel_data);

% --- 查找溢出点 ---
% 检查I或Q分量是否达到饱和阈值
overflow_mask_i = abs(i_data) >= SATURATION_THRESHOLD;
overflow_mask_q = abs(q_data) >= SATURATION_THRESHOLD;
overflow_mask = overflow_mask_i | overflow_mask_q; % I或Q溢出都算溢出

% 获取所有溢出点的索引 (prt索引, 距离索引)
[overflow_prt_indices, overflow_range_indices] = find(overflow_mask);

fprintf('在通道 %d 中共发现 %d 个溢出点。\n', channel_to_plot, numel(overflow_prt_indices));

%% 5. 极坐标图（PPI）可视化
fprintf('正在生成极坐标图...\n');
figure('Name', sprintf('帧 #%d, 通道 #%d 的溢出分析', frame_to_load, channel_to_plot), ...
       'NumberTitle', 'off', 'Position', [100, 100, 800, 800]);

% --- 创建一个极坐标轴 ---
pax = polaraxes;
pax.ThetaZeroLocation = 'top'; % 将0度设置在顶部 (正北方向)
pax.ThetaDir = 'clockwise';    % 顺时针方向为角度增加方向


pax.ThetaLim = [0 360];        % 角度范围

% --- 准备用于pcolor的数据 ---
% 角度 (theta)
angles_rad = deg2rad(servo_angle); % 将角度从度转换为弧度
% 距离 (rho)
ranges = 1:point_PRT;

% pcolor需要网格数据，我们这里简化一下，只画出点的幅度
% 为了性能，我们只绘制部分距离的数据
num_ranges = min(max_range_to_plot, point_PRT);
amplitude_to_plot = amplitude(:, 1:num_ranges);

% --- 绘制背景幅度图 ---

% 使用 pcolor 可以创建填充的扇区图，但设置起来较复杂
% 这里我们使用一种更简单的方法：用 polarscatter 绘制所有点的散点图
[THETA_grid, RHO_grid] = meshgrid(angles_rad, ranges(1:num_ranges));
polarscatter(pax, THETA_grid(:), RHO_grid(:), 1, amplitude_to_plot(:).', 'filled', 'MarkerFaceAlpha', 0.5);
colorbar;
title(sprintf('帧 #%d, 通道 #%d 幅度与溢出点分布', frame_to_load, channel_to_plot));

% --- 在图上用醒目的方式标记溢出点 ---
if ~isempty(overflow_prt_indices)
    % 获取溢出点的角度和距离
    overflow_angles = angles_rad(overflow_prt_indices);
    overflow_ranges = overflow_range_indices;

    hold(pax, 'on');
    % 用红色的'x'标记溢出点
    polarplot(pax, overflow_angles, overflow_ranges, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
    hold(pax, 'off');
    legend('信号点', '溢出点');
end

% 设置距离轴的范围
pax.RLim = [0 num_ranges];