% main_combined_visualization_v2.m
%
% v2.0 更新:
% - 集成了动态溢出点检测功能，无需预先保存巨大的溢出点日志文件。
% - 用户可以选择是对 "原始I/Q数据" 还是 "脉冲压缩后" 的数据进行溢出检测。
% - 保留了加载已保存的CFAR目标日志的功能。
% - 将实时检测的溢出点和加载的CFAR目标点在同一张图上进行联合可视化。
%
% --- 工作流程 ---
% 1. 用户在配置区选择要进行溢出点检测的数据类型 ('raw_iq' 或 'pc')。
% 2. 提示用户选择相应的数据文件夹（原始I/Q或脉冲压缩数据）。
% 3. 提示用户选择包含 "累积CFAR目标日志" 的 .mat 文件。
% 4. 脚本会遍历指定帧范围，实时加载数据，进行溢出检测并累积结果。
% 5. 加载CFAR日志文件。
% 6. 调用统一的绘图函数，将两种数据点绘制在同一个直角坐标距离-方位图上。

clc; clear; close all;

%% 1. 用户配置区
% =========================================================================
% --- 【核心】溢出点检测模式选择 ---
% 'raw_iq': 对原始16通道I/Q数据进行溢出检测 (参考 main_plot_overflow_ppi_v5.m)
% 'pc':     对脉冲压缩后的数据进行溢出检测 (参考 main_plot_pc_overflow.m)
options.overflow_detection_mode = 'raw_iq'; % <--- 在此切换 'raw_iq' 或 'pc'

% --- 分析目标 ---
frame_range = 0:150;     % 需要处理的帧范围
channel_to_plot = 5;     % (仅在 'raw_iq' 模式下有效) 指定要分析的物理通道 (1-16)
beam_to_plot = 1;        % (仅在 'pc' 模式下有效) 指定要分析的波束 (1-13)

% --- 溢出检测阈值 ---
thresholds.raw_iq = 6000; % 原始I/Q数据的饱和阈值
thresholds.pc = 1e6;       % 脉冲压缩后数据的溢出阈值

% --- 角度修正参数 ---
NorthAngle = 307;
FixAngle = 35;

% --- 雷达系统参数 (用于计算) ---
n_exp = 3; % 实验编号
config.Sig_Config.deltaR = 2.99792458e8 / (2 * 25e6); % 距离分辨率

%% 2. 动态检测溢出点 (重构部分)
% =========================================================================
fprintf('--- 开始进行动态溢出点检测... ---\n');
tic;

% --- 根据模式选择路径和阈值 ---
if strcmp(options.overflow_detection_mode, 'raw_iq')
    data_path = uigetdir('', '请选择包含原始I/Q数据 (iq_data_before_DBF) 的根目录');
    data_folder = fullfile(data_path, num2str(n_exp), 'iq_data_before_DBF');
    SATURATION_THRESHOLD = thresholds.raw_iq;
else % 'pc' 模式
    data_path = uigetdir('', '请选择包含脉冲压缩数据 (pulse_compressed_data) 的根目录');
    data_folder = fullfile(data_path, num2str(n_exp), 'pulse_compressed_data');
    SATURATION_THRESHOLD = thresholds.pc;
end

if isequal(data_path, 0), disp('用户取消了选择。'); return; end
if ~exist(data_folder, 'dir'), error('指定的数据文件夹不存在: %s', data_folder); end

% --- 初始化溢出点日志 ---
overflow_log = struct('frame', {}, 'prt_index', {}, 'range_bin', {}, 'angle_deg', {});

% --- 循环遍历所有帧进行检测 ---
for frame_to_load = frame_range
    mat_file_path = fullfile(data_folder, ['frame_', num2str(frame_to_load), '.mat']);
    if ~exist(mat_file_path, 'file'), continue; end
    
    try
        if strcmp(options.overflow_detection_mode, 'raw_iq')
            load_data = load(mat_file_path, 'raw_iq_data', 'servo_angle');
            data_to_check = load_data.raw_iq_data(:, :, channel_to_plot);
        else % 'pc' 模式
            load_data = load(mat_file_path, 'pc_data_all_beams', 'servo_angle');
            data_to_check = load_data.pc_data_all_beams{beam_to_plot};
        end
        servo_angle = load_data.servo_angle;
    catch
        warning('加载文件 "%s" 或提取变量失败，跳过此帧。', mat_file_path);
        continue;
    end
    
    % 伺服角修正
    servo_angle_corrected = fun_correct_servo_angle(servo_angle, NorthAngle, FixAngle);
    
    % 溢出检测
    overflow_mask = abs(real(data_to_check)) >= SATURATION_THRESHOLD | abs(imag(data_to_check)) >= SATURATION_THRESHOLD;
    [overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
    
    if ~isempty(overflow_prt_indices)
        num_overflow_this_frame = numel(overflow_prt_indices);
        temp_log(1:num_overflow_this_frame) = struct('frame', frame_to_load, 'prt_index', 0, 'range_bin', 0, 'angle_deg', 0);
        
        for k = 1:num_overflow_this_frame
            prt_idx = overflow_prt_indices(k);
            temp_log(k).prt_index = prt_idx;
            temp_log(k).range_bin = overflow_range_indices(k);
            % 注意：ser_angle_vocorrected 可能是一维或二维的，需要正确索引
            if size(servo_angle_corrected, 1) > 1
                 temp_log(k).angle_deg = servo_angle_corrected(prt_idx, 1); % 假设角度在第一列
            else
                 temp_log(k).angle_deg = servo_angle_corrected(prt_idx);
            end
        end
        
        overflow_log = [overflow_log; temp_log.'];
    end
    
    if mod(frame_to_load, 10) == 0
        fprintf('已处理到第 %d 帧...\n', frame_to_load);
    end
end
toc;
fprintf('溢出点检测完成，共发现 %d 个溢出点。\n', length(overflow_log));


%% 3. 加载CFAR目标检测日志 (此部分不变)
% =========================================================================
fprintf('--- 正在加载CFAR目标检测日志... ---\n');

[cfar_log_file, cfar_log_path] = uigetfile('*.mat', '请选择累积的CFAR目标日志文件 (e.g., cumulative_detection_log.mat)');
if isequal(cfar_log_file, 0), disp('用户取消了选择。'); return; end
fprintf('正在加载CFAR目标日志: %s\n', fullfile(cfar_log_path, cfar_log_file));
try
    cfar_data = load(fullfile(cfar_log_path, cfar_log_file));
    if isfield(cfar_data, 'cumulative_final_log')
        detection_log = cfar_data.cumulative_final_log;
    elseif isfield(cfar_data, 'detection_log')
        detection_log = cfar_data.detection_log;
    else
        error('在CFAR日志文件中未找到 "cumulative_final_log" 或 "detection_log" 变量。');
    end
catch ME
    error('加载CFAR日志文件失败: %s', ME.message);
end

fprintf('数据加载完成。\n');


%% 4. 调用绘图函数
% =========================================================================
fprintf('--- 正在生成联合可视化图表 ---\n');

% 准备参数
params.NorthAngle = NorthAngle;
params.FixAngle = FixAngle;

% 创建图形窗口并调用绘图函数
h_fig = figure('Name', 'CFAR检测与信号溢出联合分析 (动态检测版)', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 750]);
fun_plot_combined_az_range(h_fig, detection_log, overflow_log, params);

fprintf('--- 可视化分析完成 ---\n');  