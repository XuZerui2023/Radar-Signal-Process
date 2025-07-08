% main_cumulative_cfar_analysis.m
% 该函数用于画累积cfar检测图
% 更新: 增加了绘图选项，可以选择生成累积PPI图或累积距离-速度图。

clc; clear; close all;

%% 1. 用户配置区
% --- 分析目标 ---
frame_range = 0:100;

% --- 【新功能】绘图选项 ---
% 'ppi':    绘制累积的平面位置显示图 (方位 vs 距离)
% 'rdm':    绘制累积的距离-多普勒图 (速度 vs 距离)
plot_option = 'rdm'; % <--- 在此选择最终的绘图类型

% --- 新功能开关 ---
options.save_detection_log = true;
options.save_cumulative_image = true;

% --- 角度修正参数 ---
NorthAngle = 307;
FixAngle = 35;

%% 2. 路径与参数配置
% ... (此部分与原版相同，保持不变) ...
n_exp = 3;
win_size = 4;
T_CFAR = 7;
base_path  = uigetdir('', '请选择数据根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end
mtd_data_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);
header_data_path = fullfile(base_path, num2str(n_exp), 'Framehead_information');
output_path = fullfile(base_path, num2str(n_exp), 'Cumulative_Results');
if ~exist(output_path, 'dir'), mkdir(output_path); end
params.c = 2.99792458e8;
params.prtNum = 332;
params.prt = 232.76e-6;
params.fs = 25e6;
params.fc = 9450e6;
params.beam_num = 13;
params.point_prt_total = 3404;
params.prf = 1 / params.prt;
params.wavelength = params.c / params.fc;
params.deltaR = params.c / (2 * params.fs);

%% 3. 初始化结果存储变量
detection_log = struct(...
    'frame', {}, 'beam', {}, 'slice', {}, ...
    'prt_index', {}, 'range_bin', {}, ...
    'azimuth_deg', {}, 'elevation_deg', {}, ...
    'velocity_ms', {}, 'range_m', {}, 'snr', {}, ...
    'timestamp', {} ...
);

%% 4. 主循环：加载数据并提取所有检测点
% ... (此部分主循环逻辑与原版完全相同，保持不变) ...
fprintf('--- 开始从所有帧中提取CFAR检测点 ---\n');
for frame_idx = frame_range
    mtd_file = fullfile(mtd_data_path, ['frame_', num2str(frame_idx), '.mat']);
    cfar_file = fullfile(cfar_data_path, ['frame_', num2str(frame_idx), '.mat']);
    header_file = fullfile(header_data_path, ['frame_', num2str(frame_idx), '.mat']);
    if ~exist(mtd_file, 'file') || ~exist(cfar_file, 'file') || ~exist(header_file, 'file')
        warning('帧 #%d 的MTD, CFAR或帧头文件缺失，跳过此帧。', frame_idx);
        continue;
    end
    load(mtd_file, 'MTD_win_all_beams');
    load(cfar_file, 'cfarFlag_win_all_beams');
    load(header_file, 'FrameHead_information');
    fprintf('正在处理第 %d 帧...\n', frame_idx);
    for b = 1:params.beam_num
        for s = 1:win_size
            mtd_slice = squeeze(MTD_win_all_beams{b}(s, :, :));
            cfar_flag = squeeze(cfarFlag_win_all_beams{b}(s, :, :));
            [detected_v_indices, detected_r_indices] = find(cfar_flag);
            if ~isempty(detected_v_indices)
                num_detections = numel(detected_v_indices);
                current_detections(1:num_detections) = struct(...
                    'frame', frame_idx, 'beam', b, 'slice', s, ...
                    'prt_index', 0, 'range_bin', 0, 'azimuth_deg', 0, ...
                    'elevation_deg', NaN, 'velocity_ms', 0, 'range_m', 0, ...
                    'snr', 0, 'timestamp', uint64(0));
                for k = 1:num_detections
                    v_idx = detected_v_indices(k);
                    r_idx = detected_r_indices(k);
                    prt_info = FrameHead_information(1);
                    current_detections(k).prt_index = prt_info.pulse_no;
                    current_detections(k).range_bin = r_idx;
                    current_detections(k).azimuth_deg = prt_info.servo_angle * 0.1;
                    v_axis = linspace(-params.prf/2, params.prf/2, params.prtNum) * params.wavelength / 2;
                    current_detections(k).velocity_ms = v_axis(v_idx);
                    current_detections(k).range_m = r_idx * params.deltaR;
                    current_detections(k).snr = mtd_slice(v_idx, r_idx);
                    current_detections(k).timestamp = prt_info.timer_cnt;
                end
                detection_log = [detection_log; current_detections.'];
            end
        end
    end
end

%% 5. 显示、保存最终结果
fprintf('\n================== 分析完毕 ==================\n');
fprintf('在分析的 %d 帧数据中，共检测到 %d 个目标点。\n', length(frame_range), length(detection_log));

% --- 保存检测点日志文件 ---
log_output_file = fullfile(output_path, 'detection_log.mat');
if options.save_detection_log && ~isempty(detection_log)
    save(log_output_file, 'detection_log');
    fprintf('检测点详细信息已保存到: %s\n', log_output_file);
end

% --- 【新功能】根据选项调用不同的绘图函数 ---
if ~isempty(detection_log)
    switch plot_option
        case 'ppi'
            h_fig = fun_plot_cumulative_detections(detection_log, params, NorthAngle, FixAngle);
            image_output_file = fullfile(output_path, 'cumulative_ppi_plot.png');
        case 'rdm'
            h_fig = fun_plot_cumulative_rdm(detection_log, params);
            image_output_file = fullfile(output_path, 'cumulative_rdm_plot.png');
        otherwise
            warning('未知的绘图选项: %s。不进行绘图。', plot_option);
            h_fig = [];
    end
    
    if options.save_cumulative_image && ishandle(h_fig)
        try
            saveas(h_fig, image_output_file);
            fprintf('累积结果图已保存到: %s\n', image_output_file);
        catch ME
            warning('无法保存图像。错误信息: %s', ME.message);
        end
    end
end

disp('所有流程执行完毕。');
