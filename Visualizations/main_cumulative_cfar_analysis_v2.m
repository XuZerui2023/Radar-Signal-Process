% 已弃用，被 main_visualize_final_results_v1.m 取代
% main_cumulative_cfar_analysis_v2.m
%
% 这是一个使用并行计算进行优化的累积CFAR结果分析主控脚本。
% 1. 将主循环从 for 更改为 parfor，以利用多核CPU并行处理，显著提高运行速度。
% 2. 调整了数据收集逻辑以适应 parfor 的工作机制。
%
% 修改记录
% date       by      version                 modify
% 25/07/07   XZR      v1.0     在main_cumulative_cfar_analysis.m的基础上引入parfor加速信号处理
%                               
% 未来改进：
clc; clear; close all;

%% 1. 用户配置区
% --- 绘图选项 ---
% 'ppi':      绘制累积的平面位置显示图 (极坐标)
% 'rdm':      绘制累积的距离-多普勒图  (矩形坐标)
% 'az_range': 绘制累积的距离-方位图    (矩形坐标)
% 'summary':  绘制包含以上所有信息的综合仪表盘
plot_option = 'rhi'; % <--- 在此选择最终的绘图类型
frame_range = 0:150;
% --- 保存功能开关 ---
options.save_detection_log = true;
options.save_cumulative_image = true;
% --- 伺服角度修正 ---
NorthAngle = 307;
FixAngle = 35;

%% 2. 路径与参数配置
n_exp = 3;
win_size = 4;
T_CFAR = 7;
base_path  = uigetdir('', '请选择数据根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end
mtd_data_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);    % 使用和波束CFAR目标检测结果的矩阵
% estimation_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);
% cfar_data_path = fullfile(base_path, num2str(n_exp), ['beam_sum_cfarFlag4_T', num2str(T_CFAR)]);
header_data_path = fullfile(base_path, num2str(n_exp), 'Framehead_information');
output_path = fullfile(base_path, num2str(n_exp), 'Cumulative_Results');
if ~exist(output_path, 'dir'), mkdir(output_path); end

% --- 雷达系统参数 --- 
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

% --- 速度范围设置参数 ---
velocity.lowerSpeedBound = -3;
velocity.upperSpeedBound = 3;

%% 3. 初始化与预计算
% --- 在所有循环开始前，预先计算好速度轴 ---
v_axis = linspace(-params.prf/2, params.prf/2, params.prtNum) * params.wavelength / 2;

%% 4. 并行处理主循环
fprintf('--- 开始并行处理，提取所有CFAR检测点 ---\n');
fprintf('正在启动并行池...\n');
tic; % 开始计时

% --- 设置进度条 ---
try
    p = gcp; % 获取当前的并行池
catch
    % 如果没有并行池，则创建一个
    p = parpool;
end

N = length(frame_range); % 获取总的迭代次数
D = parallel.pool.DataQueue; % 创建一个数据队列
h = waitbar(0, '正在初始化并行任务...'); % 创建一个进度条窗口

% 将计数器存储在waitbar的UserData属性中
h.UserData = 0;

% 使用匿名函数将waitbar句柄和总数N传递给回调函数
afterEach(D, @(~) updateWaitbar(h, N)); 

% --- 【核心优化】将 for 更改为 parfor ---
% parfor 会将 frame_range 中的任务分配给多个worker并行执行
% 创建一个元胞数组来收集每个worker的返回结果
% --- parfor 循环 ---
parfor_results = cell(1, N);
parfor i = 1 : N         % 在 parfor 循环中，避免使用 fprintf 来显示进度，输出会混乱。
    frame_idx = frame_range(i); 
    
    % --- 每个worker独立加载所需文件 ---
    mtd_file = fullfile(mtd_data_path, ['frame_', num2str(frame_idx), '.mat']);      
    cfar_file = fullfile(cfar_data_path, ['frame_', num2str(frame_idx), '.mat']);
    header_file = fullfile(header_data_path, ['frame_', num2str(frame_idx), '.mat']);
    
    if ~exist(mtd_file, 'file') || ~exist(cfar_file, 'file') || ~exist(header_file, 'file')
        warning('帧 #%d 的文件缺失，跳过此帧。', frame_idx);
        continue; % 跳到下一次parfor迭代
    end
    
    % 使用 load 函数加载数据到临时结构体中
    mtd_data = load(mtd_file, 'MTD_win_all_beams');            % mtd 好像不怎么用的上
    cfar_data = load(cfar_file, 'cfarFlag_win_all_beams');
    header_data = load(header_file, 'FrameHead_information');  % 这个最好能用子函数直接读取
    
    % --- 初始化当前worker的局部日志变量 ---
    % 每个worker都维护一个自己的日志，最后再合并，这是parfor的标准实践
    local_detection_log = [];
    
    for b = 1:params.beam_num - 1 % 波束对数量是波束数量-1 
        for s = 1:win_size
            mtd_slice = squeeze(mtd_data.MTD_win_all_beams{b}(s, :, :));
            cfar_flag = squeeze(cfar_data.cfarFlag_win_all_beams{b}(:, :, s));
            
            [detected_v_indices, detected_r_indices] = find(cfar_flag);
            
            if ~isempty(detected_v_indices)
                % --- 向量化计算 ---
                num_detections = numel(detected_v_indices);
                % prt_info = header_data.FrameHead_information(1);
                prt_info = header_data.FrameHead_information(1);
                velocities = v_axis(detected_v_indices).';
                ranges = detected_r_indices * params.deltaR;
                linear_indices = sub2ind(size(mtd_slice), detected_v_indices, detected_r_indices);
                snrs = mtd_slice(linear_indices);
                
                % 方位角（伺服角）修正，画图函数已经修正了
                current_servo_angle = prt_info.current_servo_angle; 
                % current_servo_angle_corrected = fun_correct_servo_angle(current_servo_angle, NorthAngle, FixAngle);  % 调用伺服角修正子函数修正伺服角

                % --- 批量创建结构体 ---
                frame_cell = num2cell(repmat(frame_idx, num_detections, 1));
                beam_cell = num2cell(repmat(b, num_detections, 1));
                slice_cell = num2cell(repmat(s, num_detections, 1));
                prt_index_cell = num2cell(repmat(prt_info.pulse_no, num_detections, 1));
                range_bin_cell = num2cell(detected_r_indices);
               
                azimuth_cell = num2cell(repmat(current_servo_angle, num_detections, 1)); % 方位角单元
                
                elevation_cell = num2cell(nan(num_detections, 1)); % 俯仰角单元
                velocity_cell = num2cell(velocities);
                range_m_cell = num2cell(ranges);
                snr_cell = num2cell(snrs);
                timestamp_cell = num2cell(repmat(prt_info.timer_cnt, num_detections, 1));
                
                current_detections = struct(...
                    'frame', frame_cell, 'beam', beam_cell, 'slice', slice_cell, ...
                    'prt_index', prt_index_cell, 'range_bin', range_bin_cell, ...
                    'azimuth_deg', azimuth_cell, 'elevation_deg', elevation_cell, ...
                    'velocity_ms', velocity_cell, 'range_m', range_m_cell, ...
                    'snr', snr_cell, 'timestamp', timestamp_cell);
                
                % 将当前找到的目标点追加到局部的日志中
                local_detection_log = [local_detection_log; current_detections];
            end
        end
    end
    
    % 将当前worker处理完一整帧的结果，存入总的结果元胞数组中
    parfor_results{i} = local_detection_log;
   
    % --- 在每次迭代结束时，向队列发送一个信号 ---
    send(D, i);
end
toc; % 结束计时并显示总耗时

%% 5. 合并所有worker的结果
fprintf('--- 正在合并所有并行任务的结果 ---\n');
close(h); % 关闭进度条
% 使用vertcat和cellfun将所有非空的局部日志合并成一个总的日志
detection_log = vertcat(parfor_results{:});

%% 6. 显示、保存最终结果
% ... (此部分与原版完全相同) ...
fprintf('\n================== 分析完毕 ==================\n');
fprintf('在分析的 %d 帧数据中，共检测到 %d 个目标点。\n', length(frame_range), length(detection_log));
log_output_file = fullfile(output_path, 'detection_log.mat');
if options.save_detection_log && ~isempty(detection_log)
    save(log_output_file, 'detection_log');
    fprintf('检测点详细信息已保存到: %s\n', log_output_file);
end

% --- 根据选项调用不同的绘图函数 ---
if ~isempty(detection_log)
    switch plot_option
        case 'ppi'
            h_fig = fun_plot_cumulative_detections(detection_log, params, NorthAngle, FixAngle);
            image_output_file = fullfile(output_path, 'cumulative_ppi_plot.png');
        case 'rdm'
            h_fig = fun_plot_cumulative_rdm(detection_log, params);
            image_output_file = fullfile(output_path, 'cumulative_rdm_plot.png');
        case 'az_range'
            h_fig = fun_plot_cumulative_az_range(detection_log, params, NorthAngle, FixAngle);
            image_output_file = fullfile(output_path, 'cumulative_az_range_plot.png');
        case 'summary'
            h_fig = fun_plot_summary_dashboard(detection_log, params, NorthAngle, FixAngle, velocity);
            image_output_file = fullfile(output_path, 'summary_dashboard.png');
        case 'rhi' % 绘制距离-高度图
            h_fig = fun_plot_cumulative_rhi(detection_log, params);
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


%% --- 定义回调函数 ---
function updateWaitbar(h_waitbar, total_count)
    % 从图形句柄的UserData中读取并增加计数
    progress = h_waitbar.UserData + 1;
    h_waitbar.UserData = progress;
    
    % 更新进度条
    waitbar(progress / total_count, h_waitbar, sprintf('已处理 %d/%d 帧', progress, total_count));
end


