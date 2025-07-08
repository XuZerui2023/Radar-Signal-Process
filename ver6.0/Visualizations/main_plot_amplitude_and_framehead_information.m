% 本函数主要用于跨帧读取原始iq数据和帧头信息，并画信号幅值图
% 本函数绘图功能：
%   1. 信号抽选任一prt多帧的信号幅度图（i，q，复数信号）
%   2. 信号原始伺服角和修正后伺服角示意图
%
% 本函数数据读取保存功能：
%   1. 可以保存多帧帧头信息为一个元胞数组
%

clc,clear;
frame_range = 0:151;
n_exp = 3;                                        % 该文件夹编号
channel_num = 1;                                  % 通道数选择
prt_select = 100;                                 % 抽选的prt维数，画图分析用
showaplitudeperframe = true;                      % 画图开关

config.save_options.save_frameheads_mat = false;   % 存储帧头数据开关
config.save_options.save_iq_mat = false;          % 存储原始iq数据开关


base_path  = uigetdir;   % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(base_path, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(base_path);
    disp(['已选择文件路径: ', fullFile]);
end
raw_data_path = fullfile(base_path, num2str(n_exp), '2025年05月22日17时10分05秒'); % 原始二进制bin文件路径
iq_data_path = fullfile(base_path, num2str(n_exp), '\raw_iq_data');           % 保存iq_data文件路径

%%  雷达系统参数
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

% 初始化数据矩阵
prt_frame = zeros(length(frame_range), 332, 3404);
prt_frame_abs_prt = prt_frame;
prt_frame_abs_prt_select = zeros(length(frame_range), config.Sig_Config.point_PRT, 1);

FrameHead_information_array{length(frame_range), 1} = zeros; 


% 创建所有输出目录
config.output_paths.framehead = fullfile(base_path, num2str(n_exp), 'framehead');
config.output_paths.iq = fullfile(base_path, num2str(n_exp), 'BasebandRawData_mat');

if config.save_options.save_frameheads_mat, mkdir(config.output_paths.framehead); end   % 开关：是否保存读取文件时检测的文件帧头信息
if config.save_options.save_iq_mat,         mkdir(config.output_paths.iq);        end

%% 主循环

% 清除底层函数的持久化状态，确保从头开始读取
clear FrameDataRead_xzr_raw_iq read_continuous_file_stream manage_retry_count;

for frame_to_load = frame_range
    fprintf('\n================== 正在分析第 %d 帧 ==================\n', frame_to_load);
    
    % --- 步骤 1: 从.bin文件读取单帧的原始I/Q数据 ---
    % 利用 FrameDataRead_xzr_raw_iq.m 函数读取单帧的原始I/Q数据和、帧头信息
    [raw_iq_data, servo_angle, framehead, success, is_end] = FrameDataRead_xzr_raw_iq(raw_data_path, config, frame_to_load);
    
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

    current_frame_index = frame_to_load + 1; % 定义数组索引
    prt_frame(current_frame_index, :, :) = real(raw_iq_data(:, :, channel_num));  % 按设定的通道数抽选
    prt_frame_abs_prt_select = prt_frame(:, prt_select, :);                       % 按设定的prt维度抽选
    FrameHead_information_array{current_frame_index, 1} = framehead;                    % 存储帧头信息的元胞数组

    plot_servo_angle(current_frame_index) = framehead.current_servo_angle;
    plot_frame_no(current_frame_index) = framehead.frame_no;

end

% 保存帧头信息
if config.save_options.save_frameheads_mat
    save(fullfile(config.output_paths.framehead, ['FrameHead_information_array',num2str(frame_to_load), '.mat']), 'FrameHead_information_array');
    fprintf('  > 已保存 %d 帧的帧头信息。\n', current_frame_index);
end


%% 绘图
reshaped_prt_frame_abs_prt_select = squeeze(prt_frame_abs_prt_select);
[rows, cols] = size(reshaped_prt_frame_abs_prt_select);
data_to_plot = reshaped_prt_frame_abs_prt_select';  % plot函数按列成线

if showaplitudeperframe
% 创建绘图
figure(1); % 创建一个新的图窗窗口
% 将每一行绘制成单独的线
% 每条线将代表一个帧在 3404 个采样距离上的幅值。
plot(data_to_plot); % 如果 'plot' 函数期望列作为单独的线，则进行转置
xlabel('采样距离单元'); % 如果有实际的距离值，可以使用实际值
ylabel('幅度 (dB)');
legend;
plot_title = sprintf('通道%d，prt维数%d 下，%d 帧幅值随采样距离的变化', channel_num, prt_select, rows')
title(plot_title);
grid on;
end

%% 画连续帧伺服角

plot_servo_angle1 = plot_servo_angle * 0.01;
plot_servo_angle2 = double(plot_servo_angle1) - 307.0 + 35;

for i = 1: length(frame_range)
    
    if plot_servo_angle2(i) < -180
        plot_servo_angle2(i) = plot_servo_angle2(i) + 360;
    end
end

figure(2)
plot(plot_frame_no, plot_servo_angle)
title1 = sprintf('%d 帧原始伺服角示意图', length(frame_range));
title(title1);
xlabel('帧数');
ylabel('伺服角度');

figure(3)
north_angle = 307;
fix_angle = 35;
correct_angle = fun_correct_servo_angle(plot_servo_angle,north_angle,fix_angle); % 调用伺服角修正子函数修正伺服角
plot(correct_angle)
title2 = sprintf('%d 帧伺服角（修正后）示意图', length(frame_range));
title(title2);
xlabel('帧数'); 
ylabel('伺服角度');


% servo_1 = zeros(length(frame_range),1)
% for i = 1 : length(frame_range)
%     servo_1(i,1) = plot_servo_angle(i) * 0.01 - 307;
%     if servo_1(i,1) < -180
%         servo_1(i,1) = servo_1(i,1) + 360;
%     end
% 
% end


% servo_delta = zeros(100,1)
% for j = 1:100
%     servo_delta(j,1) = servo_1(j+1,1) - servo_1(j,1);
% 
% end

