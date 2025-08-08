% main_analyze_and_visualize_v2.m
% 该版本有bug，暂时用v1
% v2.0 更新:
% - 处理逻辑已完全更新，以匹配"13个原始波束形成12组和差波束对"的新雷达体制。
% - 移除了所有关于"长短脉冲"的过时逻辑。
% - 将第四阶段的"参数测量"逻辑完整地集成到了parfor循环中。
% - 这是一个真正意义上的"一站式"分析主控脚本。
%
% 修改记录
% date       by      version   modify
% 25/07/16   XZR      v2.0     直接处理最终测量结果

clc; clear; close all;

%% 1. 用户配置区
% =========================================================================
force_reprocess = false; 
plot_option = 'summary';

% --- 数据筛选掩码配置 ---
filters.enable = true;
filters.velocity_ms = [-inf, -3; 3, inf]; 
filters.range_m = [500, 5000];
filters.height_m = [0, 1000];
filters.snr = 1000; 

% --- 角度修正与标定参数 ---
NorthAngle = 307;
FixAngle = 35;

%% 2. 路径与参数配置
% =========================================================================
n_exp = 3;
win_size = 4;
T_CFAR = 10;
base_path  = uigetdir('', '请选择数据根目录');
if isequal(base_path, 0), disp('用户取消了文件选择。'); return; end

% --- 定义所有路径 ---
mtd_data_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);
header_data_path = fullfile(base_path, num2str(n_exp), 'Framehead_information');
output_path = fullfile(base_path, num2str(n_exp), 'Cumulative_Results');
if ~exist(output_path, 'dir'), mkdir(output_path); end
final_log_path = fullfile(output_path, 'final_detection_log.mat');

% --- 定义雷达系统与测量参数 ---
config.Sig_Config.c = 2.99792458e8; config.Sig_Config.prtNum = 332; 
config.Sig_Config.prt = 232.76e-6; config.Sig_Config.fs = 25e6; 
config.Sig_Config.fc = 9450e6; config.Sig_Config.beam_num = 13;
config.Sig_Config.prf = 1 / config.Sig_Config.prt;
config.Sig_Config.wavelength = config.Sig_Config.c / config.Sig_Config.fc;
config.Sig_Config.deltaR = config.Sig_Config.c / (2 * config.Sig_Config.fs);
config.Sig_Config.beam_angles_deg = [-12.5, -7.5, -2.5, 2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5];
config.angle_k_path = fullfile(base_path,'K_value', 'R9-DMX3-2024001_Angle_k.csv'); % K值文件路径

config.interpolation.extra_dots = 2;
config.interpolation.range_interp_times = 8;
config.interpolation.velocity_interp_times = 4;

%% 3. 加载或生成最终目标日志
% =========================================================================
if exist(final_log_path, 'file') && ~force_reprocess
    fprintf('--- 发现已存在的最终日志文件，正在加载... ---\n');
    load(final_log_path, 'final_log');
else
    fprintf('--- 开始执行完整的数据处理与参数测量流程... ---\n');
    
    frame_range = 0:150;
    v_axis = linspace(-config.Sig_Config.prf/2, config.Sig_Config.prf/2, config.Sig_Config.prtNum) * config.Sig_Config.wavelength / 2;
    
    fprintf('正在启动并行池...\n');
    tic; 
    try p = gcp; catch; p = parpool; end
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
            continue;
        end
        
        mtd_data = load(mtd_file, 'MTD_win_all_beams');
        cfar_data = load(cfar_file, 'cfarFlag_win_all_beams');
        header_data = load(header_file, 'FrameHead_information');
        freInd = header_data.FrameHead_information(1).freq_no;
        
        local_final_log = [];
        
        % --- 【核心逻辑】循环遍历12个和差波束对 ---
        for b = 1:config.Sig_Config.beam_num - 1 
            for s = 1:win_size
                cfar_flag = cfar_data.cfarFlag_win_all_beams{b}(:, :, s);
                [detected_v_indices, detected_r_indices] = find(cfar_flag);
                
                if ~isempty(detected_v_indices)
                    RDM_beam1 = mtd_data.MTD_win_all_beams{b}(s, :, :);
                    RDM_beam2 = mtd_data.MTD_win_all_beams{b+1}(s, :, :);
                    RDM_sum_amp = abs(RDM_beam1) + abs(RDM_beam2);

                    k_value = fun_get_k_value(config, freInd, b);
                    
                    for k = 1:length(detected_v_indices)
                        v_idx = detected_v_indices(k);
                        r_idx = detected_r_indices(k);
                        
                        % 准备参数测量函数的输入
                        prelim_detection.complex_val_beam1 = RDM_beam1(v_idx, r_idx);
                        prelim_detection.complex_val_beam2 = RDM_beam2(v_idx, r_idx);
                        prelim_detection.beam_pair_index = b;
                        prelim_detection.range_index = r_idx;
                        prelim_detection.velocity_index = v_idx;

                        % 调用参数测量引擎
                        estimated_params = fun_parameter_estimation(prelim_detection, RDM_sum_amp, k_value, config);
                        
                        % 记录最终结果
                        current_detection.frame = frame_idx;
                        current_detection.slice = s;
                        current_detection.beam_pair = b;
                        current_detection.range_m = estimated_params.range_m;
                        current_detection.velocity_ms = estimated_params.velocity_ms;
                        current_detection.elevation_deg = estimated_params.elevation_deg;
                        current_detection.height_m = estimated_params.height_m;
                        current_detection.snr = estimated_params.snr;
                        current_detection.azimuth_deg = header_data.FrameHead_information(1).current_servo_angle;

                        local_final_log = [local_final_log; current_detection];
                    end
                end
            end
        end
        parfor_results{i} = local_final_log;
        send(D, i);
    end
    toc;
    
    fprintf('--- 正在合并所有并行任务的结果 ---\n');
    close(h);
    final_log = vertcat(parfor_results{:});
    
    if ~isempty(final_log)
        fprintf('处理完成，共累积 %d 个检测点。\n', length(final_log));
        save(final_log_path, 'final_log');
        fprintf('最终日志已保存到: %s\n', final_log_path);
    else
        warning('处理完成，但未检测到任何目标点。');
    end
end

if isempty(final_log)
    disp('日志为空，没有可供分析的目标点。程序结束。');
    return;
end

%% 4. 应用数据筛选掩码
if filters.enable
    fprintf('--- 正在应用数据筛选掩码 ---\n');
    all_velocities = [final_log.velocity_ms];
    all_ranges = [final_log.range_m];
    all_heights = [final_log.height_m];
    all_snr = [final_log.snr];
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
    filtered_log = final_log(combined_mask);
    fprintf('筛选完毕，原始点数: %d, 剩余点数: %d\n', length(final_log), length(filtered_log));
    if isempty(filtered_log)
        disp('筛选后无剩余目标点，程序结束。');
        return;
    end
else
    filtered_log = final_log; 
end

%% 5. 调用绘图函数
fprintf('--- 正在生成可视化图表 ---\n');
fun_plot_final_dashboard(filtered_log, config, NorthAngle, FixAngle, plot_option);
fprintf('--- 可视化分析完成 ---\n');

%% --- 定义回调函数 ---
function updateWaitbar(h_waitbar, total_count)
    progress = h_waitbar.UserData + 1;
    h_waitbar.UserData = progress;
    waitbar(progress / total_count, h_waitbar, sprintf('已处理 %d/%d 帧', progress, total_count));
end
