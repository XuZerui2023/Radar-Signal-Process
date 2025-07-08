function [mtd_results, angles_wins] = process_stage2_mtd(iq_data_now, iq_data_next, angle1, angle2, config)
% PROCESS_STAGE2_MTD - 对输入的I/Q数据执行MTD处理
%
% 本函数是原 main_produce_dataset_win_xzr_v2.m 脚本的功能化改造版本。
% 它接收两个连续的数据帧，进行拼接和窗口化，然后对每个切片执行
% 完整的MTD处理流程。
%
% 输入参数:
%   iq_data_now  - (complex 3D matrix) 当前帧的I/Q数据。
%   iq_data_next - (complex 3D matrix) 下一帧的I/Q数据。
%   config       - (struct) 包含所有MTD处理参数的配置结构体。
%
% 输出参数:
%   mtd_results  - (cell) MTD处理结果。每个单元格包含一个波束的所有切片结果。

%% 1. 从config结构体中获取参数
beam_num = config.mtd.beam_num;
win_size = config.mtd.win_size;
% 将核心的雷达系统参数打包，传递给下一层函数
params_for_produce = config.Sig_Config; 
% params_for_produce.debug = config.debug; % 传递调试开关

%% 2. 拼接数据帧以提高速度分辨率
% 拼接信号数据
echo_win_beams = cell(beam_num, 1);
for b = 1:beam_num
    echo_now_beam_data = squeeze(iq_data_now(:, :, b));
    echo_next_beam_data = squeeze(iq_data_next(:, :, b));
    % 沿慢时间维（行）拼接，形成一个更长的信号窗口
    echo_win_beams{b} = [echo_now_beam_data; echo_next_beam_data];
end

% 拼接角度数据
echo_now_servo_angle = angle1;
echo_next_servo_angle = angle2;
servo_angle_win = [echo_now_servo_angle, echo_next_servo_angle];

%% 3. 对所有波束和切片进行MTD处理
mtd_results = cell(beam_num, 1); % 初始化用于保存最终结果的Cell数组

% --- 波束循环 ---
for b = 1:beam_num
    current_beam_echo_win = echo_win_beams{b};
    [total_prts, ~] = size(current_beam_echo_win);
    prts_per_slice = total_prts / 2;
    
    MTD_data_for_one_beam = []; % 初始化临时变量

    % --- 切片循环 ---
    for i = 0:(win_size - 1)
        start_row = round(i * prts_per_slice / win_size) + 1;
        end_row = start_row + prts_per_slice - 1;
        if end_row > total_prts, continue; end

        echo_segment = current_beam_echo_win(start_row:end_row, :);
        
        % --- 调用核心MTD处理链函数 ---
        % 注意：这里 fun_MTD_produce 也需要被相应修改，以接收params结构体
        MTD_result = fun_MTD_produce(echo_segment, params_for_produce);
        
        MTD_data_for_one_beam(i+1, :, :) = MTD_result;
    end
    
    mtd_results{b} = MTD_data_for_one_beam;
end

%% 4. 角度信息拼接
% 如果需要，也可以保存窗口化的角度信息
angles_wins = [];
prts_per_slice_angle = length(servo_angle_win) / 2;
for i = 0:(win_size - 1)
    start_idx = round(i * prts_per_slice_angle / win_size) + 1;
    end_idx = start_idx + prts_per_slice_angle - 1;
    angles_wins(i+1, :) = servo_angle_win(start_idx:end_idx);
end

fprintf('  > MTD处理完成。\n');


end
