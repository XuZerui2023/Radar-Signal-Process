function cfar_results = process_stage3_cfar(mtd_results, config)
% PROCESS_STAGE3_CFAR - 对MTD结果执行CFAR目标检测
%
% 本函数是原 main_cfar_xzr.m 脚本的功能化改造版本。
% 它接收MTD处理的结果，并对其中的每个数据切片执行CFAR检测。
%
% 输入参数:
%   mtd_results  - (cell) 来自第二阶段的MTD处理结果。
%   config       - (struct) 包含所有CFAR参数的配置结构体。
%
% 输出参数:
%   cfar_results - (cell) CFAR检测结果，结构与mtd_results完全对应。

%% 1. 从config结构体中获取参数
beam_num = config.Sig_Config.beam_num;
win_size = config.mtd.win_size;
CFAR_params = config.cfar; % 将CFAR相关的参数子结构体提取出来

%% 2. 对所有波束和切片进行CFAR检测
cfar_results = cell(beam_num, 1); % 初始化用于保存最终结果的Cell数组

% --- 波束循环 ---
% 循环体处理流程：帧 -> 波束 -> 切片
for b = 1:beam_num
    MTD_win_single_beam = mtd_results{b};
    
    cfarFlag_win_temp = []; % 初始化临时变量

    % --- 切片循环 ---
    for i = 1:win_size
        MTD_slice = squeeze(MTD_win_single_beam(i,:,:));
        MTD_temp = abs(MTD_slice);

        % 预处理：进行零速抑制
        MTD_temp = fun_0v_pressing(MTD_temp);

        % --- 调用核心CFAR处理函数 ---
        % 注意：这里的fun_CFARflag是本文件内定义的本地函数
        cfarFlag_temp = fun_CFARflag(MTD_temp, CFAR_params, config);
        
        cfarFlag_win_temp(i,:,:) = cfarFlag_temp;
    end
    
    cfar_results{b} = cfarFlag_win_temp;
end

fprintf('  > CFAR检测完成。\n');

end


%% ========================================================================
% 本地子函数 (从原main_cfar_xzr.m中移入)
% ========================================================================
function [cfarFlag] = fun_CFARflag(MTD_data, CFAR_params, config)
    % FUN_CFARFLAG - CFAR处理的"桥梁"函数
    % 它根据窄、中、长三种脉冲类型分割MTD数据，并为每一段调用核心CFAR执行器。

    % 从config中获取分割点数
    point_prt = config.Sig_Config.point_prt(1);
    point_prt_narrow = config.Sig_Config.point_prt(2);
    point_prt_medium = config.Sig_Config.point_prt(3);
    point_prt_long = config.Sig_Config.point_prt(4);
    
    % 1. 按脉冲类型分割距离维
    MTD_p0 = MTD_data(:, 1:point_prt_narrow);
    MTD_p1 = MTD_data(:, point_prt_narrow+1 : point_prt_narrow+point_prt_medium);
    MTD_p2 = MTD_data(:, point_prt_narrow+point_prt_medium+1 : point_prt);

    % 2. 为每一段数据调用executeCFAR
    % 注意：executeCFAR也需要被修改，以接收CFAR_params结构体
    [cfar_0, ~] = executeCFAR(MTD_p0, CFAR_params);
    [cfar_1, ~] = executeCFAR(MTD_p1, CFAR_params);
    [cfar_2, ~] = executeCFAR(MTD_p2, CFAR_params);

    % 3. 将各段的CFAR结果重新拼接起来
    cfarFlag = zeros(size(MTD_data));
    cfarFlag(:, 1:point_prt_narrow) = cfar_0;
    cfarFlag(:, point_prt_narrow+1 : point_prt_narrow+point_prt_medium) = cfar_1;
    cfarFlag(:, point_prt_narrow+point_prt_medium+1 : end) = cfar_2;
end
