%% 功能：从二进制bin文件中读取回波信号数据中一帧的数据, 有角码
%   此函数现在通过调用 read_continuous_file_stream.m 从连续文件流中读取数据。
% 输入：
%     orgDataFilePath：基带原始数据文件夹位置（传递给 read_continuous_file_stream）。
%     DBF_coeffs_data_C：加权DBF参数，用于DDC信号中。
%     frameRInd：需要处理的帧编号 (此参数现在主要用于逻辑标识和警告信息)。
%     prtNum：每帧信号数据包含的prt数目。
%
% 输出：
%     sig_data_DBF_allprts: 一帧所有PRT的DBF处理后信号数据。
%     servo_angle: 一帧所有PRT的伺服方位角。
%     frameCompleted: 逻辑值，如果当前帧的所有PRT都已成功读取，则为 true。
%     is_global_stream_end: 逻辑值，如果底层数据流已结束，则为 true。

function [sig_data_DBF_allprts, servo_angle, frameCompleted, is_global_stream_end] = frameDataRead_A_xzr_V2(orgDataFilePath, DBF_coeffs_data_C, Sig_Config, frameRInd)

% 初始化参数
    % 持久化变量，用于在函数调用之间保持状态（仅用于帧内PRT计数和帧切换逻辑）
    persistent current_prt_index_in_frame;                  % 当前帧中已处理的PRT数量
    persistent last_frameRInd_processed;                    % 上一次处理的逻辑帧编号


    % 基础参数设置（由实际采样的雷达体制和信号特征决定）
    MHz = 1e6;                                              % 定义MHz单位
    cj = sqrt(-1);                                          % 定义虚数单位
    fs = Sig_Config.fs;                                     % 采样率
    timer_freq = Sig_Config.timer_freq;                     % 时标计数频率
    prtNum = Sig_Config.prtNum;                             % 每帧信号的prt数目
    point_PRT = Sig_Config.point_PRT;                       % 定义每个PRT中的采样点数
    channel_num = Sig_Config.channel_num;                   % 通道数（相元数目）
    beam_num = Sig_Config.beam_num;                         % 波束数
    bytesFrameHead = Sig_Config.bytesFrameHead;             % 每个PRT帧头字节数
    bytesFrameEnd = Sig_Config.bytesFrameEnd;               % 每个PRT帧尾字节数
    bytesFrameRealtime = Sig_Config.bytesFrameRealtime;     % 实时参数的字节数


    % 初始化输出
    sig_data_DBF_allprts = complex(zeros(prtNum, point_PRT, beam_num)); % 初始化多波束一帧（所有PRT）的信号数据矩阵
    servo_angle = zeros(1,prtNum,'double');                             % 初始化伺服方位角序列向量
    frameCompleted = false;                                             % 默认帧未完成
    is_global_stream_end = false;                                       % 默认数据流未结束

    % 首次调用或新的逻辑帧开始时重置状态
    if isempty(current_prt_index_in_frame) || isempty(last_frameRInd_processed) || last_frameRInd_processed ~= frameRInd
        current_prt_index_in_frame = 0; % 从帧的第一个PRT开始
        last_frameRInd_processed = frameRInd;
    end


% 信号处理部分
    % 循环读取当前帧的PRT，直到读完所有prtNum个PRT或遇到数据流结束
    while current_prt_index_in_frame < prtNum
        % 打印当前处理的逻辑帧和PRT索引
        fprintf('frameDataRead_A_xzr_V2: 正在处理逻辑帧 %d 的第 %d 个PRT。\n', frameRInd, current_prt_index_in_frame + 1);

        % ----------------------- 1. 读取帧头信息 --------------------------
        [datahead_raw_bytes, actual_len_head, is_stream_end_head] = read_continuous_file_stream(bytesFrameHead, orgDataFilePath);
        if is_stream_end_head || actual_len_head < bytesFrameHead
            warning('frameDataRead_A_xzr_V2: PRT帧头在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true; % 标记底层数据流已结束
            return; % 帧未完成，返回当前已处理部分
        end
        datahead = typecast(datahead_raw_bytes, 'uint32');

        % 从帧头中解析信息
        current_servo_angle = mod(datahead(5),2^16); % 伺服方位角
        pulse_data_num = datahead(7); % 一个PRT采样点数
        data_type = mod(datahead(8),2^8); % 数据类型

        % 验证 pulse_data_num 的有效性
        if pulse_data_num <= 0
            warning('frameDataRead_A_xzr_V2: Invalid pulse_data_num (%d) read from frame head for frame %d, PRT %d. Treating as corrupted PRT.', pulse_data_num, frameRInd, current_prt_index_in_frame + 1);
            is_global_stream_end = true; % 视为数据异常，可能导致后续读取失败，标记为数据流结束
            return; % 帧未完成，返回当前已处理部分
        end

        % ------------------- 2. 读取（辅助数据）实时参数 -------------------
        [aux_data_raw, actual_len_aux, is_stream_end_aux] = read_continuous_file_stream(bytesFrameRealtime, orgDataFilePath);
        if is_stream_end_aux || actual_len_aux < bytesFrameRealtime
            warning('frameDataRead_A_xzr_V2: PRT辅助数据在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end

        % ---------------------- 3. 信号数据大小计算 -----------------------
        sig_data_size = 0;
        if data_type == 0       % ADC数据
            sig_data_size = pulse_data_num * channel_num * 2;
        elseif data_type == 1   % DDC数据
            sig_data_size = pulse_data_num * channel_num * 2 * 2;
        else                    % DBF数据
            one_sample_pad = 8-mod(6*channel_num,8);
            sig_data_size = pulse_data_num * channel_num * 2 * 3 + pulse_data_num * one_sample_pad;
        end
        
        pad_size = 0;
        if mod(sig_data_size,64) > 0
            pad_size = (64-mod(sig_data_size,64));
        end
        pulse_data_size = sig_data_size + pad_size;

        % ------------------------ 4. 读取信号数据 -------------------------
        [signal_data_raw, actual_len_signal, is_stream_end_signal] = read_continuous_file_stream(pulse_data_size, orgDataFilePath);
        if is_stream_end_signal || actual_len_signal < pulse_data_size
            warning('frameDataRead_A_xzr_V2: PRT信号数据在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end
        
        pulse_data_parsed = [];
        if data_type == 2   % DBF数据
            data_uint8_signal = signal_data_raw;
            data_temp = reshape(data_uint8_signal(1:end-pad_size),channel_num*2*3+one_sample_pad,[]).';
            pulse_data_parsed = data_temp(:,1:3:end-3)+data_temp(:,2:3:end-2)*2^8+data_temp(:,3:3:end)*2^16;
            negative_index = find(pulse_data_parsed>2^23);
            pulse_data_parsed(negative_index) = pulse_data_parsed(negative_index)-2^24;
        else  % ADC数据 或 DDC数据
            pulse_data_parsed = typecast(signal_data_raw, 'int16');
        end

        % ------------ 5. 解析信号数据，计算信号相位叠加所成的波束 ------------
        current_sig_data_DBF = complex(zeros(point_PRT, beam_num)); % 初始化当前PRT的DBF数据
        switch data_type
            case 0 % ADC数据
                sig_data = pulse_data_parsed(1:pulse_data_num*channel_num);
                sig_data = reshape(sig_data,channel_num,[]).';
                current_sig_data_DBF = sig_data; % 暂时将ADC数据本身作为输出

            case 1 % DDC数据处理
                sig_data = pulse_data_parsed(1: pulse_data_num * channel_num * 2);
                sig_data = reshape(sig_data,channel_num*2,[]).';
                
                sig_data_I = sig_data(:, 1:2:end);
                sig_data_Q = sig_data(:, 2:2:end);
                sig_data_C = sig_data_I + sig_data_Q * cj;

                current_sig_data_DBF = sig_data_C * DBF_coeffs_data_C.';
                
            case 2 %DBF数据
                sig_data_C = pulse_data_parsed(:,1:2:end) + cj * pulse_data_parsed(:,2:2:end);
                current_sig_data_DBF = sig_data_C;
        end
        
        % 检查读取到的PRT数据尺寸是否符合预期
        % 这里使用 size(current_sig_data_DBF,1) 而不是 pulse_data_num 
        % 因为 reshape 可能会在 pulse_data_num 为0时导致意想不到的尺寸，
        % 虽然前面已经对 pulse_data_num 做了检查，这里再次确认输出矩阵的维度
        if size(current_sig_data_DBF, 1) ~= point_PRT || size(current_sig_data_DBF, 2) ~= beam_num
            warning('frameDataRead_A_xzr_V2: 处理后的PRT数据尺寸与预期不符（帧 %d，PRT %d）。预期尺寸: %dx%d, 实际尺寸: %dx%d。', ...
                frameRInd, current_prt_index_in_frame + 1, point_PRT, beam_num, size(current_sig_data_DBF, 1), size(current_sig_data_DBF, 2));
            is_global_stream_end = true; % 视为数据异常，标记为数据流结束
            return; % 帧未完成，返回当前已处理部分
        end

        % 将当前PRT的数据存入总的帧数据矩阵
        current_prt_index_in_frame = current_prt_index_in_frame + 1;
        sig_data_DBF_allprts(current_prt_index_in_frame, :, :) = current_sig_data_DBF;
        servo_angle(current_prt_index_in_frame) = current_servo_angle;

        % --- 6. 读取帧尾数据 ---
        [~, actual_len_tail, is_stream_end_tail] = read_continuous_file_stream(bytesFrameEnd, orgDataFilePath);
        if is_stream_end_tail || actual_len_tail < bytesFrameEnd
            warning('frameDataRead_A_xzr_V2: PRT帧尾在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end

        % 7. 判断DDC抽取倍数（画频谱图需要）
        % radar_type 未从帧头解析，这里省略或根据需要添加
        % if radar_type==4  % KuP4K雷达
        %     DDC_M = 2;
        % else
        %     DDC_M = 4;    % X3D3K、C3D5K、X3D8K和C3D8K雷达
        % end
    end

    % 如果循环完成，表示当前帧的所有PRT都已成功读取
    frameCompleted = true;
    is_global_stream_end = false; % 帧完成，且数据流没有结束
end
