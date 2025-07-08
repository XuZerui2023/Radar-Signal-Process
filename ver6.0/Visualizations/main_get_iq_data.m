% main_get_iq_data.m 该函数已经弃用
% 此函数用于在 main_plot_overflow_ppi_v1.m 文件前提取信号文件的原始iq数据，它们是分开实现的
% 本脚本用于加载第一阶段生成的.mat文件，分析原始I/Q数据是否存在溢出，
% 并通过极坐标图（PPI 平面位置显示）进行可视化。
% 修改记录
% date       by      version   modify
% 25/06/26   XZR      v1.0      创建

clc;clear; close all;

% 在脚本开始时清除所有相关函数的持久化状态，确保每次运行都从头开始
clear read_continuous_file_stream;  % 清除 read_continuous_file_stream 的持久化状态（持久性变量）
clear FrameDataRead_xzr;            % 清除 FrameDataRead_xzr 的持久化状态（持久性变量）
clear manage_retry_count;           % 清除 manage_retry_count 的持久化状态（持久性变量）

%% 1. 基础参数设置（由实际采样的雷达体制和信号特征决定）
% --- 雷达系统基础参数 ---
MHz = 1e6; % 定义MHz单位
config.Sig_Config.c = 2.99792458e8;            % 光速
config.Sig_Config.pi = pi;                     % 圆周率
config.Sig_Config.fs = 25e6;                   % 采样率 (Hz)
config.Sig_Config.fc = 9450e6;                 % 中心频率 (Hz)
config.Sig_Config.timer_freq = 200e6;          % 时标计数频率 
config.Sig_Config.prtNum = 332;                % 定义每帧信号的脉冲数，每帧信号包含 332 个脉冲
config.Sig_Config.point_PRT = 3404;            % 定义每个PRT中的采样点数（时间轴）
config.Sig_Config.channel_num = 16;            % 通道数（阵元数目）
config.Sig_Config.beam_num = 13;               % 波束数
config.Sig_Config.prt = 232.76e-6;             % 脉冲重复时间 (s)
config.Sig_Config.prf = 1/config.Sig_Config.prt;
config.Sig_Config.B = 20e6;                    % 带宽 (Hz)
config.Sig_Config.bytesFrameHead = 64;         % 每个PRT帧头字节数
config.Sig_Config.bytesFrameEnd = 64;          % 每个PRT帧尾字节数
config.Sig_Config.bytesFrameRealtime = 128;    % 实时参数的字节数 
config.Sig_Config.tao = [0.16e-6, 8e-6, 28e-6];       % 脉宽 [窄, 中, 长]
config.Sig_Config.point_prt = [3404, 228, 723, 2453]; % 采集点数 [总采集点数，窄脉冲采集点数，中脉冲采集点数，长脉冲采集点数]   
config.Sig_Config.wavelength = config.Sig_Config.c / config.Sig_Config.fc;   % 信号波长
config.Sig_Config.deltaR = config.Sig_Config.c / (2 * config.Sig_Config.fs); % 距离分辨率由采样率决定
config.Sig_Config.tao1 = config.Sig_Config.tao(1);    % 窄脉宽 
config.Sig_Config.tao2 = config.Sig_Config.tao(2);    % 中脉宽
config.Sig_Config.tao3 = config.Sig_Config.tao(3);    % 长脉宽
config.Sig_Config.K1   = config.Sig_Config.B/config.Sig_Config.tao1;   % 短脉冲调频斜率
config.Sig_Config.K2   = -config.Sig_Config.B/config.Sig_Config.tao2;  % 中脉冲调频斜率（负）
config.Sig_Config.K3   = config.Sig_Config.B/config.Sig_Config.tao3;   % 长脉冲调频斜率

%% 2. 文件路径与参数设置
n_exp = 3;        % 该文件夹编号

base_path  = uigetdir;                         % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(base_path, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(base_path);
    disp(['已选择文件路径: ', fullFile]);
end

filepath = fullfile(base_path, num2str(n_exp), '2025年05月22日17时10分05秒'); % 原始二进制bin文件路径
iq_data_path = fullfile(base_path, num2str(n_exp), '\raw_iq_data');           % 保存iq_data文件路径
mkdir(iq_data_path);
 
%% 3.信号处理部分
tic;
frameRInd = 0; % 从第0帧开始处理
max_frames_to_process = 100; % 要处理的总的帧数，可以根据实际数据量调整

while frameRInd <= max_frames_to_process
    fprintf('main_visualize_overflow.m: 尝试处理逻辑帧 %d\n', frameRInd);
    
    %  调用 frameDataRead_A_xzr_V2 来读取一帧数据
    %  frameDataRead_A_xzr_V2 内部会调用 read_continuous_file_stream 来获取字节流
    [raw_iq_data, servo_angle, frameCompleted, is_global_stream_end] = FrameDataRead_xzr_raw_iq(filepath, config, frameRInd);
    
    if frameCompleted
        % 如果帧已完成，保存数据并处理下一帧
        save(fullfile(iq_data_path, ['frame_',num2str(frameRInd),'.mat']),'raw_iq_data','servo_angle');
        disp(['已处理并保存第',num2str(frameRInd),'帧。']);
        frameRInd = frameRInd + 1; % 移动到下一帧
        manage_retry_count('reset'); % 成功处理一帧后重置重试计数
    else
        % 如果帧未完成（因为最后数据流末尾截断或无效PRT），
        warning('main_visualize_overflow.m: 帧 %d 未能完整读取。', frameRInd);
        
        if is_global_stream_end
            % 如果底层数据流已经结束，则无法继续处理更多帧
            fprintf('main_visualize_overflow.m: 已到达所有数据流的末尾，停止处理。\n');
            break; % 退出主循环
        else
            % 如果数据流未结束，但当前帧未完成，可能是数据格式问题或临时截断，尝试重试当前帧
            % frameRInd 不变，循环会再次尝试读取同一逻辑帧。
            current_retry_count = manage_retry_count('increment');
            if current_retry_count > 1000 % 连续尝试1000次同一帧，可能数据有问题
                error('main_visualize_overflow.m: 连续尝试读取同一帧 %d 失败次数过多，可能数据文件损坏或逻辑错误。', frameRInd);
            end
        end
    end
    
end
disp(toc);
disp('所有帧处理完成。');



%% 1. 用户配置区
% --- 指定要分析的文件 ---
% n_exp = 3;
frame_to_load = 0; % 指定要加载和分析的帧编号

% --- 溢出检测阈值 ---
% 对于16位有符号ADC，其最大值为 2^15 - 1 = 32767。
% 我们可以设置一个略小于此值的阈值来检测饱和/溢出。
SATURATION_THRESHOLD = 32760;

% --- 绘图参数 ---
channel_to_plot = 1; % 指定要分析和显示的物理通道 (1 到 16)
max_range_to_plot = 2000; % 只显示最近2000个距离单元的数据，避免图像过于拥挤

%
% 加载雷达距离单元参数
% 注意：这里的point_PRT应与数据生成时 Sig_Config 中的定义一致
point_PRT = 3404;

%% 3. 加载数据

[mat_filename, mat_pathname] = uigetfile;                         % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(mat_pathname, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(mat_pathname, mat_filename);
    disp(['已选择文件路径: ', fullFile]);
end

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
iq_channel_data = raw_iq_data(:, channel_to_plot, :); % 提取单个通道数据
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

