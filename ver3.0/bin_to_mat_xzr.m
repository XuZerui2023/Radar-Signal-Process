% 此文件用于读取雷达数据，将二进制bin文件格式转换为MATLAB的mat文件格式，并依据雷达信号格式读取其中的帧头帧尾信号数据
% 调用了 frameDataRead_A_xzr_V2.m 函数 (该函数内部调用 read_continuous_file_stream.m 进行跨文件读取)

% 修改记录
% date       by      version   modify
% 25/05/28   XZR      v2.0       修改1
% 25/06/04   XZR      v3.0       重构以实现跨文件读取功能（通过持久化状态）
% 25/06/05   XZR      v4.0       修改为所有bin文件首尾相连处理（内存拼接）一起处理
% 25/06/09   XZR      v5.0       改回跨文件处理，封装为 read_continuous_file_stream 模拟 C++ 逻辑
% 未来改进：文件读取可以写成APP，弹出框选择文件夹路径


clc;clear; close all;

% 在脚本开始时清除所有相关函数的持久化状态，确保每次运行都从头开始
clear read_continuous_file_stream;  % 清除 read_continuous_file_stream 的持久化状态（持久性变量）
clear frameDataRead_A_xzr_V2;       % 清除 frameDataRead_A_xzr_V2 的持久化状态（持久性变量）
clear manage_retry_count;           % 清除 manage_retry_count 的持久化状态（持久性变量）

%% 从给定文本文件中读入DBF系数
% 注意文件中分隔符只能使用逗号或空格，每行是一个数据，不要加分号
try
    DBF_coeffs_data = readmatrix("D:\MATLAB_Project\MatlabProcess_xuzerui_latest\DBF_data\X8数据采集250522_DBFcoef.txt");  % 示例："X8数据采集250522_DBFcoef.txt"
catch ME
    error(['读入DBF系数文件失败。请确认文件路径正确，且文件数据为逗号分隔格式。错误信息: ', ME.message]);
end
DBF_coeffs_data_I = double(DBF_coeffs_data( :, 1:2:end));
DBF_coeffs_data_Q = double(DBF_coeffs_data( :, 2:2:end));
DBF_coeffs_data_C = DBF_coeffs_data_I + sqrt(-1) * DBF_coeffs_data_Q;


%% 基础参数设置（由实际采样的雷达体制和信号特征决定）
% 参数
MHz = 1e6;                                           % 定义MHz单位
Sig_Config = struct('fs', 100*MHz,              ...  % 采样率 
                    'timer_freq', 200*MHz,      ...  % 时标计数频率
                    'prtNum', 332,              ...  % 定义每帧信号的脉冲数，每帧信号包含 332 个脉冲
                    'point_PRT', 3404,          ...  % 定义每个PRT中的采样点数（时间轴）
                    'channel_num', 16,          ...  % 通道数（阵元数目）
                    'beam_num', 13,             ...  % 波束数
                    'bytesFrameHead', 64,       ...  % 每个PRT帧头字节数
                    'bytesFrameEnd', 64,        ...  % 每个PRT帧尾字节数
                    'bytesFrameRealtime', 128);      % 实时参数的字节数

% 读写路径
n_exp = 2;        % 该文件夹编号
orgDataFilePath = ['D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\1\2025年05月22日17时16分14秒'];   % 设置原始数据文件（bin文件）的位置
mkdir(['D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\', num2str(n_exp),'\BasebandRawData_mat']);  % 新建一个文件夹，用于存储转换后的mat文件
outputMatDir = ['D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\', num2str(n_exp),'\BasebandRawData_mat']; % 定义存储 mat文件的地址


%% 信号处理部分
tic;
frameRInd = 0; % 从第0帧开始处理
max_frames_to_process = 30; % 要处理的总的帧数，可以根据实际数据量调整

while frameRInd <= max_frames_to_process
    fprintf('bin_to_mat_xzr: 尝试处理逻辑帧 %d\n', frameRInd);
    
    %  调用 frameDataRead_A_xzr_V2 来读取一帧数据
    %  frameDataRead_A_xzr_V2 内部会调用 read_continuous_file_stream 来获取字节流
    [sig_data_DBF_allprts, servo_angle, frameCompleted, is_global_stream_end] = FrameDataRead_xzr(orgDataFilePath, DBF_coeffs_data_C, Sig_Config, frameRInd);
    
    if frameCompleted
        % 如果帧已完成，保存数据并处理下一帧
        save(fullfile(outputMatDir, ['frame_',num2str(frameRInd),'.mat']),'sig_data_DBF_allprts','servo_angle');
        disp(['已处理并保存第',num2str(frameRInd),'帧。']);
        frameRInd = frameRInd + 1; % 移动到下一帧
        manage_retry_count('reset'); % 成功处理一帧后重置重试计数
    else
        % 如果帧未完成（因为最后数据流末尾截断或无效PRT），
        warning('bin_to_mat_xzr: 帧 %d 未能完整读取。', frameRInd);
        
        if is_global_stream_end
            % 如果底层数据流已经结束，则无法继续处理更多帧
            fprintf('bin_to_mat_xzr: 已到达所有数据流的末尾，停止处理。\n');
            break; % 退出主循环
        else
            % 如果数据流未结束，但当前帧未完成，可能是数据格式问题或临时截断，尝试重试当前帧
            % frameRInd 不变，循环会再次尝试读取同一逻辑帧。
            current_retry_count = manage_retry_count('increment');
            if current_retry_count > 1000 % 连续尝试1000次同一帧，可能数据有问题
                error('bin_to_mat_xzr: 连续尝试读取同一帧 %d 失败次数过多，可能数据文件损坏或逻辑错误。', frameRInd);
            end
        end
    end
    
end
disp(toc);
disp('所有帧处理完成。');
