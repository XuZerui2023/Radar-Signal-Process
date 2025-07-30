% main_plot_overflow_from_mat.m 绘制溢出检测点
%
% v5.0 更新:
% - 新增 plot_mode 开关，支持 'ppi' 和 'az_range' (距离-方位图) 两种绘图模式。
% - 调用新的统一绘图函数 fun_plot_overflow_dashboard.m。
%
% 修改记录
% date       by      version             modify
% 25/06/26   XZR      v1.0      创建，手动分析单帧数据
% 25/06/30   XZR      V2.0      改进为循环多帧分析多帧数据，绘图函数封装为对应子函数fun_plot_overflow_ppi.m
% 25/07/04   XZR      V3.0      1 . 增加溢出点驻留显示功能，可在PPI图上累积显示所有历史溢出点。
%                               2. 增加溢出信息记录功能，将每个溢出点的详细信息all_frames_data保存到.mat文件。
%                               3. 实现将最后一帧的图片保存到文件夹中
%                               4. 实现增添角度修正函数，利用指北角和固定角修正伺服角
% 25/07/15   XZR      V4.0      增添累计绘图模式
% 25/07/15   XZR      v5.0      新增 plot_mode 开关，支持 'ppi' 和 'az_range' (距离-方位图) 两种绘图模式。
%                               调用新的统一绘图函数 fun_plot_overflow_dashboard.m。
clc; clear; close all

%% 1. 用户配置区
% --- 显示模式选择 ---
% 'dynamic': 动态模式，逐帧刷新显示。
% 'cumulative': 累积模式，处理完所有帧后，一次性显示所有溢出点。
options.display_mode = 'cumulative'; 

% --- 【新增】绘图模式选择 ---
% 'ppi': 极坐标PPI图，经典雷达显示。
% 'az_range': 直角坐标距离-方位图，便于观察角度变化。
% 'summary'：两张图都画
options.plot_mode = 'summary'; % <--- 在此切换 'ppi' 或 'az_range'

% --- 时间戳配置 ---
current_time = datetime('now');
timestamp_str = string(current_time, 'yyyyMMdd_HHmmss');
% --- 分析目标 ---
frame_range = 0:150;   % 选择画图帧文件
channel_to_plot = 5;   % 选择通道数（1-16）
plot_range = 1:3000;   % 选择显示的距离单元（1-3404）
% --- 新功能开关 ---
options.persist_overflow_display = true;  % 持续显示开关
options.save_overflow_log = true;         % 保存溢出值记录开关
options.save_final_image = true;          % 保存最后图片开关
options.root_folder = 'Overflow_log';     % 保存文件夹名称
options.output_filename = options.root_folder + "_" + timestamp_str;
% --- 溢出检测阈值 ---
SATURATION_THRESHOLD = 10000;
% --- 流程控制 ---
pause_duration = 0.1;
% --- 角度修正 ---
north_angle = 307;
fix_angle = 35;

%% 2. 文件路径与参数配置
n_exp = 3;
base_path  = uigetdir('', '请选择包含 raw_iq_data 文件夹的根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end

iq_data_path = fullfile(base_path, num2str(n_exp), 'iq_data_before_DBF');
if ~exist(iq_data_path, 'dir')
    error('指定的I/Q数据文件夹不存在: %s', iq_data_path);
end

out_put_path = fullfile(base_path, num2str(n_exp), options.root_folder, timestamp_str);
out_put_file = fullfile(out_put_path, options.output_filename); 

% --- 雷达系统参数 ---
config.Sig_Config.point_PRT = 3404;
config.Sig_Config.deltaR = 2.99792458e8 / (2 * 25e6);

%% 3. 初始化结果存储变量
overflow_log = struct(...
    'frame', {}, 'prt_index', {}, 'range_bin', {}, 'angle_deg', {}, 'range_m', {} ...
);
servo_angle_saved = zeros(1, length(frame_range));
servo_angle_corrected_saved = zeros(1, length(frame_range));

%% 4. 主循环与可视化分析
% --- 在循环外创建图形窗口 ---
h_fig = figure('Name', '已存I/Q数据溢出分析', 'NumberTitle', 'off', 'Position', [100, 100, 900, 700]);

for frame_to_load = frame_range
    fprintf('\n================== 正在分析第 %d 帧 ==================\n', frame_to_load);
    
    % --- 加载数据 ---
    mat_file_path = fullfile(iq_data_path, ['frame_', num2str(frame_to_load), '.mat']);
    if ~exist(mat_file_path, 'file'), warning('文件 %s 不存在，跳过此帧。', mat_file_path); continue; end
    try
        load_data = load(mat_file_path, 'raw_iq_data', 'servo_angle');
        raw_iq_data = load_data.raw_iq_data;
        servo_angle = load_data.servo_angle;
    catch ME
        warning('加载文件 %s 或提取变量失败，跳过此帧。错误信息: %s', mat_file_path, ME.message);
        continue;
    end
    
    % --- 伺服角修正与记录 ---
    servo_angle_corrected = fun_correct_servo_angle(servo_angle, north_angle, fix_angle); 
    servo_angle_saved(frame_to_load + 1) =  servo_angle(1);
    servo_angle_corrected_saved(frame_to_load + 1) = servo_angle_corrected(1);
    
    % --- 溢出检测与记录 ---
    iq_channel_data = raw_iq_data(:, :, channel_to_plot);
    overflow_mask = abs(real(iq_channel_data)) >= SATURATION_THRESHOLD | abs(imag(iq_channel_data)) >= SATURATION_THRESHOLD;
    [overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
    
    if ~isempty(overflow_prt_indices)
        num_overflow_this_frame = numel(overflow_prt_indices);
        current_overflows(1:num_overflow_this_frame) = struct(...
            'frame', frame_to_load, 'prt_index', 0, 'range_bin', 0, 'angle_deg', 0, 'range_m', 0 ...
        );
        for k = 1:num_overflow_this_frame
            current_overflows(k).prt_index = overflow_prt_indices(k);
            current_overflows(k).range_bin = overflow_range_indices(k);
            current_overflows(k).angle_deg = servo_angle_corrected(overflow_prt_indices(k));
            current_overflows(k).range_m = overflow_range_indices(k) * config.Sig_Config.deltaR;
        end
        overflow_log = [overflow_log, current_overflows];
    end
    
    % --- 根据显示模式决定是否在循环中绘图 ---
    if strcmp(options.display_mode, 'dynamic')
        plot_params.plot_mode = options.plot_mode; % 传递绘图模式
        plot_params.channel_to_plot = channel_to_plot;
        plot_params.range_to_plot = plot_range;
        plot_params.point_PRT = config.Sig_Config.point_PRT;
        plot_params.frame_to_load = frame_to_load;
        plot_params.persist_display = options.persist_overflow_display;
        plot_params.overflow_log = overflow_log;
        
        fun_plot_overflow_ppi_v5(h_fig, raw_iq_data, servo_angle_corrected, plot_params);
        
        if pause_duration > 0, pause(pause_duration); end
    end
end

%% 5. 最终结果处理与可视化
fprintf('\n================== 分析完毕 ==================\n');
total_overflow_count = length(overflow_log);
fprintf('在 %d 到 %d 帧的范围内，通道 %d 共检测到 %d 个溢出点。\n', ...
        frame_range(1), frame_range(end), channel_to_plot, total_overflow_count);

% --- 如果是累积模式，在循环结束后进行一次总绘图 ---
if strcmp(options.display_mode, 'cumulative') && ~isempty(overflow_log)
    fprintf('正在绘制累积图...\n');
    plot_params.plot_mode = options.plot_mode; % 传递绘图模式
    plot_params.channel_to_plot = channel_to_plot;
    plot_params.range_to_plot = plot_range;
    plot_params.point_PRT = config.Sig_Config.point_PRT;
    plot_params.frame_to_load = -1; 
    plot_params.persist_display = true;
    plot_params.overflow_log = overflow_log;
    
    % 调用绘图函数，但传入空的raw_iq_data，因为它只负责画log
    fun_plot_overflow_ppi_v5(h_fig, [], [], plot_params);
end

% --- 根据开关选项保存日志文件和图像 ---
if options.save_overflow_log && ~isempty(overflow_log)
    mkdir(out_put_path);
    save(out_put_file, 'overflow_log');
    fprintf('溢出点详细信息已保存到 %s\n', out_put_file);
end

% --- 根据开关选项保存最后一张PPI图像 ---
if options.save_final_image && exist('h_fig', 'var') && ishandle(h_fig)
    if length(frame_range) >= 0
        % 创建一个描述性的文件名
        final_image_filename = sprintf('%d Frames_Channel %d_PPI.png', length(frame_range), channel_to_plot);
        final_image_fullpath = fullfile(out_put_path, final_image_filename);
        
        fprintf('正在保存最后一帧 (%d) 的PPI图像到: %s\n', max(frame_range), final_image_fullpath);
        
        % 使用 saveas 函数保存图像
        try
            saveas(h_fig, final_image_fullpath);
            fprintf('图像保存成功。\n');
        catch ME
            % 如果保存失败（例如，因为窗口在检查后被立即关闭），则捕获错误并显示警告
            warning('无法保存图像。错误信息: %s', ME.message);
            warning('这通常是因为在脚本运行结束前，图形窗口被手动关闭了。');
        end
    else
        warning('没有成功处理任何帧，无法保存最终图像。');
    end
    

end

disp('所有流程执行完毕。');


%% 6. 画一个伺服角随帧数变化的图
% 画原始伺服角随帧数变化图
figure(3);
plot( servo_angle_saved);
xlabel('帧数'); % 如果有实际的距离值，可以使用实际值
ylabel('伺服角度');
title1 = sprintf('%d 帧内原始伺服角随帧数的变化图', length(frame_range))
title(title1)

% 画修正后伺服角随帧数变化图
figure(4);
plot(servo_angle_corrected_saved);
xlabel('帧数'); % 如果有实际的距离值，可以使用实际值
ylabel('伺服角度');
title1 = sprintf('%d 帧内伺服角（修正后）随帧数的变化图', length(frame_range))
title(title1)