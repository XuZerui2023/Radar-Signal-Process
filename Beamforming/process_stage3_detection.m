% process_stage3_detection.m - 目标检测阶段控制脚本
% 本函数的核心职责是"发现目标"，并为下一阶段的"精算参数"准备好所有必要的原始信息。
% - 重构为函数式调用，直接接收process_stage2_mtd.m 结果作为输入参数，而不是从文件加载。
% - 函数现在处理单帧数据，并返回一个初步检测日志，由主控脚本决定如何处理。
% - 移除了文件I/O操作，使其成为一个纯粹的数据处理模块。
%
% --- 工作流程 ---
% 1. 接收由第二阶段(MTD)生成的、属于单帧的13个原始俯仰波束RDM数据。
% 2. 遍历12对相邻的交叠波束 (e.g., 波束1和2, 波束2和3, ...)。
% 3. 对每一对波束，通过幅度求和的方式动态合成一个临时的"和波束"。
% 4. 在这个"和波束"的幅度矩阵上执行CFAR检测，以找出潜在的目标点。
% 5. 将每个潜在目标的原始信息（最关键的是它在构成和差的两个原始波束中的复数值）
%    打包并作为函数返回值输出。
%
% 输入参数:
%   mtd_results_one_frame - (cell) 单帧的MTD处理结果，即包含13个RDM的元胞数组。
%   config                - (struct) 全局配置结构体，包含了所有路径和处理参数。
%   frame_idx             - (double) 当前正在处理的帧编号，用于日志记录。
%
% 输出:
%   prelim_log_this_frame - (struct array) 包含本帧所有潜在目标原始信息的结构体数组。
%
%  修改记录
%  date       by      version   modify
%  25/07/10   XZR      v1.0      创建，用于替代旧的CFAR处理流程
%  25/07/12   XZR      v2.0      重构为直接接收MTD结果的函数

function prelim_log_this_frame = process_stage3_detection(mtd_results_one_frame, config, frame_idx)
%% 1. 初始化与参数加载
% =========================================================================
fprintf('--- STAGE 3: 正在检测帧 #%d...\n', frame_idx);

% --- 从全局配置中获取所需处理参数 ---
beam_num = config.Sig_Config.beam_num;
win_size = config.mtd.win_size;
CFAR_params = config.cfar; % 从config中获取CFAR参数，这些参数由主控脚本统一配置

% MTD_win_all_beams 是一个 13x1 的元胞数组(cell array), 
% 每个元胞 MTD_win_all_beams{i} 存储了第i个波束的所有切片数据。
MTD_win_all_beams = mtd_results_one_frame;

%% 2. 主处理逻辑
% =========================================================================
% --- 初始化日志 ---
% 为当前处理的这一帧，初始化一个空的结构体数组，用于存储所有检测到的潜在目标信息。
% 字段定义了后续参数测量所需的所有原始数据。
prelim_log_this_frame = struct(...
    'frame_index', {}, ...          % 帧号
    'slice_index', {}, ...          % 滑动窗口的切片号
    'beam_pair_index', {}, ...      % 发现目标的波束对编号 (1到12)
    'velocity_index', {}, ...       % 目标在RDM中的速度维索引
    'range_index', {}, ...          % 目标在RDM中的距离维索引
    'complex_val_beam1', {}, ...    % 【关键】目标在波束对中第一个波束的复数值
    'complex_val_beam2', {}  ...    % 【关键】目标在波束对中第二个波束的复数值
);

% --- 遍历所有数据切片 ---
for s = 1 : win_size          % 目前切片窗口为 4
    
    % --- 核心逻辑: 遍历所有相邻的波束对 ---
    for i = 1:(beam_num - 1)  % 目前波束对为 12
        
        % 1. 获取相邻的两个原始RDM (复数矩阵)，squeeze() 用于移除单维度，将 (1 x vel x range) 变为 (vel x range)
        RDM_beam1 = squeeze(MTD_win_all_beams{i}(s, :, :));
        RDM_beam2 = squeeze(MTD_win_all_beams{i+1}(s, :, :));
        
        % 2. 合成"和信号"幅度矩阵，专门用于CFAR检测，一般使用幅度求和的方式构造和信号，信噪比最高。
        RDM_sum_amp = abs(RDM_beam1) + abs(RDM_beam2);
        
        % 3. 在"和信号"上执行CFAR检测，调用本地封装的CFAR函数，得到0-1标志矩阵。
        cfar_flag_matrix = local_execute_cfar(RDM_sum_amp, CFAR_params, config);
        
        % 4. 查找所有被检测为目标的位置
        [target_v_indices, target_r_indices] = find(cfar_flag_matrix);
        
        % 5. 如果找到目标，打包所有原始信息并存入日志
        if ~isempty(target_v_indices)
            num_detections = numel(target_v_indices);
            
            % 使用预分配和元胞数组的方式，可以提高批量创建结构体的效率
            temp_detections(1:num_detections) = struct(...
                'frame_index', frame_idx, ...
                'slice_index', s, ...
                'beam_pair_index', i, ... % 记录这是由第i和i+1波束对发现的
                'velocity_index', 0, ...
                'range_index', 0, ...
                'complex_val_beam1', 0, ...
                'complex_val_beam2', 0 ...
            );

            for k = 1:num_detections
                v_idx = target_v_indices(k);
                r_idx = target_r_indices(k);
                
                temp_detections(k).velocity_index = v_idx;
                temp_detections(k).range_index = r_idx;
                
                % 提取并记录两个原始波束在该目标点的【复数值】，这是进行和差单脉冲测角最关键的原始数据
                temp_detections(k).complex_val_beam1 = RDM_beam1(v_idx, r_idx);
                temp_detections(k).complex_val_beam2 = RDM_beam2(v_idx, r_idx);
            end
            
            % 将当前波束对的检测结果追加到本帧的总日志中
            prelim_log_this_frame = [prelim_log_this_frame; temp_detections.'];
        end
    
    end % 结束波束对循环

end     % 结束切片循环

% --- 结束处理，返回日志 ---
if ~isempty(prelim_log_this_frame)
    fprintf('  > 帧 #%d 检测到 %d 个潜在目标。\n', frame_idx, length(prelim_log_this_frame));
else
    fprintf('  > 帧 #%d 未检测到目标。\n', frame_idx);
end
fprintf('--- STAGE 3: 目标检测完成 ---\n\n');

end


%% ========================================================================
% 本地CFAR执行函数 (Local Helper Functions)
% ========================================================================
function cfar_flag = local_execute_cfar(mtd_amplitude_map, cfar_params, config)
    % 这是一个简化的CFAR执行器，它接收一个幅度矩阵并返回一个0-1标志矩阵。
    % 它内部调用了更底层的1D-CFAR函数。

    % --- 1. 按脉冲类型分割距离维进行处理 ---
    % 您的雷达使用了多种脉冲，不同距离段的信号特性不同，分开处理更精确。
    point_prt_narrow = config.Sig_Config.point_prt(2);
    point_prt_medium = config.Sig_Config.point_prt(3);
    
    MTD_p0 = mtd_amplitude_map(:, 1:point_prt_narrow);
    MTD_p1 = mtd_amplitude_map(:, point_prt_narrow+1 : point_prt_narrow+point_prt_medium);
    MTD_p2 = mtd_amplitude_map(:, point_prt_narrow+point_prt_medium+1 : end);

    % --- 2. 对每个区域分别执行二维CFAR ---
    % 注意：这里的executeCFAR_2D是另一个需要定义的本地函数
    cfar_0 = executeCFAR_2D(MTD_p0, cfar_params);
    cfar_1 = executeCFAR_2D(MTD_p1, cfar_params);
    cfar_2 = executeCFAR_2D(MTD_p2, cfar_params);

    % --- 3. 将各段的CFAR结果重新拼接起来 ---
    cfar_flag = zeros(size(mtd_amplitude_map));
    cfar_flag(:, 1:point_prt_narrow) = cfar_0;
    cfar_flag(:, point_prt_narrow+1 : point_prt_narrow+point_prt_medium) = cfar_1;
    cfar_flag(:, point_prt_narrow+point_prt_medium+1 : end) = cfar_2;
end

function cfarResultFlag = executeCFAR_2D(echo_mtd_amp, cfar_params)
    % 实现了"先速度维，后距离维"的二维CFAR检测策略
    
    % --- 从参数结构体中获取所需参数 ---
    refCells_V = cfar_params.refCells_V;
    saveCells_V = cfar_params.saveCells_V;
    T_CFAR_V = cfar_params.T_CFAR_V;
    CFARmethod_V = cfar_params.CFARmethod_V;
    
    refCells_R = cfar_params.refCells_R;
    saveCells_R = cfar_params.saveCells_R;
    T_CFAR_R = cfar_params.T_CFAR_R;
    CFARmethod_R = cfar_params.CFARmethod_R;
    
    [vCellNum, rCellNum] = size(echo_mtd_amp);

    % --- 第一步：速度维CFAR ---
    % Function_CFAR1D_sub需要按行检测，所以先转置矩阵
    cfar_result_V = Function_CFAR1D_sub(echo_mtd_amp.', refCells_V, saveCells_V, T_CFAR_V, CFARmethod_V).';

    % --- 第二步：距离维CFAR ---
    % 仅对第一步检测出的可疑目标点，进行距离维的二次确认
    cfarResultFlag = zeros(vCellNum, rCellNum);
    [v_indices, r_indices] = find(cfar_result_V);
    
    if ~isempty(v_indices)
        for k = 1:length(v_indices)
            v_idx = v_indices(k);
            r_idx = r_indices(k);
            
            % 对单个可疑行进行距离维检测
            row_to_check = echo_mtd_amp(v_idx, :);
            % 调用一个简化的本地函数来检测单个点
            flag_R = check_single_point_cfar(row_to_check, r_idx, refCells_R, saveCells_R, T_CFAR_R, CFARmethod_R);
            
            if flag_R
                cfarResultFlag(v_idx, r_idx) = 1;
            end
        end
    end
end

function flag = check_single_point_cfar(data_row, cut_idx, ref_cells, guard_cells, T_cfar, method)
    % 简化版1D-CFAR，只检测单个点
    flag = 0;
    len = length(data_row);
    
    % 定义参考窗和保护窗的边界
    left_guard_end = cut_idx - guard_cells - 1;
    left_ref_start = left_guard_end - ref_cells + 1;
    
    right_guard_start = cut_idx + guard_cells + 1;
    right_ref_end = right_guard_start + ref_cells - 1;
    
    noise_L = -1; % 初始值，表示左侧噪声未计算
    noise_R = -1; % 初始值，表示右侧噪声未计算
    
    % 计算左侧参考窗的噪声平均值
    if left_ref_start >= 1
        noise_L = mean(data_row(left_ref_start:left_guard_end));
    end
    
    % 计算右侧参考窗的噪声平均值
    if right_ref_end <= len
        noise_R = mean(data_row(right_guard_start:right_ref_end));
    end
    
    % 噪声估计策略
    if noise_L == -1 && noise_R == -1
        return; % 边缘情况：左右都无法估计噪声，直接返回
    elseif noise_L == -1
        noise_est = noise_R; % 左侧无参考窗，使用右侧噪声
    elseif noise_R == -1
        noise_est = noise_L; % 右侧无参考窗，使用左侧噪声
    else
        % 正常情况：两侧都有参考窗
        if method == 0 % 选大 (CA-GO)
            noise_est = max(noise_L, noise_R);
        else % 选小 (CA-SO)
            noise_est = min(noise_L, noise_R);
        end
    end
    
    % 比较门限
    threshold = noise_est * T_cfar;
    if data_row(cut_idx) > threshold
        flag = 1; % 超过门限，判定为目标
    end
end

% 依赖提示:
% 为保证此脚本能完整运行，您需要确保 MATLAB 的工作路径中包含您项目中的
% Function_CFAR1D_sub.m 文件，因为它被本地函数 executeCFAR_2D 所调用。
% 或者，您可以将 Function_CFAR1D_sub.m 的代码也作为本地函数复制到此文件末尾。

function [PeakDetectionoutput] = Function_CFAR1D_sub(datamatrix,refCellNum,saveCellNum,T_CFAR,CFARmethod)
% input:
% datamatrix: 待做CFAR的矩阵，
% refCellNum: 参考单元点数,
% saveCellNum:保护单元点数
% T_CFAR:检测门限
% CFARmethod;  % 0--选大；1--选小；
% output:
% PeakDetectionoutput：峰值点处有正值，其余都是0
%
% fuxiongjun, 2008-12-28. modified @2009-03-05
% Rui_W modified @2015-07-21

[RowNum_ASR,ColNum_ASR]=size(datamatrix);
PeakDetectionoutput=zeros(RowNum_ASR,ColNum_ASR);

for y=1:ColNum_ASR
    if CFARmethod==0
        refL_average=zeros(RowNum_ASR,1);  % 初始化
        refR_average=zeros(RowNum_ASR,1);  % 初始化
    else
        refL_average=Inf*ones(RowNum_ASR,1);  % 初始化
        refR_average=Inf*ones(RowNum_ASR,1);  % 初始化
    end
    refL1=y-(saveCellNum+refCellNum);% 左参考单元的左边界
    refL2=y-saveCellNum-1;           % 左参考单元的右边界
    refR1=y+saveCellNum+1;           % 右参考单元的左边界
    refR2=y+saveCellNum+refCellNum;  % 右参考单元的右边界

    if refL1>=1
        refL_average=mean(datamatrix(:,refL1:refL2),2);  % 左参考单元的平均
    else % 左参考单元点数不够,则用检测点右边的数据估计杂波水平
        refL_average = mean(datamatrix(:,refR1:refR2),2);
    end
    if refR2<=ColNum_ASR
        refR_average=mean(datamatrix(:,refR1:refR2),2);    % 右参考单元的平均
    else  % 右参考单元点数不够,则用检测点左边的数据估计杂波水平
        refR_average=mean(datamatrix(:,refL1:refL2),2);
    end
    if CFARmethod==0
        ref_average_used=max(refL_average,refR_average);     % 选大
    else
        ref_average_used=min(refL_average,refR_average);     % 选小
    end
    threshold_CFAR=ref_average_used.*T_CFAR;           % 生成门限 (DSP程序中，threshold_CFAR可只用一个变量，不必用数组.这里是方便测试）
    flag=datamatrix(:,y)>=threshold_CFAR;

    %     if y==1
    %         flag1=ones(RowNum_ASR,1);
    %     else
    %         flag1=datamatrix(:,y)>=datamatrix(:,y-1);
    %     end
    %
    %     if y==ColNum_ASR
    %         flag2=ones(RowNum_ASR,1);
    %     else
    %         flag2=datamatrix(:,y)>=datamatrix(:,y+1);
    %     end
    flag1 = 1;
    flag2 = 1;

    % 这里将会删掉许有效的检测点
    % flag3=datamatrix(:,y)>=[0;datamatrix(1:end-1,y)];
    % flag4=datamatrix(:,y)>=[datamatrix(2:end,y);0];
    flag3 = 1;
    flag4 = 1;

    PeakDetectionoutput(:,y)=flag.*flag1.*flag2.*flag3.*flag4;
end

end




