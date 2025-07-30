% main_visualize_results_v2.m
%
% 这是一个功能增强的可视化分析主控脚本。它负责加载处理好的MTD和CFAR结果，
% 并根据用户的配置，以多种模式循环显示分析仪表盘。
% 调用 fun_plot_cfar_dashboard_v2.m 函数
%
% 使用说明:
% 1. 在 "1. 用户配置区" 修改参数以选择要分析的数据和显示模式。
% 2. 确保 "2. 加载雷达系统参数" 中的参数与数据处理时所用参数一致。
% 3. 确保 "3. 文件路径设置" 中的路径正确。
% 4. 运行此脚本。在动态显示模式下，按任意键可显示下一张图。
%
% 修改记录:
% date       by      version   modify
% 25/06/18   XZR      v1.0    生成指定的某个波束某个切片下具体某帧信号的结果图（MTD和CFAR结果图）
% 25/06/19   XZR      v2.0    实现三种功能循环显示每个帧 切片 波束的结果图
% 未来改进：


clc; clear; close all;

%% 1. 用户配置区
% --- 显示模式设置 ---
% 'single':              基础模式。循环显示每一帧的单个指定波束和切片。
% 'all_slices_one_beam': 进阶模式1。对每一帧，依次显示单个指定波束下的所有切片。
% 'all_beams_one_slice': 进阶模式2。对每一帧，依次显示单个指定切片下的所有波束。
display_mode = 'single'; % <--- 在此修改显示模式

% --- 数据选择 ---
frame_range = 0:100;       % 要循环显示的帧编号范围 (例如 0:10)
beam_to_analyze = 1;     % 在'single'和'all_slices_one_beam'模式下，指定要分析的波束
slice_to_analyze = 2;    % 在'single'和'all_beams_one_slice'模式下，指定要分析的切片

% --- 流程控制 ---
pause_duration = 1;      % 动态显示时，每张图的暂停时间(秒)。设为 inf 则为手动按键继续。

%% 2. 加载雷达系统参数
% !!! 关键步骤 !!! 
% 这些参数必须与数据处理时使用的参数完全一致。
params.c = 2.99792458e8;
params.prtNum = 332;
params.prt = 232.76e-6;
params.fs = 25e6;
params.fc = 9450e6;
params.beam_num = 13;
params.win_size = 4; % 必须与生成数据时所用的win_size一致
% 派生参数
params.prf = 1 / params.prt;
params.wavelength = params.c / params.fc;
params.deltaR = params.c / (2 * params.fs);
% 定义绘图的固定坐标轴范围
params.plot_options.fixed_range_m = [0, 6000]; % X轴（距离）范围，单位：米
params.plot_options.fixed_velocity_ms = [-40, 40]; % Y轴（速度）范围，单位：米/秒

%% 3. 文件路径设置
filepath = uigetdir;                         % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(filepath, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(filepath);
    disp(['已选择文件路径: ', fullFile]);
end
base_path = filepath;

n_exp = 3;
T_CFAR = 7;
mtd_data_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(params.win_size)]);
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);

%% 4. 主循环与可视化
% 在所有循环之外，只创建一次figure窗口
h_fig = figure('Name', '可视化分析仪表盘', 'NumberTitle', 'off');

for frame_idx = frame_range
    % --- 加载当前帧的数据 ---
    mtd_filename = fullfile(mtd_data_path, ['frame_', num2str(frame_idx), '.mat']);
    cfar_filename = fullfile(cfar_data_path, ['frame_', num2str(frame_idx), '.mat']);
    
    if ~exist(mtd_filename, 'file') || ~exist(cfar_filename, 'file')
        warning('帧 #%d 的MTD或CFAR文件不存在，跳过此帧。', frame_idx);
        continue;
    end
    
    fprintf('正在加载第 %d 帧的数据...\n', frame_idx);
    load_mtd = load(mtd_filename, 'MTD_win_all_beams');
    load_cfar = load(cfar_filename, 'cfarFlag_win_all_beams');
    
    % 将当前帧的信息存入params，以便绘图函数调用
    params.frame_to_load = frame_idx;

    % --- 根据显示模式执行不同的绘图逻辑 ---
    switch display_mode
        case 'single'
            % --- 基础模式：显示单个指定切片 ---
            params.beam_to_plot = beam_to_analyze;
            params.slice_to_plot = slice_to_analyze;
            
            mtd_to_plot = squeeze(load_mtd.MTD_win_all_beams{params.beam_to_plot}(params.slice_to_plot, :, :));
            cfar_to_plot = squeeze(load_cfar.cfarFlag_win_all_beams{params.beam_to_plot}(:, :, params.slice_to_plot));
            
            % --- 修改点: 将h_fig作为参数传入 ---
            fun_plot_cfar_dashboard_v2(h_fig, mtd_to_plot,cfar_to_plot, params);
             
        case 'all_slices_one_beam'
            % --- 进阶模式1：显示一个波束下的所有切片 ---
            params.beam_to_plot = beam_to_analyze;
            fprintf('--- 正在显示帧 #%d, 波束 #%d 的所有切片 ---\n', frame_idx, params.beam_to_plot);
            
            for slice_idx = 1:params.win_size
                params.slice_to_plot = slice_idx;
                
                mtd_to_plot = squeeze(load_mtd.MTD_win_all_beams{params.beam_to_plot}(slice_idx, :, :));
                cfar_to_plot = squeeze(load_cfar.cfarFlag_win_all_beams{params.beam_to_plot}(slice_idx, :, :));
                
                % --- 修改点: 将h_fig作为参数传入 ---
                fun_plot_cfar_dashboard_v2(h_fig, mtd_to_plot, cfar_to_plot, params);
                
                sgtitle(sprintf('帧 #%d, 波束 #%d, 切片 #%d / %d', frame_idx, params.beam_to_plot, slice_idx, params.win_size));
                
                fprintf('暂停 %.1f 秒... (如需手动继续，请将pause_duration设为inf)\n', pause_duration);
                pause(pause_duration);
            end
            
        case 'all_beams_one_slice'
            % --- 进阶模式2：显示一个切片下的所有波束 ---
            params.slice_to_plot = slice_to_analyze;
            fprintf('--- 正在显示帧 #%d, 切片 #%d 的所有波束 ---\n', frame_idx, params.slice_to_plot);

            for beam_idx = 1:params.beam_num
                params.beam_to_plot = beam_idx;
                
                mtd_to_plot = squeeze(load_mtd.MTD_win_all_beams{beam_idx}(params.slice_to_plot, :, :));
                cfar_to_plot = squeeze(load_cfar.cfarFlag_win_all_beams{beam_idx}(params.slice_to_plot, :, :));
                
                % --- 修改点: 将h_fig作为参数传入 ---
                fun_plot_cfar_dashboard_v2(h_fig, mtd_to_plot, cfar_to_plot, params);
                
                sgtitle(sprintf('帧 #%d, 切片 #%d, 波束 #%d / %d', frame_idx, params.slice_to_plot, beam_idx, params.beam_num));

                fprintf('暂停 %.1f 秒... (如需手动继续，请将pause_duration设为inf)\n', pause_duration);
                pause(pause_duration);
            end
            
    end % switch end
    
    % 在'single'模式下，每帧之间暂停
    if strcmp(display_mode, 'single')
        fprintf('暂停 %.1f 秒... (如需手动继续，请将pause_duration设为inf)\n', pause_duration);
        pause(pause_duration);
    end
    
end % frame loop end

disp('所有指定帧显示完毕。');
