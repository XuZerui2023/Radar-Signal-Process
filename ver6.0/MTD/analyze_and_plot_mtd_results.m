% analyze_and_plot_mtd_results.m
%
% 本脚本专门用于加载由 main_produce_dataset_win_xzr_v2.m 生成的MTD结果文件，
% 并对其进行可视化分析。

clc; clear; close all;

%% 1. 定义需要分析的目标
% --- 指定要加载的文件 ---
n_exp = 1;         % 实验编号 (必须与生成数据时使用的编号一致)
win_size = 4;      % 窗口大小 (必须与生成数据时使用的编号一致)
frame_to_load = 2; % 指定要加载和分析的帧编号

% --- 指定要可视化的数据切片 ---
beam_to_plot = 1;  % 指定要查看的波束 (例如, 第1个波束，范围是1-13波束)
slice_to_plot = 1; % 指定要查看的窗口切片 (例如, 第1个切片, 范围是 1 到 win_size)

%% 2. 加载雷达系统参数
% !!! 关键步骤 !!!
% 绘图函数需要雷达的物理参数来计算坐标轴。
% 由于这些参数没有保存在MTD结果文件中，我们必须在这里重新定义它们。
% 这些参数必须与 main_produce_dataset_win_xzr_v2.m 中的定义完全一致。

% 2.1 物理常数
params.c = 2.99792458e8;
params.pi = pi;

% 2.2 雷达系统核心参数
params.fs = 25e6;
params.fc = 9450e6;
params.prt = 232.76e-6;
params.B = 20e6;

% 2.3 派生参数计算
params.prf = 1 / params.prt;
params.wavelength = params.c / params.fc;
params.deltaR = params.c / (2 * params.fs);

%% 3. 加载MTD结果文件
% --- 构建文件路径 ---
base_path = 'D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\';
output_MTD_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);
mtd_filename = fullfile(output_MTD_path, ['frame_', num2str(frame_to_load), '.mat']);

% --- 加载数据 ---
if exist(mtd_filename, 'file')
    fprintf('正在加载文件: %s\n', mtd_filename);
    load_data = load(mtd_filename);
    MTD_win_all_beams = load_data.MTD_win_all_beams;
else
    error('MTD结果文件不存在: %s', mtd_filename);
end

%% 4. 从数据结构中提取要绘图的二维RDM
% 检查指定的波束和切片索引是否有效
if beam_to_plot > numel(MTD_win_all_beams) || beam_to_plot < 1
    error('指定的波束索引 %d 超出范围 (1 到 %d)。', beam_to_plot, numel(MTD_win_all_beams));
end

data_for_one_beam = MTD_win_all_beams{beam_to_plot};
[num_slices, ~, ~] = size(data_for_one_beam);

if slice_to_plot > num_slices || slice_to_plot < 1
    error('指定的切片索引 %d 超出范围 (1 到 %d)。', slice_to_plot, num_slices);
end

% 提取出目标二维矩阵 (速度 x 距离)
% squeeze() 函数用于移除尺寸为1的维度
mtd_signal_to_plot = squeeze(data_for_one_beam(slice_to_plot, :, :));

%% 5. 调用绘图函数进行可视化
fprintf('正在为第 %d 帧, 第 %d 波束, 第 %d 切片的数据绘图...\n', frame_to_load, beam_to_plot, slice_to_plot);

plot_funs = 'pulse_compression';

switch plot_funs
    case 'fun_plot_mtd_dashboard'
        % 调用选择的绘图函数，"仪表盘"函数包括 3D MTD视图、2D MTD俯视图以及距离维和速度维的切片
        fun_plot_mtd_dashboard(mtd_signal_to_plot, params);

    case 'pulse_compression'
        % 脉冲压缩的动态图
        fun_plot_visualizations('pulse_compression', struct('mtd_signal', mtd_signal_to_plot), params);

    case 'fft_dynamic'
        % 绘制速度维FFT的动态图
        fun_plot_visualizations('fft_dynamic', struct('mtd_signal', mtd_signal_to_plot), params);

    case 'mtd_3d'
        % 调用3D MTD视图
        fun_plot_visualizations('mtd_3d', struct('mtd_signal', mtd_signal_to_plot), params);
        
end