% main_integrated_processing.m 是一个一体化的雷达信号处理 总控脚本。
% 它将数据读取、MTD处理和CFAR检测三个阶段串联起来，
% 实现了从原始.bin文件到最终CFAR结果的一键式自动化处理。
% 通过配置开关，可以选择性地保存中间阶段的数据。
%
% 修改记录
% date       by      version   modify
% 25/06/25   XZR      v1.0     创建
% 25/07/15   XZR      v2.0     增添波束成形部分，利用和波束做CFAR目标检测，差波束用来单脉冲测角
% 25/07/27   XZR      v3.0     更新了对第四阶段返回值的处理，以适应新的两层数据结构

clc; clear; close all;

%% 1. 全局参数配置区 (所有参数在此统一设置 Config)
fprintf('--- 开始进行全局参数配置 ---\n');

% --- 0.0 实际测量时一些修正参数 ---
% 伺服角（方位角）修正系数
config.corrected.North = 307;                % 雷达指北角（见雷达系统设置文件 SysSet.ini.bak）
config.corrected.FixAngle = 35;              % 雷达固定角（见初始化参数文件 InitPara.ini）
% 俯仰角修正系数 
config.corrected.ELeAngleSettingValue = -10; % 雷达俯仰设置值（见雷达系统设置文件 SysSet.ini.bak）

% --- 1.1 流程控制 --- 
config.frame_range = 0 : 155;                         % 指定要处理的帧范围
config.save_options.save_frameheads_mat = true;       % 开关：是否保存读取文件时检测的文件帧头信息
config.save_options.save_iq_mat_before_DBF = true;    % 开关：是否保存原始的16通道I/Q数据
config.save_options.save_iq_mat_after_DBF = true;     % 开关：是否保存第一阶段的.mat格式I/Q数据
config.save_options.save_pc_mat = true;               % 开关：是否保存脉冲压缩(PC)结果
config.save_options.save_mtd_mat = true;              % 开关：是否保存第二阶段的MTD结果
config.save_options.save_cfar_mat = true;             % 开关：是否保存第三阶段的CFAR结果矩阵 (CFARflag)
config.save_options.save_beam_sum_cfar_mat = true;    % 开关：是否保存第三阶段和波束CFAR目标检测阶段结果
config.save_options.save_final_log = true;            % 开关：是否保存第四阶段差波束参数测量的结果（按帧保存）   
config.save_options.save_cumulative_log = true;       % 开关：是否保存所有帧累积的测量结果
config.save_options.save_to_bin = true;              % 开关：是否保存目标检测点信息为二进制.bin文件

% --- 1.2 路径配置 ---
filepath = uigetdir;                               % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如“X8数据采集250522”
if isequal(filepath, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(filepath);
    disp(['已选择文件路径: ', fullFile]);
end
config.base_path = filepath;

% --- 1.3 实验数据路径 ---
config.n_exp = 3;  % 具体实验组数（项目文件组数） 
config.DBF_coef_path = fullfile(config.base_path, 'DBF_data', 'X8数据采集250522_DBFcoef.csv');          % 用于 DDC 数据波束成形的 DBF 系数，先处理成CSV（逗号分隔值）文件
config.raw_data_path = fullfile(config.base_path, num2str(config.n_exp), '2025年05月22日17时10分05秒'); % 原始二进制 bin  数据文件夹
config.angle_k_path = fullfile(config.base_path, 'K_value', 'R9-DMX3-2024001_Angle_k.csv');             % 用于和差比幅的K值矩阵

% --- 1.4 雷达系统基础参数 ---
MHz = 1e6; % 定义MHz单位
config.Sig_Config.c = 2.99792458e8;            % 光速
config.Sig_Config.pi = pi;                     % 圆周率
config.Sig_Config.fs = 25e6;                   % 采样率 (Hz)
config.Sig_Config.fc = 9450e6;                 % 中心频率 (Hz)
config.Sig_Config.timer_freq = 200e6;          % 时标计数频率 
config.Sig_Config.prtNum = 332;                % 定义每帧信号的脉冲数，每帧信号包含 332 个脉冲
config.Sig_Config.point_PRT = 3404;            % 定义每个PRT中的采样点数（距离单元）
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

config.Sig_Config.beam_angles_deg = [-12.5, -7.5, -2.5, 2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5]; % 13个波束的标称俯仰角 (Nominal Elevation Angles)
config.Sig_Config.beam_angles_deg = config.Sig_Config.beam_angles_deg + config.corrected.ELeAngleSettingValue;

config.Sig_Config.debug.show_PC = 0;              % 脉冲压缩结果显示
config.Sig_Config.debug.show_FFT = 0;             % 速度维显示
config.Sig_Config.debug.graph = 0;                % 是否画图 

% --- 1.5 MTD处理参数 ---
config.mtd.win_size = 4;                          % MTD 窗口切片数  

config.mtd.c = config.Sig_Config.c;               % 光速
config.mtd.pi = config.Sig_Config.pi;             % 圆周率
config.mtd.prtNum = config.Sig_Config.prtNum;     % 每帧信号的脉冲数
config.mtd.fs = config.Sig_Config.fs;             % 采样频率 (Hz)
config.mtd.fc = config.Sig_Config.fc;             % 中心频率 (Hz)
config.mtd.beam_num = config.Sig_Config.beam_num; % 雷达总波束数量
config.mtd.prt = config.Sig_Config.prt;           % 脉冲重复时间 (s)
config.mtd.B = config.Sig_Config.B;               % 带宽 (Hz)
config.mtd.tao = config.Sig_Config.tao;           % 脉宽 [窄, 中, 长]
config.mtd.point_prt = config.Sig_Config.point_prt;   % 采集点数 [总采集点数，窄脉冲采集点数，中脉冲采集点数，长脉冲采集点数]   
config.mtd.prf = 1 / config.mtd.prt;                  
config.mtd.wavelength = config.Sig_Config.wavelength; % 信号波长
config.mtd.deltaR = config.Sig_Config.deltaR;         % 距离分辨率由采样率决定
config.mtd.tao1 = config.Sig_Config.tao1;             % 窄脉宽 
config.mtd.tao2 = config.Sig_Config.tao2;             % 中脉宽
config.mtd.tao3 = config.Sig_Config.tao3;             % 长脉宽
config.mtd.K1   = config.Sig_Config.B/config.Sig_Config.tao1;   % 短脉冲调频斜率
config.mtd.K2   = -config.Sig_Config.B/config.Sig_Config.tao2;  % 中脉冲调频斜率（负）
config.mtd.K3   = config.Sig_Config.B/config.Sig_Config.tao3;   % 长脉冲调频斜率

% --- 1.6 CFAR处理参数 ---

% --- CFAR核心参数 ---
config.cfar.T_CFAR = 10;                   % 恒虚警标称化因子
config.cfar.MTD_V = 3;                     % 杂波区速度范围，速度在 -3 m/s 到 +3 m/s 范围内的区域都当作是地杂波区域，在CFAR检测中忽略掉。

% --- 速度维参数 ---
config.cfar.refCells_V = 5;                % 速度维 参考单元数
config.cfar.saveCells_V = 14;              % 速度维 保护单元数
config.cfar.T_CFAR_V = config.cfar.T_CFAR; % 速度维恒虚警标称化因子
config.cfar.CFARmethod_V = 0;              % 0--选大；1--选小

% --- 距离维参数 ---
config.cfar.rCFARDetect_Flag = 1;          % 距离维CFAR检测操作标志。 0-否； 1-是
config.cfar.refCells_R = 5;                % 距离维 参考单元数
config.cfar.saveCells_R = 14;              % 距离维 保护单元数
config.cfar.T_CFAR_R = config.cfar.T_CFAR; % 距离维恒虚警标称化因子7,越低，门限越低，虚警率越高
config.cfar.CFARmethod_R = 0;              % 0--选大；1--选小

% --- 计算杂波区对应的速度单元数 ---
config.cfar.deltaDoppler = config.Sig_Config.prf/config.Sig_Config.prtNum;      % 计算多普勒频率分辨率
config.cfar.deltaV = config.Sig_Config.wavelength*config.cfar.deltaDoppler/2;   % 计算速度分辨率：计算出了一个频率单元（deltaDoppler）等效于多少米/秒（m/s）的速度。这个 deltaV 就是雷达能分辨的最小速度差。
config.cfar.MTD_0v_num = floor(config.cfar.MTD_V/config.cfar.deltaV);           % 计算杂波区的宽度（以单元数计），在进行CFAR检测时，需要以零速为中心，向两侧各跳过 MTD_0v_num 个速度单元，以避开强大的地杂波对噪声估计的干扰。

% --- 画图参数（绘图坐标轴参数）---
config.cfar.graph = 0;
config.cfar.prtNum = config.Sig_Config.prtNum;            % 每帧信号prt数量
config.cfar.point_prt = config.Sig_Config.point_prt(1);   % 3个脉冲的PRT总采集点数
config.cfar.R_point = 6;                                  % 每个距离单元长度（两点间距6m）
config.cfar.r_axis = 0 : config.cfar.R_point: config.cfar.point_prt*config.cfar.R_point-config.cfar.R_point;  % 距离轴
config.cfar.fd = linspace(-config.Sig_Config.prf/2, config.Sig_Config.prf/2, config.Sig_Config.prtNum);           
config.cfar.v_axis = config.cfar.fd*config.Sig_Config.wavelength/2;                                           % 速度轴
% v_axis = v_axis(691:845);
% (其他如refCells, saveCells等参数也应在此定义)

% --- 目标参数测量参数与插值参数 --- 
config.interpolation.extra_dots = 2;            % 插值时在峰值两侧各取几个点
config.interpolation.range_interp_times = 8;    % 距离维插值倍数
config.interpolation.velocity_interp_times = 4; % 速度维插值倍数



% --- 1.7 创建所有输出目录 ---
config.output_paths.framehead = fullfile(config.base_path, num2str(config.n_exp), 'Framehead_information');
config.output_paths.iq_before_DBF = fullfile(config.base_path, num2str(config.n_exp), 'iq_data_before_DBF');
config.output_paths.iq_after_DBF = fullfile(config.base_path, num2str(config.n_exp), 'BasebandRawData_mat');
config.output_paths.pc = fullfile(config.base_path, num2str(config.n_exp), 'pulse_compressed_data');
config.output_paths.mtd = fullfile(config.base_path, num2str(config.n_exp), ['MTD_data_win', num2str(config.mtd.win_size)]);
config.output_paths.cfar = fullfile(config.base_path, num2str(config.n_exp), ['cfarFlag4_T', num2str(config.cfar.T_CFAR)]);
config.output_paths.beam_sum_cfar = fullfile(config.base_path, num2str(config.n_exp), ['beam_sum_cfarFlag4_T', num2str(config.cfar.T_CFAR)]);
config.output_paths.beam_diff_estimation = fullfile(config.base_path, num2str(config.n_exp), ['beam_diff_estimation_cfarFlag4_T', num2str(config.cfar.T_CFAR)]);
config.output_paths.beam_diff_estimation_cumulative = fullfile(config.base_path, num2str(config.n_exp), 'beam_diff_estimation_cumulative');
config.output_paths.bin_output = fullfile(config.base_path, num2str(config.n_exp), 'Save_bin');


if config.save_options.save_frameheads_mat,    mkdir(config.output_paths.framehead);     end   % 开关：是否保存读取文件时检测的文件帧头信息
if config.save_options.save_iq_mat_before_DBF, mkdir(config.output_paths.iq_before_DBF); end
if config.save_options.save_iq_mat_after_DBF,  mkdir(config.output_paths.iq_after_DBF);  end
if config.save_options.save_pc_mat, mkdir(config.output_paths.pc);                       end
if config.save_options.save_mtd_mat,           mkdir(config.output_paths.mtd);           end
if config.save_options.save_cfar_mat,          mkdir(config.output_paths.cfar);          end
if config.save_options.save_beam_sum_cfar_mat, mkdir(config.output_paths.beam_sum_cfar); end
if config.save_options.save_final_log,         mkdir(config.output_paths.beam_diff_estimation);            end
if config.save_options.save_cumulative_log,    mkdir(config.output_paths.beam_diff_estimation_cumulative); end
if config.save_options.save_to_bin,            mkdir(config.output_paths.bin_output);    end


%% 2. 初始化与预加载
% --- 加载DBF系数 ---
try
    DBF_coeffs_data = readmatrix(config.DBF_coef_path);
    DBF_coeffs_data_I = double(DBF_coeffs_data(:, 1:2:end));
    DBF_coeffs_data_Q = double(DBF_coeffs_data(:, 2:2:end));
    DBF_coeffs_data_C = DBF_coeffs_data_I + 1j * DBF_coeffs_data_Q;
catch ME
    error('读入DBF系数文件失败: %s', ME.message);
end

% --- 清除所有函数的持久化状态 ---
clear read_continuous_file_stream;
clear FrameDataRead_xzr; 
clear manage_retry_count;

%% 3. 一体化处理主循环
tic;
fprintf('--- 开始一体化处理流程 ---\n');

cumulative_final_log = []; % 初始化一个空的结构体数组，用于累积所有帧的最终结果

% --- 为处理"拼接窗口"，需要预读一帧（MTD中为提高相参时间积累，选择拼接上下帧）---
fprintf('预加载第 %d 帧的数据...\n', config.frame_range(1));
[iq_data1, raw_iq_data1, angle1, frame_headers1, success, is_end] = process_stage1_read_data(config.frame_range(1), config, DBF_coeffs_data_C);

if ~success
    error('无法读取第一帧数据，程序中止。请检查数据文件或路径。')
end
 
% --- 信号处理处理主循环 ---
for frame_idx = 1 : length(config.frame_range) - 1
    
    current_frame_num = config.frame_range(frame_idx);
    next_frame_num = config.frame_range(frame_idx + 1);
    % current_frame_num = frame_idx;
    % next_frame_num = frame_idx + 1;
    fprintf('\n================== 正在处理逻辑帧: %d ==================\n', current_frame_num);
    
    % --- STAGE 1: 读取下一帧数据 ---
    fprintf('STAGE 1: 正在从.bin文件流中读取第 %d 帧...\n', next_frame_num) ;
    [iq_data2, raw_iq_data2, angle2, frame_headers2, success, is_end] = process_stage1_read_data(next_frame_num, config, DBF_coeffs_data_C);
    if ~ success || is_end
        fprintf('无法读取更多帧，处理结束。\n');
        break;
    end     
    
    % 保存帧头信息
    if config.save_options.save_frameheads_mat
        FrameHead_information = frame_headers1;
        save(fullfile(config.output_paths.framehead, ['frame_',num2str(current_frame_num),'.mat']), 'FrameHead_information');
        fprintf('  > 已保存第 %d 帧的帧头信息。\n', current_frame_num);
    end
    
    % 保存原始的16通道I/Q数据
    if config.save_options.save_iq_mat_before_DBF
        raw_iq_data = raw_iq_data1; % 使用当前帧的数据
        servo_angle = angle1;       % 同时保存对应的角度信息
        save(fullfile(config.output_paths.iq_before_DBF, ['frame_',num2str(current_frame_num),'.mat']), 'raw_iq_data', 'servo_angle');
        fprintf('  > 已保存第 %d 帧的原始16通道I/Q数据。\n', current_frame_num);
    end
    
    % 保存第一阶段的结果 (可选) 
    if config.save_options.save_iq_mat_after_DBF
        sig_data_DBF_allprts = iq_data1;
        servo_angle = angle1;
        save(fullfile(config.output_paths.iq_after_DBF, ['frame_',num2str(current_frame_num),'.mat']),'sig_data_DBF_allprts','servo_angle');
        fprintf('  > 已保存第 %d 帧的I/Q数据。\n', current_frame_num);
    end

    % --- STAGE 2: MTD处理 ---
    fprintf('STAGE 2: 正在对帧 %d 和 %d 进行MTD处理...\n', current_frame_num, next_frame_num);
    [mtd_results, angles_wins, pc_results] = process_stage2_mtd(iq_data1, iq_data2, angle1, angle2, config);
    
    % 保存第二阶段的结果 (可选) 
    % 保存脉冲压缩结果
    if config.save_options.save_pc_mat
        % 将变量重命名为更有意义的名称再保存
        pc_data_all_beams = pc_results;
        servo_angle = angles_wins; % 同时保存对应的角度信息
        save(fullfile(config.output_paths.pc, ['frame_',num2str(current_frame_num),'.mat']), 'pc_data_all_beams', 'servo_angle');
        fprintf('  > 已保存第 %d 帧的脉冲压缩结果。\n', current_frame_num);
    end
    
    % 保存MTD结果
    if config.save_options.save_mtd_mat
        MTD_win_all_beams = mtd_results;
        save(fullfile(config.output_paths.mtd, ['frame_',num2str(current_frame_num),'.mat']),'MTD_win_all_beams','angles_wins');
        fprintf('  > 已保存第 %d 帧的MTD结果。\n', current_frame_num);
    end
   
    % --- STAGE 3: 波束成形及和波束CFAR检测 ---
    [prelim_log, cfar_flags] = process_stage3_detection(mtd_results, angle1, config, current_frame_num);
    
    if config.save_options.save_beam_sum_cfar_mat % 可以在config中增加新的保存开关
        save(fullfile(config.output_paths.beam_sum_cfar, ['frame_', num2str(current_frame_num), '.mat']), 'prelim_log');
        fprintf('  > 已保存第 %d 帧的初步检测日志。\n', current_frame_num);
    end

    % 根据开关，选择性地保存CFAR标志矩阵，以供绘图函数使用
    if config.save_options.save_cfar_mat
        cfarFlag_win_all_beams = cfar_flags; % 重命名以匹配旧变量名
        output_filename = fullfile(config.output_paths.cfar, ['frame_', num2str(current_frame_num), '.mat']);
        save(output_filename, 'cfarFlag_win_all_beams');
        fprintf('  > 已保存第 %d 帧的CFAR标志矩阵。\n', current_frame_num);
    end


    % --- STAGE 4: 差波束单脉冲测角（参数测量） ---
    % 1. 按帧保存 (可选) 注意，此处伺服角仍是原始方位角
    beamdiff_estimation = process_stage4_measurement(prelim_log, mtd_results, config, frame_headers1); % 假设frame_headers1是当前帧的帧头
    
    if config.save_options.save_final_log
        save(fullfile(config.output_paths.beam_diff_estimation, ['frame_', num2str(current_frame_num), '.mat']), 'beamdiff_estimation');
        fprintf('  > 已保存第 %d 帧的最终检测日志。\n', current_frame_num);
    end
    
    % 2. 累积结果 (可选) 注意，此处伺服角已经调用子函数修正
    beamdiff_estimation_cumulative = process_stage4_measurement_v2(prelim_log, mtd_results, config, frame_headers1); % 假设frame_headers1是当前帧的帧头
        
    if config.save_options.save_cumulative_log
        cumulative_final_log = [cumulative_final_log; beamdiff_estimation_cumulative];
    end


    % % --- STAGE 5：目标检测信息保存为二进制 .bin 文件 ---
    % if config.save_options.save_to_bin && ~isempty(beamdiff_estimation)
    %     output_bin_filename = fullfile(config.output_paths.bin_output, 'detection_results.bin');
    % 
    %     % 调用我们之前创建的函数来执行保存操作
    %     save_log_to_bin(beamdiff_estimation, output_bin_filename, config);
    % end

    % % 需要修改为差波束参数测量
    % % --- STAGE 3: CFAR检测 ---
    % 
    % fprintf('STAGE 3: 正在对MTD结果进行CFAR检测...\n');
    % [cfar_results] = process_stage3_cfar(mtd_results, config); % 假设您已将CFAR逻辑封装
    % % cfar_results = cell(config.Sig_Config.beam_num, 1); % 这是一个示例，实际应为CFAR处理后的结果
    % % fprintf('  > CFAR检测完成。\n');
    % 
    % % (可选) 保存第三阶段的结果
    % if config.save_options.save_cfar_mat
    %     cfarFlag_win_all_beams = cfar_results;
    %     save(fullfile(config.output_paths.cfar, ['frame_',num2str(current_frame_num),'.mat']),'cfarFlag_win_all_beams');
    %     fprintf('  > 已保存第 %d 帧的CFAR结果。\n', current_frame_num);
    % end
    
    % --- 为下一次循环准备数据 ---
    iq_data1 = iq_data2;
    raw_iq_data1 = raw_iq_data2;
    angle1 = angle2;
    frame_headers1 = frame_headers2;
end

toc;

%% 4. 最终累积结果保存

if config.save_options.save_cumulative_log && ~isempty(cumulative_final_log)
    cumulative_log_path = fullfile(config.output_paths.beam_diff_estimation_cumulative, 'cumulative_detection_log.mat');
    
    save(cumulative_log_path, 'cumulative_final_log');
    fprintf('  > 累积的最终日志已保存，共包含 %d 帧的数据。\n', length(cumulative_final_log));
end

disp('所有一体化处理流程完成。');

%% 5. 累计结果mat文件转bin文件 见 Output_bin 文件夹中 main_mat_to_bin_converter.m 主程序脚本

% if config.save_options.save_cumulative_log
%     mat_output_path = cumulative_log_path;
%     bin_output_path = fullfile(config.output_paths.bin_output, 'Result_bin');
%     fun_output_mat2bin(bin_output_path, cumulative_final_log) 
% 
% end