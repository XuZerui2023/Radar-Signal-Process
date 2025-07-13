function final_log = process_stage4_measurement(prelim_log, config, frame_headers)
% PROCESS_STAGE4_MEASUREMENT - 参数测量阶段 (处理流程第四阶段)
%
% 本函数是信号处理流程的最后一站。它负责对第三阶段输出的"初步检测日志"
% 进行精细化处理，计算出每个目标的精确物理参数。
%
% 输入参数:
%   prelim_log    - (struct array) 由第三阶段生成的初步检测日志。
%   config        - (struct) 全局配置结构体。
%   frame_headers - (struct array) 当前帧的帧头信息，用于获取频点号。
%
% 输出:
%   final_log     - (struct array) 包含最终精确参数的日志。
%
%  修改记录
%  date       by      version   modify
%  25/07/12   XZR      v1.0      创建

%% 1. 初始化
fprintf('--- STAGE 4: 参数测量开始 ---\n');
if isempty(prelim_log)
    fprintf('  > 初步检测日志为空，无需测量。跳过此阶段。\n');
    final_log = []; % 如果没有初步检测点，直接返回空日志
    return;
end

% 初始化最终日志结构体
final_log = struct(...
    'frame', {}, 'slice', {}, 'beam_pair', {}, ...
    'range_m', {}, 'velocity_ms', {}, ...
    'elevation_deg', {}, 'height_m', {}, 'snr', {} ...
);

% 从帧头中获取当前帧的频点号 (假设所有PRT的频点号都相同)
freInd = frame_headers(1).freq_no; 

%% 2. 遍历所有初步检测点
num_detections = length(prelim_log);
final_detections(1:num_detections) = struct(...
    'frame', 0, 'slice', 0, 'beam_pair', 0, ...
    'range_m', 0, 'velocity_ms', 0, ...
    'elevation_deg', 0, 'height_m', 0, 'snr', 0 ...
);

for i = 1:num_detections
    % 获取当前处理的初步检测点
    current_prelim_detection = prelim_log(i);
    
    % --- 步骤1: 获取对应的K值 ---
    beam_pair_idx = current_prelim_detection.beam_pair_index;
    k_value = fun_get_k_value(config, freInd, beam_pair_idx);
    
    % --- 步骤2: 调用参数测量引擎进行计算 ---
    estimated_params = fun_parameter_estimation(current_prelim_detection, k_value, config);
    
    % --- 步骤3: 将精确结果存入最终日志 ---
    final_detections(i).frame = current_prelim_detection.frame_index;
    final_detections(i).slice = current_prelim_detection.slice_index;
    final_detections(i).beam_pair = beam_pair_idx;
    final_detections(i).range_m = estimated_params.range_m;
    final_detections(i).velocity_ms = estimated_params.velocity_ms;
    final_detections(i).elevation_deg = estimated_params.elevation_deg;
    final_detections(i).height_m = estimated_params.height_m;
    final_detections(i).snr = estimated_params.snr;
end

final_log = final_detections;

fprintf('  > 已完成 %d 个目标的精确参数测量。\n', num_detections);
fprintf('--- STAGE 4: 参数测量完成 ---\n\n');

end
