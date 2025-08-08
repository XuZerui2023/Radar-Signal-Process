beamdiff_estimation



nums = length(beamdiff_estimation) 
beam_test = struct(...
    'frame', {}, 'slice', {}, 'beam_pair', {}, ...
    'range_m', {}, 'velocity_ms', {}, ...
    'elevation_deg', {}, 'servo_deg_raw', {}, 'height_m', {}, 'snr', {}, ...
    'amp_sum', {}, 'amp_diff', {}, 'k_value', {}, 'k_value_10e4', {} ...
);


final_detections(1:nums) = struct(...
    'frame', 0, 'slice', 0, 'beam_pair', 0, ...
    'range_m', 0, 'velocity_ms', 0, ...
    'elevation_deg', 0, 'servo_deg_raw', 0, 'height_m', 0, 'snr', 0, ...
    'amp_sum', 0, 'amp_diff', 0, 'k_value', 0, 'k_value_10e4', 0 ...
);

for i = 1:nums
    % 获取当前处理的初步检测点
    final_detections(i).frame = beamdiff_estimation.frame_index;
    final_detections(i).slice = beamdiff_estimation.slice_index;
    final_detections(i).beam_pair = beamdiff_estimation.beam_pair_idx;
    final_detections(i).range_m = beamdiff_estimation.range_m;
    final_detections(i).velocity_ms = beamdiff_estimation.velocity_ms;
    final_detections(i).elevation_deg = beamdiff_estimation.elevation_deg;
    final_detections(i).servo_deg_raw = beamdiff_estimation.servo_raw;
    final_detections(i).height_m = beamdiff_estimation.height_m;
    final_detections(i).snr = beamdiff_estimation.snr;
    
    final_detections(i).amp_sum = estimated_params.amp_sum;                      % 使用和信号幅度作为信噪比的近似
    final_detections(i).amp_diff = estimated_params.amp_diff;                    % 使用和信号幅度作为信噪比的近似
    final_detections(i).k_value = k_value;                      % 使用和信号幅度作为信噪比的近似
    % final_detections(i).velocity_ms_10e4 = estimated_params.velocity_ms;                      % 使用和信号幅度作为信噪比的近似
end


beamdiff_estimation_new = beamdiff_estimation;

for i = 1 : length(beamdiff_estimation_new)
    beamdiff_estimation_new(i).velocity_ms = beamdiff_estimation(i).velocity_ms * 10e4;
    beamdiff_estimation_new(i).frame = beamdiff_estimation(i).amp_diff / beamdiff_estimation(i).amp_sum;
end



