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

% 修改记录
% date       by      version   modify
% 25/06/09   XZR      v1.0    调用下层函数实现跨文件处理
% 25/06/27   XZR      V2.0    只提取原始信号IQ数据和伺服角用于数据溢出分析
% 未来改进：

function [raw_iq_data, servo_angle, frame_headers, frameCompleted, is_global_stream_end] = FrameDataRead_xzr_raw_iq(orgDataFilePath, config, frameRInd)

% 初始化参数
    % 持久化变量，用于在函数调用之间保持状态（仅用于帧内PRT计数和帧切换逻辑）
    persistent current_prt;                  % 当前帧中已处理的PRT数量
    persistent last_frameRInd;               % 上一次处理的逻辑帧编号


    % 基础参数设置（由实际采样的雷达体制和信号特征决定）
    MHz = 1e6;                                                     % 定义MHz单位
    cj = sqrt(-1);                                                 % 定义虚数单位
    fs = config.Sig_Config.fs;                                     % 采样率
    timer_freq = config.Sig_Config.timer_freq;                     % 时标计数频率
    prtNum = config.Sig_Config.prtNum;                             % 每帧信号的prt数目
    point_PRT = config.Sig_Config.point_PRT;                       % 定义每个PRT中的采样点数
    channel_num = config.Sig_Config.channel_num;                   % 通道数（相元数目）
    beam_num = config.Sig_Config.beam_num;                         % 波束数
    bytesFrameHead = config.Sig_Config.bytesFrameHead;             % 每个PRT帧头字节数
    bytesFrameEnd = config.Sig_Config.bytesFrameEnd;               % 每个PRT帧尾字节数
    bytesFrameRealtime = config.Sig_Config.bytesFrameRealtime;     % 实时参数的字节数


    % 初始化输出
    raw_iq_data = complex(zeros(prtNum, point_PRT, channel_num));  % 初始化的信号原始IQ数据矩阵
    servo_angle = zeros(1,prtNum,'double');                 % 初始化伺服方位角序列向量
    frameCompleted = false;                                 % 默认帧未完成
    is_global_stream_end = false;                           % 默认数据流未结束

    % 初始化用于存储帧头信息的结构体数组
    % 定义一个模板，包含所有需要保存的帧头字段
    header_template = struct('frame_no', 0, 'pulse_no', 0, 'freq_no', 0, ...
        'channel_num', 0, 'servo_angle', 0, 'pulse_data_num', 0, ...
        'data_type', 0, 'pulse_num', 0, 'radar_type', 0, ...
        'timer_cnt', uint64(0), 's_pluse_dots', 0, 'm_pluse_dots', 0, 'l_pluse_dots', 0 ...
        );
   
    % 使用模板预分配整个结构体数组，提高效率
    frame_headers(1:prtNum) = header_template;

    % 首次调用或新的逻辑帧开始时重置状态
    if isempty(current_prt) || isempty(last_frameRInd) || last_frameRInd ~= frameRInd
        current_prt = 0; % 从帧的第一个PRT开始
        last_frameRInd = frameRInd;
    end

% 信号处理部分
    % 循环读取当前帧的PRT，直到读完所有prtNum个PRT或遇到数据流结束
    while current_prt < prtNum
        % 打印当前处理的逻辑帧和PRT索引
        fprintf('FrameDataRead_xzr: 正在处理逻辑帧 %d 的第 %d 个PRT。\n', frameRInd, current_prt + 1);

    % 1. 读取帧头信息
        [datahead_raw_bytes, actual_len_head, is_stream_end_head] = read_continuous_file_stream(bytesFrameHead, orgDataFilePath);
        if is_stream_end_head || actual_len_head < bytesFrameHead
            warning('FrameDataRead_xzr: PRT帧头在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true; % 标记底层数据流已结束
            return; % 帧未完成，返回当前已处理部分，结束该子函数
        end
        
        % 底层数据格式为uint8，然后在上层函数调用时根据需要再转换为特定的数据类型
        datahead = typecast(datahead_raw_bytes, 'uint32');   % 不改变底层二进制数据情况下，将原始字节数据转换为无符号32位整数（uint32）类型，符合对帧头数据的定义

        % 解析所有帧头信息并存入结构体 ---
        current_prt_index = current_prt + 1;                                                  % current_prt 是从零开始计数的
        frame_headers(current_prt_index).frame_no = datahead(1);                              % 帧号，迭代的最后一个prt对应的帧（从0开始），第1-4字节
        frame_headers(current_prt_index).pulse_no = mod(datahead(3),2^16);                    % PRT号（9-12字节），一个完整帧的PRT是0-331，取余（保留低16位即9-10字节）
        frame_headers(current_prt_index).freq_no = datahead(3)/2^16;                          % 频点号，将9-12字节内容向右平移16位（第11-12字节）
        frame_headers(current_prt_index).channel_num = mod(datahead(4),2^8);                  % 通道数，取余保留低8位(第13字节)
        frame_headers(current_prt_index).current_servo_angle = mod(datahead(5),2^16);         % 伺服方位角，单位0.1°（第17-18字节），这个数组是否是后面所需的角编码？
        frame_headers(current_prt_index).pulse_data_num = datahead(7);                        % 一个PRT采样点数（第25-28字节）
        frame_headers(current_prt_index).data_type = mod(datahead(8),2^8);                    % 数据类型,0=ADC数据,1=DDC数据;2=DBF数据 （第29字节）
        frame_headers(current_prt_index).pulse_num = mod(floor(datahead(8)/2^8),2^16);        % 一帧PRT个数（30-31字节）
        frame_headers(current_prt_index).radar_type = mod(floor(datahead(8)/2^24),2^8);       % 雷达型号，0-X3D3K，1-C3D5K，2-X3D8K，3-C3D8K，4-KuP4K（第32字节）
        frame_headers(current_prt_index).timer_cnt = datahead(9) + datahead(10)*2^32;         % 时标（第33-36字节作为低32位 + 第37-40字节作为高32位）
        frame_headers(current_prt_index).s_pluse_dots = mod(datahead(11),2^16);               % 短脉冲采样点数（第41-42字节）
        frame_headers(current_prt_index).m_pluse_dots = mod(floor(datahead(11)/2^16),2^16);   % 中脉冲采样点数（第43-44字节）
        frame_headers(current_prt_index).l_pluse_dots = mod(datahead(12),2^16);               % 长脉冲采样点数（第45-46字节）

        % 从结构体中获取当前PRT的关键信息用于后续处理
        pulse_data_num = frame_headers(current_prt_index).pulse_data_num;
        data_type = frame_headers(current_prt_index).data_type;
        current_servo_angle = frame_headers(current_prt_index).current_servo_angle;
        radar_type = frame_headers(current_prt_index).radar_type;                             

        
        % 验证 pulse_data_num 的有效性
        if pulse_data_num <= 0
            warning('FrameDataRead_xzr: Invalid pulse_data_num (%d) read from frame head for frame %d, PRT %d. Treating as corrupted PRT.', pulse_data_num, frameRInd, current_prt + 1);
            is_global_stream_end = true; % 视为数据异常，可能导致后续读取失败，标记为数据流结束
            return; % 帧未完成，返回当前已处理部分
        end

    % 2. 读取（辅助数据）实时参数
        [aux_data_raw, actual_len_aux, is_stream_end_aux] = read_continuous_file_stream(bytesFrameRealtime, orgDataFilePath);
        if is_stream_end_aux || actual_len_aux < bytesFrameRealtime
            warning('FrameDataRead_xzr: PRT辅助数据在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end

    % 3. 信号数据大小计算（一个PRT信号字节数）
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
        if mod(sig_data_size,64) > 0                   % DBF数据有补零
            pad_size = (64-mod(sig_data_size,64));     % 补零数据量，FPGA中将信号数据补为64Byte整数倍
        end
        pulse_data_size = sig_data_size + pad_size;    % 一个PRT信号数据大小，含补零数据,单位Byte
 
    % 4. 读取信号数据 
        [signal_data_raw, actual_len_signal, is_stream_end_signal] = read_continuous_file_stream(pulse_data_size, orgDataFilePath);
        if is_stream_end_signal || actual_len_signal < pulse_data_size
            warning('FrameDataRead_xzr: PRT信号数据在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end
        
        pulse_data_parsed = [];
        if data_type == 2      % DBF数据，无符号整数转换为24位有符号整数（二进制补码表示） 这段有些问题，还没有修改！！！！！
            data_uint8_signal = signal_data_raw;
            data_temp = reshape(data_uint8_signal(1:end-pad_size),channel_num*2*3+one_sample_pad,[]).';
            pulse_data_parsed = data_temp(:,1:3:end-3)+data_temp(:,2:3:end-2)*2^8+data_temp(:,3:3:end)*2^16;
            negative_index = find(pulse_data_parsed>2^23);
            pulse_data_parsed(negative_index) = pulse_data_parsed(negative_index)-2^24;
       
        else  % ADC数据 或 DDC数据
            pulse_data_parsed = typecast(signal_data_raw, 'int16');        % 转换为有符号整型16位（2字节）数据，符合信号数据格式
        end

    % 5. 解析信号数据，计算信号相位叠加所成的波束
        current_sig_data_DBF = complex(zeros(point_PRT, beam_num)); % 初始化当前PRT的DBF数据
        switch data_type
            case 0 % ADC数据
                sig_data = pulse_data_parsed(1:pulse_data_num*channel_num);              % 去掉可能的块尾部补零数据
                sig_data = reshape(sig_data,channel_num,[]).';                           % 分通道，重塑为一个二维矩阵
                current_sig_data_DBF = sig_data;                                         % 暂时将ADC数据本身作为输出

            case 1 % DDC数据处理（已修改，使用正确）
                sig_data = pulse_data_parsed(1: pulse_data_num * channel_num * 2);       % 去掉可能的块尾部补零数据
                sig_data = reshape(sig_data,channel_num*2,[]).';                         % 分通道，将一维的 sig_data 重塑为一个二维矩阵。矩阵每行代表一个采样点，每列代表一个通道IQ数据
                sig_data = double(sig_data);

                sig_data_I = sig_data(:, 1:2:end);                                       % 分离IQ分量，提取所有行的奇数列（代表所有通道的I分量）
                sig_data_Q = sig_data(:, 2:2:end);                                       % 分离IQ分量，提取所有行的偶数列（代表所有通道的Q分量）
                sig_data_C = sig_data_I + sig_data_Q * cj;                               % 转换为复数矩阵，每一列代表一个通道的复数基带信号 (I + jQ)

                %current_sig_data_DBF = sig_data_C * DBF_coeffs_data_C.';                 % DBF系数加权后信号数据 = 原复信号(3404*16) * DBF系数矩阵(16*13)（非共轭转置），DBF权重系数是否已经取过共轭？
                %sig_data_DBF_I = real(sig_data_DBF);                                    % DBF系数加权后信号数据实部（大小为：pulse_data_num * beam_num）
                %sig_data_DBF_Q = imag(sig_data_DBF);                                    % DBF系数加权后信号数据虚部（大小为：pulse_data_num * beam_num）
            
            case 2 %DBF数据
                sig_data_C = pulse_data_parsed(:,1:2:end) + cj * pulse_data_parsed(:,2:2:end);
                current_sig_data_DBF = sig_data_C;
        end
        
        % 检查读取到的PRT数据尺寸是否符合预期
        % 这里使用 size(current_sig_data_DBF,1) 而不是 pulse_data_num 
        % 因为 reshape 可能会在 pulse_data_num 为0时导致意想不到的尺寸，
        % 虽然前面已经对 pulse_data_num 做了检查，这里再次确认输出矩阵的维度
        if size(current_sig_data_DBF, 1) ~= point_PRT || size(current_sig_data_DBF, 2) ~= beam_num
            warning('FrameDataRead_xzr: 处理后的PRT数据尺寸与预期不符（帧 %d，PRT %d）。预期尺寸: %dx%d, 实际尺寸: %dx%d。', ...
                frameRInd, current_prt + 1, point_PRT, beam_num, size(current_sig_data_DBF, 1), size(current_sig_data_DBF, 2));
            is_global_stream_end = true; % 视为数据异常，标记为数据流结束
            return; % 帧未完成，返回当前已处理部分
        end

        % 将当前PRT的数据存入总的帧数据矩阵
        current_prt = current_prt + 1;                                     % current_prt 初始值为0，迭代下一个prt
        % sig_data_DBF_allprts(current_prt, :, :) = current_sig_data_DBF;  % 转置为 (pulse_data_num x beam_num) % 三维数组存储一帧信号中所有PRT的13波束的所有采样点信号数据
        raw_iq_data(current_prt,:,:) = sig_data_C;
        servo_angle(current_prt) = current_servo_angle;                    % 保存每帧信号所有prt的伺服方位角

    % 6. 读取帧尾数据
        [~, actual_len_tail, is_stream_end_tail] = read_continuous_file_stream(bytesFrameEnd, orgDataFilePath);
        if is_stream_end_tail || actual_len_tail < bytesFrameEnd
            warning('FrameDataRead_xzr: PRT帧尾在数据流末尾被截断或数据已尽。帧 %d 未完成。', frameRInd);
            is_global_stream_end = true;
            return; % 帧未完成，返回当前已处理部分
        end

    % 7. 判断DDC抽取倍数（画频谱图需要）
        if radar_type==4  % KuP4K雷达
            DDC_M = 2;
        else
            DDC_M = 4;    % X3D3K、C3D5K、X3D8K和C3D8K雷达
        end
    
    end

    % 如果循环完成，表示当前帧的所有PRT都已成功读取
    frameCompleted = true;
    is_global_stream_end = false; % 帧完成，且数据流没有结束

end
