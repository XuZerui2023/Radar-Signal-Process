% FUN_GET_K_VALUE - 获取指定频点和波束对的测角鉴别器斜率(K值)
% 本函数作为雷达标定数据的接口。它在第一次被调用时会加载K值标定文件，
% 之后根据输入的频点号和波束对编号，从中查找并返回对应的K值。
%
% 输入参数:
%   config          - (struct) 全局配置结构体，需包含K值文件的路径 .k_value_path
%   freInd          - (double) 当前帧工作的频点编号 (通常从0开始)。
%   beam_pair_index - (double) 当前处理的相邻波束对的索引 (从1到12)。
%
% 输出:
%   k_value         - (double) 查询到的测角K值。
%
%  修改记录
%  date       by      version   modify
%  25/07/12   XZR      v1.0      创建

function k_value = fun_get_k_value(config, freInd, beam_pair_index)
% --- 使用持久化变量(persistent)来缓存K值矩阵，这样可以避免每次调用函数都重复读取文件，提高效率 ---
persistent K_Matrix;

% --- 首次调用时，加载K值文件 ---
if isempty(K_Matrix)
    fprintf('首次调用，正在加载K值标定文件...\n');
    k_value_file_path = config.angle_k_path; % 从全局配置中获取路径
    if ~exist(k_value_file_path, 'file')
        error('K值标定文件不存在: %s', k_value_file_path);
    end
    % 使用readmatrix加载.ini文件，它能自动处理逗号分隔的数据
    K_Matrix = readmatrix(k_value_file_path);
    fprintf('K值矩阵加载成功，维度: %d x %d\n', size(K_Matrix, 1), size(K_Matrix, 2));
end

% --- 查表获取K值 ---
% 根据输入的频点号和波束对索引，在矩阵中查找对应的K值。
try
    k_value = K_Matrix(freInd + 1, beam_pair_index);
catch ME
    error('无法获取K值。请检查频点号(%d)和波束对索引(%d)是否在有效范围内。\n错误信息: %s', freInd, beam_pair_index, ME.message);
end

end
