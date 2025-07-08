% main_plot_overflow_ppi_v2.m
% 调用对应绘图子函数 fun_plot_overflow_ppi.m
% 这是一个一体化的溢出数据分析与可视化工具。
% 它将从原始.bin文件读取数据、进行溢出分析、并生成极坐标PPI图的过程整合在一起，并支持按帧循环显示。
% 使用说明:
% 1. 在 "1. 用户配置区" 修改参数。
% 2. 确保您已有一个名为 FrameDataRead_xzr_raw_iq.m 的函数，
%    它能返回原始I/Q数据。
% 3. 运行此脚本。

% 修改记录
% date       by      version             modify
% 25/06/26   XZR      v1.0      创建，手动分析单帧数据
% 25/06/30   XZR      V2.0      改进为循环多帧分析多帧数据，绘图函数封装为对应子函数fun_plot_overflow_ppi.m
% 未来改进：

clc; clear; close all;

%% 1. 用户配置区
% --- 分析目标 ---
frame_range = 0:151; % 指定要分析和显示的帧编号范围
channel_to_plot = 8;  % 指定要分析和显示的物理通道 (1 到 16)

% --- 溢出检测阈值 ---
% 对于16位有符号ADC，其最大值为 2^15 - 1 = 32767。
SATURATION_THRESHOLD = 32760;
% SATURATION_THRESHOLD = 3000;
% --- 流程控制 ---
pause_duration = 0.1; % 每帧分析后的暂停时间(秒)。设为 inf 则为手动按键继续。

%% 2. 路径与参数配置
% --- 路径设置 ---
n_exp = 3;        % 该文件夹编号
base_path  = uigetdir;                         % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(base_path, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(base_path);
    disp(['已选择文件路径: ', fullFile]);
end
raw_data_path = fullfile(base_path, num2str(n_exp), '2025年05月22日17时10分05秒'); % 原始二进制bin文件路径
iq_data_path = fullfile(base_path, num2str(n_exp), '\raw_iq_data');           % 保存iq_data文件路径
mkdir(iq_data_path);

% --- 雷达系统参数 ---
% 将所有参数封装在config结构体中，方便传递
MHz = 1e6; % 定义MHz单位
config.Sig_Config.c = 2.99792458e8;            % 光速
config.Sig_Config.pi = pi;                     % 圆周率
config.Sig_Config.fs = 25e6;                   % 采样率 (Hz)
config.Sig_Config.fc = 9450e6;                % 中心频率 (Hz)
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


%% 4. 主循环与可视化分析

% --- 在循环开始前，创建空的元胞数组和计数器 ---
overflow_prt   = cell(length(frame_range),1);   % 预分配元胞数组用于存储每帧溢出点的PRT索引
overflow_range = cell(length(frame_range),1); % 预分配元胞数组用于存储每帧溢出点的距离索引
total_overflow_count = 0;                                 % 初始化总溢出点计数器为0
servo = cell(length(frame_range),1);
% 在所有循环之外，只创建一次figure窗口
h_fig = figure('Name', '原始I/Q数据溢出分析', 'NumberTitle', 'off');

% 清除底层函数的持久化状态，确保从头开始读取
clear FrameDataRead_xzr_raw_iq read_continuous_file_stream manage_retry_count;

for frame_to_load = frame_range
    fprintf('\n================== 正在分析第 %d 帧 ==================\n', frame_to_load);
    
    % --- 步骤 1: 从.bin文件读取单帧的原始I/Q数据 ---
    % 利用 FrameDataRead_xzr_raw_iq.m 函数读取单帧的原始I/Q数据
    [raw_iq_data, servo_angle, ~, success, is_end] = FrameDataRead_xzr_raw_iq(raw_data_path, config, frame_to_load);
    
    if ~success
        warning('未能完整读取第 %d 帧。', frame_to_load);
        if is_end
            fprintf('已到达数据流末尾，分析结束。\n');
            break;
        else
            fprintf('跳过此帧，继续分析下一帧。\n');
            continue;
        end
    end
    
   
    % --- 步骤 2: 进行溢出检测 ---
    iq_channel_data = raw_iq_data(:, :, channel_to_plot);
    overflow_mask = abs(real(iq_channel_data)) >= SATURATION_THRESHOLD | abs(imag(iq_channel_data)) >= SATURATION_THRESHOLD;
    [overflow_prt_indices, overflow_range_indices] = find(overflow_mask);
    num_overflow_this_frame = numel(overflow_prt_indices);
    fprintf('  > 在通道 %d 中共发现 %d 个溢出点。\n', channel_to_plot, num_overflow_this_frame);

    % --- 步骤 3: 存储当前帧的溢出结果并累加总数 (新功能) ---
    % 使用 frame_to_load + 1 作为索引，因为MATLAB索引从1开始
    current_index = frame_to_load + 1;
    overflow_prt{current_index} = overflow_prt_indices;
    overflow_range{current_index} = overflow_range_indices;
    total_overflow_count = total_overflow_count + num_overflow_this_frame;
    
    % --- 步骤 4: 调用绘图函数进行分析和可视化 ---
    plot_params.channel_to_plot = channel_to_plot;
    plot_params.SATURATION_THRESHOLD = SATURATION_THRESHOLD;
    plot_params.range_to_plot = 1 : 1000;                      % 手动设置需要显示的距离单元范围（最大范围 1-point_PRT）
    plot_params.point_PRT = config.Sig_Config.point_PRT;
    servo_angle = servo_angle * 0.01;                          % 原数据单位是0.1° 
    servo{current_index} = servo_angle; 
    [overflow_prt_indices, overflow_range_indices] = fun_plot_overflow_ppi(frame_to_load, h_fig, raw_iq_data, servo_angle, plot_params);
    
    % --- 暂停以控制显示节奏 ---
    if pause_duration > 0
        fprintf('暂停 %.1f 秒... (如需手动继续，请将pause_duration设为inf)\n', pause_duration);
        pause(pause_duration);
    end
 
end

%% 5. 显示最终统计结果 (新功能)
fprintf('\n================== 分析完毕 ==================\n');
fprintf('在 %d 到 %d 帧的范围内，通道 %d 共检测到 %d 个溢出点。\n', ...
        frame_range(1), frame_range(end), channel_to_plot, total_overflow_count);

% 也可以查询任何一帧的溢出情况，例如查看第0帧的结果：
% first_frame_overflow_prts = overflow_prt_all_frames{1};
% first_frame_overflow_ranges = overflow_range_all_frames{1};

disp('所有指定帧分析显示完毕。');


% servo_1 = zeros(length(frame_range),1)
% for i = 1:101
%     servo_1(i,1) = servo{i}(1,1) * 0.01 - 307;
%     if servo_1(i,1) < -180
%         servo_1(i,1) = servo_1(i,1) + 360;
%     end
% 
% end
% 
% servo_delta = zeros(100,1)
% for j = 1:100
%     servo_delta(j,1) = servo_1(j+1,1) - servo_1(j,1);
% 
% end

