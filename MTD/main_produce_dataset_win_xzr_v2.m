% main_produce_dataset_win_xzr_v2.m
% 这是MTD主流程控制脚本
% 该脚本用于处理.mat格式的基带信号数据，通过窗口化处理，为每个波束生成MTD（动目标检测）数据。
%
% 修改记录:
% date       by      version   modify
% 原始版本                     仅硬编码处理两个波束
% 25/06/12   XZR      v1.0    重构代码以循环处理所有13个波束，并统一保存结果。
% 25/06/17   XZR      v2.0    将子函数中硬编码的变量移到主函数
% 未来改进：

clc;clear; close all;

%% 1.主流程控制脚本参数设置
n_exp = 2;         % 实验编号
win_size = 4;      % 处理窗口的切片数量
Total_Frames = 5; % 要处理的总帧数


%% 2.子函数参数设置
% 2.1 控制与调试参数
params.debug.show_PC = 0;
params.debug.show_FFT = 0;
params.debug.graph = 0;      % 只在这里控制是否画图

% 2.2 物理常数
params.c = 2.99792458e8;     % 光速
params.pi = pi;

% 2.3 雷达系统参数 (核心配置)
params.prtNum = 332;         % 每帧信号的脉冲数
params.fs = 25e6;            % 采样频率 (Hz)
params.fc = 9450e6;          % 中心频率 (Hz)
params.prt = 232.76e-6;      % 脉冲重复时间 (s)
params.B = 20e6;             % 带宽 (Hz)
params.tao = [0.16e-6, 8e-6, 28e-6];        % 脉宽 [窄, 中, 长]
params.point_prt = [3404, 228, 723, 2453];  % 采集点数 [总采集点数，窄脉冲采集点数，中脉冲采集点数，长脉冲采集点数]   

beam_num = 13;               % 雷达总波束数量

% 2.4 派生参数计算 (一次性计算)
params.prf = 1 / params.prt;
params.wavelength = params.c / params.fc;   % 信号波长
params.deltaR = params.c / (2 * params.fs); % 距离分辨率由采样率决定


%% 3.路径设置
% 根据您的项目结构修改以下路径
base_path = 'D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\';
mat_data_path = fullfile(base_path, num2str(n_exp), 'BasebandRawData_mat');
output_MTD_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);   % MTD后信号文件存储地址

% 创建存储MTD数据的文件夹
if ~exist(output_MTD_path, 'dir')
    mkdir(output_MTD_path);
end

% 获取所有.mat文件列表
dirOutput = dir(fullfile(mat_data_path, '*.mat'));
if isempty(dirOutput)
    error('在路径 %s 中未找到.mat文件，请检查路径或确认上一阶段已成功生成文件。', mat_data_path);
end
fileNames = {dirOutput.name};

%% 4.主处理循环
tic;
% 循环处理每一帧，注意文件列表从1开始，而逻辑帧号frameRInd从0开始
% 确保处理的帧数不超过文件总数减1（因为需要加载下一帧）
frame_idx = 1; % 测试用
for frame_idx = 1:(min(Total_Frames, numel(fileNames) - 1))
    
    frameRInd = frame_idx - 1; % 当前处理的逻辑帧编号 (从0开始)
    fprintf('开始处理第 %d 帧...\n', frameRInd);
    params.current_frame = frameRInd;
    % --- 4.1 加载当前帧和下一帧的数据 ---
    try 
        echo_now_struct = load(fullfile(mat_data_path, ['frame_', num2str(frameRInd), '.mat']));       % 加载当前帧
        echo_next_struct = load(fullfile(mat_data_path, ['frame_', num2str(frameRInd + 1), '.mat']));  % 加载下一帧
    catch ME
        warning('加载帧 %d 或 %d 失败: %s。跳过此帧。', frameRInd, frameRInd + 1, ME.message);
        continue; % 跳过当前循环
    end

    % --- 4.2 提取并拼接所有波束的数据 ---
    % 拼接两帧数据，增加用于信号处理的相参处理间隔（CPI），从而提高动目标检测（MTD）的速度分辨率
    echo_win_beams = cell(beam_num, 1);
    
    % 检查sig_data_DBF_allprts是否存在
    if ~isfield(echo_now_struct, 'sig_data_DBF_allprts') || ~isfield(echo_next_struct, 'sig_data_DBF_allprts')
        warning('在帧 %d 或 %d 的.mat文件中未找到变量 "sig_data_DBF_allprts"。请检查数据格式。跳过此帧。', frameRInd, frameRInd + 1);
        continue;
    end

    for b = 1:beam_num
        % 从三维矩阵中提取当前波束的数据 (prtNum x point_PRT)
        echo_now_beam_data = squeeze(echo_now_struct.sig_data_DBF_allprts(:, :, b));       % 提取当前帧信号数据
        echo_next_beam_data = squeeze(echo_next_struct.sig_data_DBF_allprts(:, :, b));     % 提取下一帧信号数据

        echo_win_beams{b} = [echo_now_beam_data; echo_next_beam_data]; % 拼接每一个波束的当前帧和下一帧的数据，形成一个更长的信号窗口（按行叠加） 
    end
    
    % 拼接角度数据
    servo_angle_win = [echo_now_struct.servo_angle, echo_next_struct.servo_angle];

    % --- 4.3 对所有波束进行MTD处理 ---
    MTD_win_all_beams = cell(beam_num, 1); % 初始化一个Cell数组来存储所有波束的MTD结果

    % 外层循环，遍历每一个波束
    for b = 1:beam_num
        
        current_beam_echo_win = echo_win_beams{b};     % 获取对应波束拼接好的信号窗口
        
        % 获取当前信号窗口的维度，用于后续切片
        [total_prts, ~] = size(current_beam_echo_win); % 获取拼接后信号prt数量
        prts_per_slice = total_prts / 2;               % 每个原始帧的PRT数量相同

        MTD_data_for_one_beam = [];  % 初始化用于存储当前波束所有窗口切片的MTD结果

        % 内层循环，将长窗口切片并进行MTD处理
        for i = 0:(win_size - 1)
            
            % 计算切片的起始和结束行索引
            start_row = round(i * prts_per_slice / win_size) + 1;
            end_row = start_row + prts_per_slice - 1;
            
            % 确保索引不越界
            if end_row > total_prts
                warning('窗口切片索引超出范围，请检查win_size和PRT数量。');
                continue;
            end

            % 从当前波束（b）的信号窗口中切割出子窗口
            echo_segment = current_beam_echo_win(start_row:end_row, :);
            
            % 调用函数计算信号的MTD
            MTD_result = fun_MTD_produce(echo_segment,params);   % 一共调用 beam_num * win_size（13*4）次
            
            % 从MTD结果中提取特定的行数据（速度区间）
            MTD_result = MTD_result( : , : ); % 可以调整行的取值范围，从而取出特定速度区间
            
            % 将当前子窗口的MTD结果存入临时矩阵
            % MTD处理后MTD_data_for_one_beam数组维度为 (切片索引, 速度, 距离)
            MTD_data_for_one_beam(i+1, :, :) = MTD_result;   
        end
        
        % 将处理完的单个波束的完整MTD数据存入Cell数组
        MTD_win_all_beams{b} = MTD_data_for_one_beam;
    end
    
    % 如果需要，也可以保存窗口化的角度信息
    % angles_wins = [];
    % prts_per_slice_angle = length(angles_win) / 2;
    % for i = 0:(win_size - 1)
    %     start_idx = round(i * prts_per_slice_angle / win_size) + 1;
    %     end_idx = start_idx + prts_per_slice_angle - 1;
    %     angles_wins(i+1, :) = angles_win(start_idx:end_idx);
    % end

    % --- 4.4 保存所有波束的MTD结果 ---
    output_filename = fullfile(output_MTD_path, ['frame_', num2str(frameRInd), '.mat']);
    % 将包含所有波束结果的Cell数组 'MTD_win_all_beams' 保存到文件
    save(output_filename, 'MTD_win_all_beams');
    % 如果需要，也可以一同保存角度信息: save(output_filename, 'MTD_win_all_beams', 'angles_wins');

    fprintf('第 %d 帧处理完成并已保存到 %s\n', frameRInd, output_filename);
    toc
end

disp('所有帧处理完成。');
