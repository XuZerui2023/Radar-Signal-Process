%% 功能: 跨文件连续流读取器，从一系列二进制文件中连续读取指定长度的数据流，支持跨文件边界。
%   此函数通过 persistent 变量维护文件读取状态，模拟 C++ 类的行为。
%
% 输入:
%   expected_data_len: 期望读取的字节数（大小）。
%   orgDataFilePath: 原始数据文件根目录路径（用于调用 DataFullPathGen）。
%
% 输出:
%   read_data: 实际读取到的字节数据 (数据格式为 uint8 数据)。
%   actual_read_len: 实际读取的字节数。
%   is_end_of_stream: 逻辑值，如果无法再读取任何数据（文件已尽或错误），则为 true。
%   current_file_index: 当前操作的.bin文件的索引号。
% 注意: 首次运行或需要重置文件读取状态时，请执行:
%   clear read_continuous_file_stream;

% 修改记录
% date       by      version                            modify
% 25/06/10   XZR      v1.0         实现跨文件处理的下层函数，被上层函数 FrameDataRead_xzr.m 调用
% 25/07/03   XZR      v1.1         跟踪当前frame或prt所属的bin文件并返回文件索引号
% 未来改进：

function [read_data, actual_read_len, is_end_of_stream, current_file_index] = read_continuous_file_stream(expected_data_len, orgDataFilePath)

    % 持久化变量，模拟 C++ 类的成员变量
    persistent is_file_open_m;                % 当前是否有打开的文件
    persistent file_id_m;                     % 文件句柄
    persistent current_file_pos_m;            % 当前文件中的位置
    persistent current_file_max_length_m;     % 当前文件的总长度
    persistent current_file_index_m;          % 当前处理的文件索引


    % --- 初始化 持久化变量 ---
    % 仅在首次调用或被 clear 后才执行初始化
    if isempty(is_file_open_m)
        is_file_open_m = false;
        file_id_m = -1;           % MATLAB 中文件句柄 -1 表示无效
        current_file_pos_m = 0;
        current_file_max_length_m = 0;
        current_file_index_m = 0; % 从文件索引 0 开始，会在第一次打开文件时递增到 1
    end
    
    current_file_index = current_file_index_m;  % 在函数开始时，就将当前文件索引赋值给输出变量
    actual_read_len = 0;      % 对应 C++ 中的 nRealRead_Len
    read_data = uint8([]);    % 初始化输出数据缓冲区为 uint8 类型（注意这里底层数据格式统一读取为uint8，然后在上层函数中根据需要再转换为特定的数据类型）
    is_end_of_stream = false; % 默认未到数据流末尾

    % --- 1. 如果文件未打开，则尝试打开文件 ---
    if ~is_file_open_m
        current_file_index_m = current_file_index_m + 1; % 递增文件索引以获取下一个文件
        
        % --- 更新输出的索引号 ---
        current_file_index = current_file_index_m;
        
        % 调用 DataFullPathGen 函数生成文件路径
        current_file_name = DataFullPathGen(orgDataFilePath, current_file_index_m);

        file_id_m = fopen(current_file_name, 'r'); % 以只读模式打开文件
        if file_id_m == -1 % 对应 C++ 中的 INVALID_HANDLE_VALUE
            is_file_open_m = false;
            is_end_of_stream = true; % 无法打开文件，视为数据流结束
            warning('MATLAB:ReadDataStream:FileOpenFailed', '无法打开文件: %s. 数据流可能已结束或文件缺失。', current_file_name);
            return; % 无法读取，返回空数据
        end
        
        % 获取文件大小，并重置文件指针到开头
        fseek(file_id_m, 0, 'eof');                    % 移动到文件末尾
        current_file_max_length_m = ftell(file_id_m);  % 获取当前位置，即文件大小，用于后续判断
        fseek(file_id_m, 0, 'bof');                    % 移动到文件开头
         
        current_file_pos_m = 0;                        % 新文件从位置 0 开始读取
        is_file_open_m = true;                         % 文件已经打开
        fprintf('read_continuous_file_stream: 打开新文件: %s, 大小: %d 字节。\n', current_file_name, current_file_max_length_m);
    end

    % 确保文件指针位于当前记录的位置
    % 只有在文件有效时才执行 fseek
    if file_id_m ~= -1 && current_file_pos_m ~= ftell(file_id_m)           % 文件有效且当前记录的文件位置与实际文件指针位置一致
         fseek(file_id_m, current_file_pos_m, 'bof');
    end


    % --- 2. 核心读取逻辑：根据文件指针位置和期望长度判断读取情况 ---

    % 2.1. 情况一: 读取会跨越文件边界 （需要下个bin文件中的数据进行拼接形成完整一帧信号）
    if (current_file_pos_m + expected_data_len) > current_file_max_length_m     % 当前在文件中的位置（字节偏移量）+ 期望读取的字节数 > 当前文件的总大小
        % 计算当前文件剩余可读取的字节数
        read_from_current_file_len = current_file_max_length_m - current_file_pos_m;
        if read_from_current_file_len < 0 % 边界情况处理，确保不读取负数长度
            read_from_current_file_len = 0;
        end
        
        % 从当前文件读取剩余数据
        [part1_data, count1] = fread(file_id_m, read_from_current_file_len, '*uint8'); % *uint8 返回列向量
        actual_read_len = count1;  % 记录实际读取的字节数
        read_data = part1_data;    % 存储第一部分数据

        % 关闭当前文件句柄 (对应 C++ 中的 CloseHandle)
        fclose(file_id_m);
        file_id_m = -1;
        is_file_open_m = false; % 标记文件已关闭

        % 计算还需要从下一个文件读取的字节数
        remain_len = expected_data_len - actual_read_len;
        
        if remain_len > 0
            % --- 准备打开下一个文件 ---
            current_file_index_m = current_file_index_m + 1; % 递增文件索引
            next_file_name = DataFullPathGen(orgDataFilePath, current_file_index_m); % 获取下一个文件路径

            file_id_m = fopen(next_file_name, 'r'); % 打开下一个文件
            
            if file_id_m == -1                 % 无法打开下一个文件
                is_end_of_stream = true;       % 视为数据流结束（最后一个bin文件）
                warning('MATLAB:ReadDataStream:NextFileOpenFailed', '无法打开下一个文件: %s. 数据流可能已尽。返回当前已读数据。', next_file_name);
                
                % 如果无法打开下一个文件，就只能返回目前已读取的数据
                read_data = read_data;         % 保持已读的部分
                current_file_pos_m = 0;        % 无法继续读取，重置位置为0以便下次尝试
                current_file_max_length_m = 0; % 重置文件大小
                return;
            end
            
            % 能打开下一个文件，获取新文件大小，并重置文件指针到开头
            fseek(file_id_m, 0, 'eof');                   
            current_file_max_length_m = ftell(file_id_m);
            fseek(file_id_m, 0, 'bof');
            
            current_file_pos_m = 0; % 新文件从位置 0 开始读取
            is_file_open_m = true;
            fprintf('read_continuous_file_stream: 打开新文件: %s, 大小: %d 字节。\n', next_file_name, current_file_max_length_m);

            % 从新文件读取剩余数据
            [part2_data, count2] = fread(file_id_m, remain_len, '*uint8');
            actual_read_len = actual_read_len + count2; % 更新总读取字节数
            read_data = [read_data; part2_data];        % 拼接数据，将位于两个bin文件的中断信号文件拼接起来
            
            current_file_pos_m = current_file_pos_m + count2; % 更新新文件中的读取位置

        end

    % 2.2. 情况二: 读取正好到达当前文件末尾
    elseif (current_file_pos_m + expected_data_len) == current_file_max_length_m
        [full_data, count] = fread(file_id_m, expected_data_len, '*uint8');
        actual_read_len = count;
        read_data = full_data;
        
        % 关闭当前文件句柄
        fclose(file_id_m);
        file_id_m = -1;
        is_file_open_m = false; % 标记文件已关闭

        current_file_index_m = current_file_index_m + 1; % 准备读取下一个文件
        current_file_pos_m = 0; % 重置文件内位置
        current_file_max_length_m = 0; % 重置文件长度
        
    % 2.3. 情况三: 读取完全在当前文件内
    else % (current_file_pos_m + expected_data_len) < current_file_max_length_m
        [full_data, count] = fread(file_id_m, expected_data_len, '*uint8');
        actual_read_len = count;
        read_data = full_data;
        
        current_file_pos_m = current_file_pos_m + actual_read_len; % 更新文件内读取位置
    end

    % 最终检查: 如果实际读取的字节数少于期望的，并且当前文件仍然是打开状态
    % 这通常表示文件提前结束或读取错误
    if actual_read_len < expected_data_len && is_file_open_m % 只有当文件仍处于打开状态，且未读够才警告
        is_end_of_stream = true; % 视为数据流意外结束
        warning('MATLAB:ReadDataStream:PartialRead', '实际读取字节数 (%d) 少于期望字节数 (%d) 且文件未关闭。数据流可能提前结束。', actual_read_len, expected_data_len);
    end

end
