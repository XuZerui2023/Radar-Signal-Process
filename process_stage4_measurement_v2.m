% process_stage4_measurement_v2.m - 参数测量阶段 (处理流程第四阶段)
% 本函数负责对第三阶段输出的"初步检测日志" 进行精细化处理，计算出每个检测目标的精确物理参数。
%
% 输入参数:
%   prelim_log    - (struct array) 由第三阶段生成的初步检测日志。
%   config        - (struct) 全局配置结构体。
%   frame_headers - (struct array) 当前帧的帧头信息。
%
% 输出:
%   frame_pack    - (struct) 包含单帧所有信息的两层结构体。
%
%  修改记录
%  date       by      version   modify
%  25/07/12   XZR      v1.0     创建
%  25/07/27   XZR      v2.0     修改文件保存格式，取消分帧存储，函数的输出被重构为一个单一的、两层嵌套的结构体 frame_pack

function frame_pack = process_stage4_measurement_v2(prelim_log, mtd_results, config, frame_headers)
%% 1. 初始化
fprintf('--- STAGE 4: 参数测量开始 ---\n');

% --- 初始化一个空的、符合最终格式的 frame_pack 结构体 ---
frame_pack = struct(...
    'iFrame', 0, ...              % 帧号
    'iWaveFormNo', 0, ...         % 波形号 (使用占位符)
    'iDistanceMode', 0, ...       % 距离模式 (使用占位符)
    'iAntSpeedMode', 0, ...       % 天线转速模式 (使用占位符)
    'iAntAngle', 0, ...           % 天线方位角
    'iCenterFreq', 0, ...         % 工作中心频率
    'T_Wave', 0, ...              % 波位驻留时间 (使用占位符)
    'TimeScale', 0, ...           % 时标
    'iGoalNum', 0, ...            % 目标个数
    'Goal_Para_Frame', [] ...     % 【嵌套】目标参数信息结构体数组
);

% 如果没有初步检测点，直接返回这个空的 frame_pack
% if isempty(prelim_log)
%     fprintf('  > 初步检测日志为空，无需测量。跳过此阶段。\n');
%     return;
% end

north_angle = config.corrected.North;    % 雷达指北角
fix_angle = config.corrected.FixAngle;   % 雷达固定角

% --- 从帧头文件中获取公共信息 ---
% 假设整帧的公共信息与第一个PRT的帧头一致
first_prt_header = frame_headers(1);
servo_angle_corrected = fun_correct_servo_angle(first_prt_header.current_servo_angle, north_angle, fix_angle);  % 伺服角修正
frame_pack.iAntAngle = servo_angle_corrected;
frame_pack.iCenterFreq = first_prt_header.freq_no;
% frame_pack.TimeScale = first_prt_header.timer_cnt;        % 时标有问题，先不管
% (可选) 增加一个帧号字段便于调试, C++结构中没有，但MATLAB中很方便
frame_pack.iFrame = first_prt_header.frame_no; 

%% 2. 遍历所有初步检测点，填充 Goal_Para_Frame
num_detections = length(prelim_log);
% 初始化嵌套的目标结构体数组
goal_params(1:num_detections) = struct(...
    'fAmp', 0, 'fSnr', 0, 'fAmuAngle', 0, 'fEleAngle', 0, ...
    'fRange', 0, 'fSpeed', 0, 'fFdA', 0, 'fSpecWidth', 0, 'Goal_Spec', [] ...
);

for i = 1 : num_detections
    current_prelim_detection = prelim_log(i);
    
    % --- 准备参数测量所需的数据 ---
    beam_pair_idx = current_prelim_detection.beam_pair_index;
    slice_idx = current_prelim_detection.slice_index;
    RDM_beam1 = squeeze(mtd_results{beam_pair_idx}(slice_idx, :, :));
    RDM_beam2 = squeeze(mtd_results{beam_pair_idx + 1}(slice_idx, :, :));
    RDM_sum_amp = abs(RDM_beam1) + abs(RDM_beam2);
    
    % --- 调用参数测量引擎 ---
    k_value = fun_get_k_value(config, frame_pack.iCenterFreq, beam_pair_idx);
    estimated_params = fun_parameter_estimation(current_prelim_detection, RDM_sum_amp, k_value, config);
    
    % --- 将精确结果存入嵌套的结构体数组 ---
    goal_params(i).fAmp = estimated_params.snr;                % 使用和信号幅度作为fAmp
    goal_params(i).fSnr = estimated_params.snr;                % 也可以用snr
    goal_params(i).fAmuAngle = frame_pack.iAntAngle;      % 假设方位角与天线指向相同
    goal_params(i).fEleAngle = estimated_params.elevation_deg;
    goal_params(i).fRange = estimated_params.range_m;
    goal_params(i).fSpeed = estimated_params.velocity_ms;
    % 其他字段使用占位符
    goal_params(i).fFdA = 0;
    goal_params(i).fSpecWidth = 0;
    goal_params(i).Goal_Spec = [];                             % 结果在转化为bin文件时需要添加谱数据
end

% --- 将填充好的目标列表赋值给 frame_pack 并更新目标数 ---
frame_pack.Goal_Para_Frame = goal_params;
frame_pack.iGoalNum = num_detections;

fprintf('  > 已完成 %d 个目标的精确参数测量。\n', num_detections);
fprintf('--- STAGE 4: 参数测量完成 ---\n\n');
end