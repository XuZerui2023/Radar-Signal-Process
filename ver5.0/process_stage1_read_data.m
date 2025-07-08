function [iq_data, servo_angle, frame_headers, success, is_end] = process_stage1_read_data(frame_to_read, config, DBF_coeffs_C)
% PROCESS_STAGE1_READ_DATA - 从二进制文件流中读取并解析单个数据帧
%
% 本函数是原 bin_to_mat_xzr.m 脚本的功能化改造版本。包装器
% 它负责调用底层的读取和解析函数，处理单个逻辑数据帧。
% 它的职责是单一的：读取一帧数据并返回结果，而不关心循环或文件保存。
%
% 输入参数:
%   frame_to_read   - (double) 需要处理的逻辑帧编号 (从0开始)。
%   config          - (struct) 包含所有配置参数的结构体。
%                     需要包含: .raw_data_path, .Sig_Config
%   DBF_coeffs_C    - (complex matrix) 预加载的DBF加权系数。
%
% 输出参数:
%   iq_data         - (complex 3D matrix) 处理后的一帧I/Q数据 (prtNum x point_PRT x beam_num)。
%   servo_angle     - (double vector) 与iq_data对应的伺服角度序列。
%   success         - (logical) 标志位，如果该帧被成功且完整地读取，则为 true。
%   is_end          - (logical) 标志位，如果底层数据流已结束，则为 true。
%
%  修改记录
%  date       by      version   modify
%  25/06/25   XZR      v1.0      创建

%% 1. 从config结构体中获取所需参数
% 这种方式使得函数本身不包含任何硬编码的配置，更加通用。
orgDataFilePath = config.raw_data_path;
Sig_Config = config.Sig_Config;

%% 2. 调用核心帧读取与解析函数
% FrameDataRead_xzr 是真正干活的函数，它负责处理所有复杂的逻辑，
% 包括调用 read_continuous_file_stream 来跨文件获取字节流。
% 我们只是将调用它的指令封装在这个更高层的函数中。
fprintf('  > 正在从.bin文件流中读取第 %d 帧...\n', frame_to_read);
[iq_data,servo_angle,frame_headers,frameCompleted,is_global_stream_end] = FrameDataRead_xzr(orgDataFilePath, DBF_coeffs_C, Sig_Config, frame_to_read);

%% 3. 设置输出状态标志
% 将底层函数返回的状态，转换为本函数的输出状态。
success = frameCompleted;
is_end = is_global_stream_end;

%% 4. 根据处理结果在命令行给出反馈
if success
    fprintf('  > 第 %d 帧成功读取。\n', frame_to_read);
else
    % 如果读取失败，给出警告，并指明是否是因为数据流已结束。
    warning('未能完整读取第 %d 帧。', frame_to_read);
    if is_end
        fprintf('  > 数据流已在尝试读取第 %d 帧时结束。\n', frame_to_read);
    end
end

end