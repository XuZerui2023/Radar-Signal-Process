% main_plot_pc_overflow.m
% 
% 这是一个专门用于分析"脉冲压缩后（PC）"数据溢出点的"一站式"主控脚本。
%
% --- 工作流程 ---
% 1. 遍历指定的 'pulse_compressed_data' 文件夹，加载所有按帧存储的 .mat 文件。
% 2. 对每一帧的脉冲压缩数据进行溢出检测。
% 3. 将所有帧中检测到的溢出点信息，累积到一个总的日志结构体中。
% 4. 调用一个统一的绘图函数，对累积的溢出点进行可视化，支持PPI和直角坐标两种模式。
%
% 修改记录
% date       by      version   modify
% 25/07/16   XZR      v1.0      创建，用于分析脉冲压缩后的数据溢出

clc; clear; close all;

%% 1. 用户配置区
% =========================================================================
% --- 1.1 绘图模式选择 ---
% 'ppi':      绘制累积溢出点的极坐标PPI图。
% 'az_range': 绘制累积溢出点的直角坐标距离-方位图。
options.plot_mode = 'summary'; % <--- 在此切换 'ppi', 'az_range', 或 'summary'

% --- 1.2 分析目标 ---
frame_range = 0:150;
beam_to_plot = 1;     % 指定要分析的波束 (1 到 13)
plot_range = 1:3404;  % 绘图的距离单元范围

% --- 1.3 溢出检测阈值 ---
% 这个值需要根据脉冲压缩后的信号幅度动态范围来设定。
threshold_pc = 1e6; 
% --- 1.4 角度修正参数 ---
north_angle = 307;
fix_angle = 35;

%% 2. 路径与参数配置
% =========================================================================
n_exp = 3;
base_path  = uigetdir('', '请选择数据根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end

% --- 直接定位到脉冲压缩数据文件夹 ---
pc_data_path = fullfile(base_path, num2str(n_exp), 'pulse_compressed_data');
if ~exist(pc_data_path, 'dir')
    error('指定的脉冲压缩数据文件夹不存在: %s', pc_data_path);
end

% --- 雷达系统参数 (用于计算) ---
config.Sig_Config.deltaR = 2.99792458e8 / (2 * 25e6);

%% 3. 加载、合并所有帧的溢出点
% =========================================================================
fprintf('--- 正在加载并分析所有帧的脉冲压缩数据... ---\n');
tic;

% 初始化一个空的结构体数组来存储所有溢出点
overflow_log = struct(...
    'frame', {}, 'prt_index', {}, 'range_bin', {}, 'angle_deg', {} ...
);

% 循环遍历每一个结果文件
for frame_to_load = frame_range
    mat_file_path = fullfile(pc_data_path, ['frame_', num2str(frame_to_load), '.mat']);
    if ~exist(mat_file_path, 'file'), continue; end
    
    try
        % 假设脉压后的数据变量名为 'pc_data_all_beams' (一个元胞数组)
        load_data = load(mat_file_path, 'pc_data_all_beams', 'servo_angle');
        pc_data_one_beam = load_data.pc_data_all_beams{beam_to_plot};
        servo_angle = load_data.servo_angle;
    catch
        warning('加载文件 "%s" 或提取变量失败，跳过此帧。', mat_file_path);
        continue;
    end
    
    % --- 伺服角修正 ---
    servo_angle_corrected = fun_correct_servo_angle(servo_angle, north_angle, fix_angle);
    
    % --- 溢出检测 ---
    overflow_mask = abs(real(pc_data_one_beam)) >= threshold_pc | abs(imag(pc_data_one_beam)) >= threshold_pc;
    [overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
    
    if ~isempty(overflow_prt_indices)
        num_overflow_this_frame = numel(overflow_prt_indices);
        
        temp_log(1:num_overflow_this_frame) = struct(...
            'frame', frame_to_load, 'prt_index', 0, 'range_bin', 0, 'angle_deg', 0 ...
        );
        
        for k = 1:num_overflow_this_frame
            prt_idx = overflow_prt_indices(k);
            temp_log(k).prt_index = prt_idx;
            temp_log(k).range_bin = overflow_range_indices(k);
            temp_log(k).angle_deg = servo_angle_corrected(prt_idx);
        end
        
        overflow_log = [overflow_log; temp_log.'];
    end
    fprintf('第%d帧处理完成\n', frame_to_load);
end
toc;

fprintf('分析完成，共累积 %d 个溢出点。\n', length(overflow_log));
if isempty(overflow_log)
    disp('未检测到溢出点，程序结束。');
    return;
end

%% 4. 调用绘图函数
% =========================================================================
fprintf('--- 正在生成可视化图表 ---\n');

% 准备绘图参数
plot_params.plot_mode = options.plot_mode;
plot_params.range_to_plot = plot_range;
plot_params.overflow_log = overflow_log;
plot_params.beam_to_plot = beam_to_plot;

% 创建图形窗口并调用绘图函数
h_fig = figure('Name', ['脉冲压缩后溢出点分析 (波束 #' num2str(beam_to_plot) ')'], 'NumberTitle', 'off', 'Position', [100, 100, 900, 700]);
fun_plot_pc_overflow_dashboard(h_fig, plot_params);

fprintf('--- 可视化分析完成 ---\n');
