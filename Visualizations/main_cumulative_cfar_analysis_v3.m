% 已弃用，被 main_visualize_final_results_v1.m 取代
% main_cumulative_cfar_analysis_v3.m
%
% v2.3 更新:
% - 在parfor循环内部增加了速度掩码(velocity mask)逻辑。
% - 现在，只有通过CFAR检测且速度符合用户定义范围的目标点才会被记录到日志中。
%
% 这是一个使用并行计算进行优化的累积CFAR结果分析主控脚本。
% 1. 将主循环从 for 更改为 parfor，以利用多核CPU并行处理，显著提高运行速度。
% 2. 调整了数据收集逻辑以适应 parfor 的工作机制。
%
% 修改记录
% date       by      version                 modify
% 25/07/07   XZR      v1.0     在main_cumulative_cfar_analysis.m的基础上引入parfor加速信号处理
% 25/07/15   XZR      v2.2     修正数据切片的维度索引方式
% 25/07/15   XZR      v2.3     增加速度值掩码筛选功能
%                               
clc; clear; close all;
%% 1. 用户配置区
% --- 绘图选项 ---
plot_option = 'summary'; 
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
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);
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
% --- 【新增】速度范围设置参数 ---
% 定义要保留的目标速度范围。注意：这里是"排除"这个范围内的点。
% 例如，要保留大于2m/s和小于-2m/s的点，应设置边界为2和-2。
velocity.upperSpeedBound = 10;   % 速度上界 (m/s)
velocity.lowerSpeedBound = -10;  % 速度下界 (m/s)
%% 3. 初始化与预计算
v_axis = linspace(-params.prf/2, params.prf/2, params.prtNum) * params.wavelength / 2;
%% 4. 并行处理主循环
fprintf('--- 开始并行处理，提取所有CFAR检测点 ---\n');
fprintf('正在启动并行池...\n');
tic; 
try
    p = gcp; 
catch
    p = parpool;
end
N = length(frame_range);
D = parallel.pool.DataQueue; 
h = waitbar(0, '正在初始化并行任务...');
h.UserData = 0;
afterEach(D, @(~) updateWaitbar(h, N)); 
parfor_results = cell(1, N);

parfor i = 1 : N
    frame_idx = frame_range(i); 
    
    mtd_file = fullfile(mtd_data_path, ['frame_', num2str(frame_idx), '.mat']);      
    cfar_file = fullfile(cfar_data_path, ['frame_', num2str(frame_idx), '.mat']);
    header_file = fullfile(header_data_path, ['frame_', num2str(frame_idx), '.mat']);
    
    if ~exist(mtd_file, 'file') || ~exist(cfar_file, 'file') || ~exist(header_file, 'file')
        warning('帧 #%d 的文件缺失，跳过此帧。', frame_idx);
        continue;
    end
    
    mtd_data = load(mtd_file, 'MTD_win_all_beams');
    cfar_data = load(cfar_file, 'cfarFlag_win_all_beams');
    header_data = load(header_file, 'FrameHead_information');
    
    local_detection_log = [];
    
    for b = 1:params.beam_num - 1 
        for s = 1:win_size
            
            cfar_flag = cfar_data.cfarFlag_win_all_beams{b}(:, :, s);
            [detected_v_indices, detected_r_indices] = find(cfar_flag);
            
            if ~isempty(detected_v_indices)
                
                % --- 【核心修改】速度筛选逻辑 ---
                % 1. 计算所有CFAR检测点的物理速度
                physical_velocities = v_axis(detected_v_indices).';
                
                % 2. 创建一个逻辑掩码(mask)，只保留速度在指定范围之外的点
                velocity_mask = (physical_velocities > velocity.upperSpeedBound) | (physical_velocities < velocity.lowerSpeedBound);
                
                % 3. 应用掩码，过滤掉不符合速度要求的目标点
                detected_v_indices = detected_v_indices(velocity_mask);
                detected_r_indices = detected_r_indices(velocity_mask);
                
                % 如果筛选后仍有目标，则继续处理
                if isempty(detected_v_indices)
                    continue; % 跳到下一次循环
                end
                % --- 速度筛选结束 ---

                % --- 向量化计算 ---
                RDM_beam1 = mtd_data.MTD_win_all_beams{b}(s, :, :);
                RDM_beam2 = mtd_data.MTD_win_all_beams{b+1}(s, :, :);
                RDM_sum_amp = abs(RDM_beam1) + abs(RDM_beam2);

                num_detections = numel(detected_v_indices);
                prt_info = header_data.FrameHead_information(1);
                velocities = v_axis(detected_v_indices).';
                ranges = detected_r_indices * params.deltaR;
                linear_indices = sub2ind(size(RDM_sum_amp), detected_v_indices, detected_r_indices);
                snrs = RDM_sum_amp(linear_indices);
                
                % --- 批量创建结构体 ---
                current_servo_angle = prt_info.current_servo_angle; 
                frame_cell = num2cell(repmat(frame_idx, num_detections, 1));
                beam_cell = num2cell(repmat(b, num_detections, 1));
                slice_cell = num2cell(repmat(s, num_detections, 1));
                prt_index_cell = num2cell(repmat(prt_info.pulse_no, num_detections, 1));
                range_bin_cell = num2cell(detected_r_indices);
                azimuth_cell = num2cell(repmat(current_servo_angle, num_detections, 1));
                elevation_cell = num2cell(nan(num_detections, 1));
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
                
                local_detection_log = [local_detection_log; current_detections];
            end
        end
    end
    
    parfor_results{i} = local_detection_log;
    send(D, i);
end
toc;
%% 5. 合并所有worker的结果
fprintf('--- 正在合并所有并行任务的结果 ---\n');
close(h);
detection_log = vertcat(parfor_results{:});
%% 6. 显示、保存最终结果
fprintf('\n================== 分析完毕 ==================\n');
fprintf('在分析的 %d 帧数据中，共检测到 %d 个目标点。\n', length(frame_range), length(detection_log));
log_output_file = fullfile(output_path, 'detection_log.mat');
if options.save_detection_log && ~isempty(detection_log)
    save(log_output_file, 'detection_log');
    fprintf('检测点详细信息已保存到: %s\n', log_output_file);
end
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
    progress = h_waitbar.UserData + 1;
    h_waitbar.UserData = progress;
    waitbar(progress / total_count, h_waitbar, sprintf('已处理 %d/%d 帧', progress, total_count));
end
