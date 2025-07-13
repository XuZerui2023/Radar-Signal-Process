%% 功能：管理数据读取过程中的重试计数。
%   通过不同的动作（'get', 'increment', 'reset'）来获取、增加或重置计数。
%
% 输入：
%   action: 字符串，可选。
%           'get'      - 获取当前计数 (默认动作)。
%           'increment' - 增加计数并返回新值。
%           'reset'    - 重置计数为0并返回0。
%
% 输出：
%   val: 根据动作返回的计数器值。

function val = manage_retry_count(action)
    % 声明持久化变量，它只在函数内部保持状态
    persistent retry_count_val;

    % 如果持久化变量未初始化，则初始化为0
    if isempty(retry_count_val)
        retry_count_val = 0;
    end

    % 根据传入的动作执行相应操作
    if nargin == 0 || strcmp(action, 'get')
        % 默认或显式请求获取计数
        val = retry_count_val;
    elseif strcmp(action, 'increment')
        % 增加计数
        retry_count_val = retry_count_val + 1;
        val = retry_count_val;
    elseif strcmp(action, 'reset')
        % 重置计数
        retry_count_val = 0;
        val = retry_count_val;
    else
        % 无效动作，抛出错误
        error('manage_retry_count: Invalid action specified. Use ''get'', ''increment'', or ''reset''.');
    end
end