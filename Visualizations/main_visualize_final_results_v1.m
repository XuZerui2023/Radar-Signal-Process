% main_visualize_final_results_v1.m
%
% 这是一个集成了数据加载、合并、筛选和可视化的"一站式"后处理与分析脚本。
%
% --- 工作流程 ---
% 1. 遍历指定的文件夹，加载所有按帧存储的、已完成参数测量的 .mat 文件。
% 2. 从每个文件中加载目标信息，并将它们累积成一个总的目标日志。
% 3. 提供一个清晰的配置区，可以方便地设置各种筛选条件（掩码）。
% 4. 对累积的目标日志应用这些筛选条件。
% 5. 调用一个统一的仪表盘绘图函数，对筛选后的数据进行多维度可视化。
%
% 修改记录
% date       by      version   modify
% 25/07/16   XZR      v1.0     读取保存的数据并直接处理最终测量结果

clc; clear; close all;

%% 1. 用户配置区
% =========================================================================

% --- 1.1 绘图选项 ---
% 'summary':  绘制包含多个核心视图的综合分析仪表盘。
% 'ppi':      单独绘制距离-方位图 (PPI)。
% 'rhi':      单独绘制距离-高度图 (RHI)。
% 'az_range': 单独绘制距离-方位图。
% 'rd_plot':  单独绘制距离-速度图。
% '3d_scatter': 单独绘制三维空间分布图。
plot_option = 'summary'; % <--- 在此选择最终的绘图类型

% --- 1.2 数据筛选掩码配置 ---
filters.enable = true; % 总开关，设为 false 则不进行任何筛选

% 速度筛选 (m/s): 保留速度小于-3 或 大于+3 的目标
filters.velocity_ms = [-inf, -3; 3, inf]; 

% 距离筛选 (m): 只保留距离在 500米 到 5000米 之间的目标
% filters.range_m = [500, 5000];

% 高度筛选 (m): 只保留高度在 10米 到 1000米 之间的目标
% filters.height_m = [10, 1000];

% 信噪比筛选: 只保留信噪比(和信号幅度)大于某个值的目标
%filters.snr = 1000; 

% 波束对筛选：筛选12个波束对部分测的目标 
filters.beampair = []
% --- 1.3 角度修正参数 ---
NorthAngle = - 242;
FixAngle = 35;

%% 2. 路径与参数配置
% =========================================================================
fprintf('--- 请选择已完成参数测量的结果文件夹 ---\n');
% 例如: 'beam_diff_estimation_cfarFlag4_T7'
estimation_path  = uigetdir('', '请选择包含参数测量结果的文件夹 (beam_diff_estimation_...)');
if isequal(estimation_path, 0), disp('用户取消了选择。'); return; end

% 如果需要从CFAR结果中提取SNR，也请选择CFAR结果文件夹
% cfar_path = uigetdir('', '请选择包含CFAR标志的文件夹 (cfarFlag4_...)');
% if isequal(cfar_path, 0), disp('用户取消了选择。'); return; end

% 获取文件夹中所有 .mat 文件
file_list = dir(fullfile(estimation_path, 'frame_*.mat'));
if isempty(file_list)
    error('在指定路径 "%s" 中未找到任何 frame_*.mat 文件。', estimation_path);
end

% 定义雷达系统参数 (用于绘图和计算)
params.c = 2.99792458e8;

%% 3. 加载、合并所有帧的检测结果
% =========================================================================
fprintf('--- 正在加载并合并所有帧的检测结果... ---\n');
tic;

% 初始化一个空的结构体数组来存储所有目标点
detection_log = struct(...
    'frame', {}, 'slice', {}, 'beam_pair', {}, 'range_m', {}, 'velocity_ms', {}, ...
    'snr', {}, 'azimuth_deg', {}, 'elevation_deg', {}, 'height_m', {} ...
);

% 循环遍历每一个结果文件
for i = 1:length(file_list)
% for i = 1:9
    file_path = fullfile(estimation_path, file_list(i).name);
    
    try
        % 假设每个.mat文件包含一个名为'resultEst_Struct'的变量
        data = load(file_path, 'beamdiff_estimation');
        frame_data = data.beamdiff_estimation;
    catch
        warning('无法从文件 "%s" 中加载 "resultEst_Struct" 变量，跳过此文件。', file_list(i).name);
        continue;
    end
    
    % 从输入文件中读取所需的参数
    if ~isempty(frame_data) 
        
        frames = [frame_data.frame];
        slices = [frame_data.slice];
        beam_pairs = [frame_data.beam_pair];
        ranges = [frame_data.range_m];
        velocities = [frame_data.velocity_ms];
        snrs = [frame_data.snr];
        azimuth = [frame_data.servo_deg_raw];
        elevations = [frame_data.elevation_deg];
        heights = [frame_data.height_m];
    
    else
        continue;
    end

    % 假设SNR信息也保存在类似字段中，如果不存在，则设为NaN
    
    num_detections = length(ranges);
    if num_detections == 0
        continue;
    end
    
    temp_log(1:num_detections) = struct(...
        'frame', 0, 'slice', 0, 'beam_pair', 0, 'range_m', 0, 'velocity_ms', 0, ...
        'snr', 0, 'azimuth_deg', 0, 'elevation_deg', 0, 'height_m', 0 ...
    );
    
    for k = 1:num_detections
        temp_log(k).frame = frames(k);
        temp_log(k).slice = slices(k);
        temp_log(k).beam_pair = beam_pairs(k);
        temp_log(k).range_m = ranges(k);
        temp_log(k).velocity_ms = velocities(k);
        temp_log(k).snr = snrs(k);
        temp_log(k).azimuth_deg = azimuth(k);
        temp_log(k).elevation_deg = elevations(k);
        temp_log(k).height_m = heights(k); % 计算高度
        
    end
    
    detection_log = [detection_log; temp_log.'];
end
toc;

fprintf('合并完成，共累积 %d 个检测点。\n', length(detection_log));
if isempty(detection_log)
    disp('日志为空，没有可供分析的目标点。程序结束。');
    return;
end

%% 4. 应用数据筛选掩码
% =========================================================================
if filters.enable
    fprintf('--- 正在应用数据筛选掩码 ---\n');
    
    all_velocities = [detection_log.velocity_ms];
    all_ranges = [detection_log.range_m];
    all_heights = [detection_log.height_m];
    all_elevations = [detection_log.elevation_deg];
    all_snr = [detection_log.snr];
    all_beampair = [detection_log.beam_pair];

    combined_mask = true(size(all_velocities));
    
    if isfield(filters, 'velocity_ms') && ~isempty(filters.velocity_ms)
        vel_mask = false(size(all_velocities));
        for k = 1:size(filters.velocity_ms, 1)
            vel_mask = vel_mask | (all_velocities >= filters.velocity_ms(k, 1) & all_velocities <= filters.velocity_ms(k, 2));
        end
        combined_mask = combined_mask & vel_mask;
    end
    
    if isfield(filters, 'range_m') && ~isempty(filters.range_m)
        range_mask = (all_ranges >= filters.range_m(1)) & (all_ranges <= filters.range_m(2));
        combined_mask = combined_mask & range_mask;
    end

    if isfield(filters, 'height_m') && ~isempty(filters.height_m)
        height_mask = (all_heights >= filters.height_m(1)) & (all_heights <= filters.height_m(2));
        combined_mask = combined_mask & height_mask;
    end

    if isfield(filters, 'snr') && ~isempty(filters.snr)
        snr_mask = all_snr >= filters.snr;
        combined_mask = combined_mask & snr_mask;
    end

    if isfield(filters, 'beampair') && ~isempty(filters.beampair)
        % beampair_mask = all_beampair == filters.beampair1;
        % 取多个波束
        beampair_mask = ismember(all_beampair, filters.beampair); % 检查 all_beampair 的每个元素是否在 filters.beampair 数组中
        combined_mask = combined_mask & beampair_mask;
    end

    filtered_log = detection_log(combined_mask);
    
    fprintf('筛选完毕，原始点数: %d, 剩余点数: %d\n', length(detection_log), length(filtered_log));
    
    if isempty(filtered_log)
        disp('筛选后无剩余目标点，程序结束。');
        return;
    end

else
    filtered_log = detection_log; 
end

%% 5. 调用绘图函数
% =========================================================================
fprintf('--- 正在生成可视化图表 ---\n');

% 将筛选后的日志和其他所需参数传递给绘图函数
fun_plot_master_dashboard(filtered_log, params, NorthAngle, FixAngle, plot_option);

fprintf('--- 可视化分析完成 ---\n') ;
