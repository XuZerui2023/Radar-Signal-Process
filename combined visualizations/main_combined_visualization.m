% main_combined_visualization.m
%
% 这是一个用于联合可视化分析的主控脚本。
%
% --- 工作流程 ---
% 1. 提示用户选择包含"累积CFAR目标日志"的文件夹。
% 2. 提示用户选择包含"累积溢出点日志"的文件夹。
% 3. 加载这两个核心的日志文件。
% 4. 调用一个统一的绘图函数，将两种数据点绘制在同一个直角坐标距离-方位图上。
%
% 修改记录
% date       by      version   modify
% 25/07/30   XZR      v1.0      创建

clc; clear; close all;

%% 1. 用户配置区
% =========================================================================
% --- 角度修正参数 ---
NorthAngle = 307;
FixAngle = 35;

%% 2. 加载数据
% =========================================================================
fprintf('--- 开始加载数据以进行联合可视化 ---\n');

% --- 2.1 加载累积的CFAR目标检测日志 ---
[cfar_log_file, cfar_log_path] = uigetfile('*.mat', '请选择累积的CFAR目标日志文件 (detection_log.mat)');
if isequal(cfar_log_file, 0), disp('用户取消了选择。'); return; end
fprintf('正在加载CFAR目标日志: %s\n', fullfile(cfar_log_path, cfar_log_file));
try
    % 假设变量名为 'detection_log' 或 'final_log'
    cfar_data = load(fullfile(cfar_log_path, cfar_log_file));
    if isfield(cfar_data, 'cumulative_final_log')
        detection_log = cfar_data.cumulative_final_log;
    elseif isfield(cfar_data, 'final_log')
        detection_log = cfar_data.final_log;
    else
        error('在CFAR日志文件中未找到 "detection_log" 或 "final_log" 变量。');
    end
catch ME
    error('加载CFAR日志文件失败: %s', ME.message);
end

% --- 2.2 加载累积的脉冲压缩后溢出点日志 ---
[overflow_log_file, overflow_log_path] = uigetfile('*.mat', '请选择累积的脉冲压缩后溢出点日志文件 (overflow_log.mat)');
if isequal(overflow_log_file, 0), disp('用户取消了选择。'); return; end
fprintf('正在加载溢出点日志: %s\n', fullfile(overflow_log_path, overflow_log_file));
try
    overflow_data = load(fullfile(overflow_log_path, overflow_log_file));
    overflow_log = overflow_data.overflow_log;
catch ME
    error('加载溢出点日志文件失败: %s', ME.message);
end

fprintf('数据加载完成。\n');

%% 3. 调用绘图函数
% =========================================================================
fprintf('--- 正在生成联合可视化图表 ---\n');

% 准备参数
params.NorthAngle = NorthAngle;
params.FixAngle = FixAngle;

% 创建图形窗口并调用新的绘图函数
h_fig = figure('Name', 'CFAR检测与信号溢出联合分析', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 750]);
fun_plot_combined_az_range(h_fig, detection_log, overflow_log, params);

fprintf('--- 可视化分析完成 ---\n');
