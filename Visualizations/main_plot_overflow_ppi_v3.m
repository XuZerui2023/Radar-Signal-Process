% main_plot_overflow_ppi_v3.m
% 调用对应绘图子函数 fun_plot_overflow_ppi_v3.m
% 这是一个一体化的溢出数据分析与可视化工具。
% 它将从原始.bin文件读取数据、进行溢出分析、并生成极坐标PPI图的过程整合在一起，并支持按帧循环显示。
%
% 修改记录
% date       by      version             modify
% 25/06/26   XZR      v1.0      创建，手动分析单帧数据
% 25/06/30   XZR      V2.0      改进为循环多帧分析多帧数据，绘图函数封装为对应子函数fun_plot_overflow_ppi.m
% 25/07/04   XZR      V3.0      1 . 增加溢出点驻留显示功能，可在PPI图上累积显示所有历史溢出点。
%                               2. 增加溢出信息记录功能，将每个溢出点的详细信息保存到.mat文件。
%                               3. 实现将最后一帧的图片保存到文件夹中
%                               4. 实现增添角度修正函数，利用指北角和固定角修正伺服角
%
% 未来改进：

clc; clear; close all

%% 1. 用户配置区
% --- 时间戳配置 ---
current_time = datetime('now');
timestamp_str = string(current_time, 'yyyyMMdd_HHmmss');
% 示例输出: 生成的时间戳字符串: 20250704_032826 (根据当前时间)

% --- 分析目标 ---
frame_range = 0:150;
channel_to_plot = 5;   % 通道数
plot_range = 1:2000;   % 绘图距离单元数

% --- 新功能开关 ---
options.persist_overflow_display = true;   % true：驻留显示所有历史溢出点; false: 只显示当前帧的溢出点
options.save_overflow_log = true;          % 在程序结束时保存溢出点日志文件
options.save_final_image = true;           % 保存最后的溢出点记录图   

options.root_folder = 'Overflow_log';      % 根目录文件夹命名
options.output_filename = options.root_folder + "_" + timestamp_str; % 保存日志的文件名

% --- 溢出检测阈值 ---
% SATURATION_THRESHOLD = 32760;
SATURATION_THRESHOLD = 10000; % 溢出值判断阈值
% --- 流程控制 ---
pause_duration = 0.1; % 图片刷新间隔

% --- 角度修正 ---
north_angle = 307;    % 指北角修正
fix_angle = 35;       % 固定角修正

%% 2. 文件路径与参数配置
n_exp = 3;
base_path  = uigetdir('', '请选择数据根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end
raw_data_path = fullfile(base_path, num2str(n_exp), '2025年05月22日17时10分05秒');
out_put_path = fullfile(base_path, num2str(n_exp), options.root_folder, timestamp_str);
out_put_file = fullfile(out_put_path, options.output_filename); 
% --- 雷达系统参数 ---
% 将所有参数封装在config结构体中，方便传递
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

%% 3. 初始化结果存储变量
% --- 将 overflow_log 初始化为一个空的、有正确字段的结构体数组 ---
overflow_log = struct(...
    'frame', {}, ...
    'prt_index', {}, ...
    'range_bin', {}, ...
    'angle_deg', {}, ...
    'range_m', {} ...
);

servo_angle_corrected_saved = zeros(1, length(frame_range));

%% 4. 主循环与可视化分析
h_fig = figure('Name', '原始I/Q数据溢出分析', 'NumberTitle', 'off');
clear FrameDataRead_xzr_raw_iq read_continuous_file_stream manage_retry_count;

for frame_to_load = frame_range
    fprintf('\n================== 正在分析第 %d 帧 ==================\n', frame_to_load);
    
    % --- 步骤 1: 读取数据 ---
    [raw_iq_data, servo_angle, frame_headers, success, is_end] = FrameDataRead_xzr_raw_iq(raw_data_path, config, frame_to_load);
    if ~success
        if is_end, fprintf('已到达数据流末尾，分析结束。\n'); break;
        else, fprintf('跳过此帧。\n'); continue; end
    end
    
    % 伺服角修正
    servo_angle_corrected = fun_correct_servo_angle(servo_angle, north_angle, fix_angle); 
    servo_angle_corrected_saved(frame_to_load + 1) = servo_angle_corrected(1);  % 修正后伺服角
    servo_angle_saved(frame_to_load + 1) = servo_angle(1);                      % 修正前伺服角
    
    % --- 步骤 2: 进行溢出检测 ---
    iq_channel_data = raw_iq_data(:, :, channel_to_plot);
    overflow_mask = abs(real(iq_channel_data)) >= SATURATION_THRESHOLD | abs(imag(iq_channel_data)) >= SATURATION_THRESHOLD;
    [overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
    fprintf('  > 在通道 %d 中共发现 %d 个溢出点。\n', channel_to_plot, numel(overflow_prt_indices));
    
    % --- 步骤 3: 记录当前帧的溢出点详细信息 (新功能) ---
    if ~isempty(overflow_prt_indices)
        num_overflow_this_frame = numel(overflow_prt_indices);
        % 为当前帧的溢出点创建一个临时结构体数组
        current_overflows(1:num_overflow_this_frame) = struct(...
            'frame', frame_to_load, ...
            'prt_index', 0, ...
            'range_bin', 0, ...
            'angle_deg', 0, ...
            'range_m', 0 ...
        );
        for k = 1:num_overflow_this_frame
            current_overflows(k).prt_index = overflow_prt_indices(k);
            current_overflows(k).range_bin = overflow_range_indices(k);
            current_overflows(k).angle_deg = servo_angle_corrected(overflow_prt_indices(k));
            current_overflows(k).range_m = overflow_range_indices(k) * config.Sig_Config.deltaR;
        end

        % 将当前帧的结果追加到总日志中
        overflow_log = [overflow_log, current_overflows];
    end
    
    % --- 步骤 4: 准备绘图参数并调用绘图函数 ---
    plot_params.channel_to_plot = channel_to_plot;
    plot_params.range_to_plot = plot_range;
    plot_params.point_PRT = config.Sig_Config.point_PRT;
    plot_params.frame_to_load = frame_to_load;
    plot_params.persist_display = options.persist_overflow_display; % 传递驻留显示开关
    plot_params.overflow_log = overflow_log; % 传递完整的溢出点日志
    
    % 调用绘图函数
    fun_plot_overflow_ppi_v3(h_fig, raw_iq_data, servo_angle_corrected, plot_params);
    
    % --- 暂停 ---
    if pause_duration > 0, pause(pause_duration); end
end

%% 5. 显示并保存最终统计结果
fprintf('\n================== 分析完毕 ==================\n');
total_overflow_count = length(overflow_log);
fprintf('在 %d 到 %d 帧的范围内，通道 %d 共检测到 %d 个溢出点。\n', ...
        frame_range(1), frame_range(end), channel_to_plot, total_overflow_count);


% --- 根据开关选项保存日志文件 ---
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
figure(2)
plot( servo_angle_saved);
xlabel('帧数'); % 如果有实际的距离值，可以使用实际值
ylabel('伺服角度');
title1 = sprintf('%d 帧内原始伺服角随帧数的变化图', length(frame_range))
title(title1)

% 画修正后伺服角随帧数变化图
figure(3)
plot(servo_angle_corrected_saved);
xlabel('帧数'); % 如果有实际的距离值，可以使用实际值
ylabel('伺服角度');
title1 = sprintf('%d 帧内伺服角（修正后）随帧数的变化图', length(frame_range))
title(title1)