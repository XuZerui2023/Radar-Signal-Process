% main_mat_to_bin_converter.m
%
% v4.0 更新:
% - 数据源更改为加载一个单一的、包含所有帧累积数据的.mat文件。
% - 文件大小判断逻辑更新，现在会精确计算每一帧数据包的实际大小。
%
% --- 工作流程 ---
% 1. 选择一个包含累积目标数据的.mat文件。
% 2. 选择一个用于保存.bin文件的输出文件夹。
% 3. 初始化第一个.bin文件用于写入。
% 4. 遍历加载进来的总日志中的每一帧。
% 5. 在写入每一帧数据之前，精确计算该帧数据将占用的字节数。
% 6. 判断加上这部分数据后，当前的.bin文件是否会超过64MB的上限。
% 7. 如果会超过，则关闭当前文件，创建并打开一个新文件。
% 8. 将帧数据写入当前打开的.bin文件。
%
%  修改记录
%  date       by       version   modify
%  25/07/27   XZR       v1.0     创建
%  25/07/27   XZR       v2.0     修复get_frame_pack_size_bytes函数拼写错误；明确iFrame字段在计算和写入时不被包含。
%  25/07/28   XZR       v3.1     新增输出临时模拟结构体数组至工作区功能，用于查看实际写入BIN文件的数据，并修正Goal_Spec长度不一致问题。
%  25/07/28   XZR       v3.2     新增reorganizeStructFields子函数，支持结构体数组字段的子集选择与重排序。
%  25/07/29   XZR       v4.0     在主函数中添加数据重赋值/硬编码处理逻辑；确保iGoalNum为0时Goal_Para_Frame为1x1的空结构体。

clc; clear; close all;
%% 1. 用户配置与常量定义
fprintf('--- 开始 MAT 到 BIN 的转换流程 (按64MB大小分割) ---\n');
% --- 定义文件大小上限 ---
MAX_FILE_SIZE_BYTES = 64 * 1024 * 1024; % 64 MB

%% 2. 用户选择路径
% --- 选择包含累积数据的输入.mat文件 ---
[mat_filename, mat_pathname] = uigetfile('*.mat', '请选择包含累积目标数据的.mat文件');
if isequal(mat_filename, 0), disp('用户取消了选择。'); return; end
input_mat_path = fullfile(mat_pathname, mat_filename);

% --- 选择输出文件夹 ---
output_path = uigetdir('', '请选择一个用于保存输出 .bin 文件的文件夹');
if isequal(output_path, 0), disp('用户取消了选择。'); return; end

%% 3. 加载数据并对数据做一些预处理
fprintf('正在加载累积数据文件: %s\n', input_mat_path);
% 假设.mat文件中的变量名为 'point_inform_0'，与您的参考函数一致
try
    loaded_data = load(input_mat_path, 'cumulative_final_log');
    all_frames_data = loaded_data.cumulative_final_log;
catch
    error('无法从 "%s" 中加载 "point_inform_0" 变量。请检查文件名或变量名。', input_mat_path);
end

% 初始化并设置无检测目标下的空数组(注意无目标的帧文件要用1*1的空数组赋值，不能用1*0的空字段)
template_single_empty_goal_struct = struct(...
    'fAmp', single([]), ...
    'fSnr', single([]), ...
    'fAmuAngle', single([]), ...
    'fEleAngle', single([]), ...
    'fRange', single([]), ...
    'fSpeed', single([]), ...
    'fFdA', single([]), ...
    'fSpecWidth', single([]), ...
    'Goal_Spec', single([]) ... % 确保 Goal_Spec 也是单精度零向量
);

tic;

% --- 在此处添加对结构体数组的重组 ---
fprintf('正在重组结构体数组，排除第一个字段 "iFrame"...\n');
originalFieldNames = fieldnames(all_frames_data(1));

% 选择除第一个字段之外的所有字段，保存到bin文件的数据不需要第一个'iFrame' 字段
desiredFieldNames_for_output = originalFieldNames(2:end); 

% 调用新的子函数进行重组，现在，reorganized_frames_data 将不包含 'iFrame' 字段
reorganized_frames_data = reorganizeStructFields(all_frames_data, desiredFieldNames_for_output); 

fprintf('发现 %d 帧数据，开始转换...\n', length(all_frames_data));

% 对重组后的结构体数组中部分数据做一些处理（硬编码赋值等）
for i = 1:size(reorganized_frames_data, 1)
    reorganized_frames_data(i).iWaveFormNo = uint8(1);
    reorganized_frames_data(i).iDistanceMode = uint8(1);
    reorganized_frames_data(i).iAntSpeedMode = uint8(12);
    reorganized_frames_data(i).iAntAngle = int16(reorganized_frames_data(i).iAntAngle);
    reorganized_frames_data(i).iCenterFreq = uint16(9450);
    timescale_temp = 0.012 * i;
    reorganized_frames_data(i).TimeScale = single(timescale_temp);

    % 写入目标参数信息
    if reorganized_frames_data(i).iGoalNum ~= 0

        for j = 1:reorganized_frames_data(i).iGoalNum
            reorganized_frames_data(i).Goal_Para_Frame(j).Goal_Spec = zeros(48, 1, 'single');
        end
    
    else
        reorganized_frames_data(i).Goal_Para_Frame = template_single_empty_goal_struct; % 检测目标为0时，使用1*1空结构体数组赋值
    end
end


%%  4. 打开并初始化第一个输出文件（bin）
bin_file_index = 1;
output_bin_path = GenerateBinOutputFullPath(output_path, bin_file_index);
fileID = fopen(output_bin_path, 'w');
if fileID == -1
   error('无法创建初始的.bin文件: %s', output_bin_path);
end
fprintf('  > 正在写入第一个文件: %s\n', output_bin_path);

%% 5. 循环遍历所有帧数据
for i = 1:length(all_frames_data)
    current_frame_data = reorganized_frames_data(i);
    
    % --- 精确计算当前帧数据包的字节大小 ---
    bytes_this_frame = get_frame_pack_size_bytes(current_frame_data);
    
    % --- 获取当前.bin文件的实时大小 ---
    fseek(fileID, 0, 'eof');
    current_bin_size = ftell(fileID);
    
    % --- 判断是否需要切换到新文件 ---
    if (current_bin_size + bytes_this_frame) > MAX_FILE_SIZE_BYTES && current_bin_size > 0
        fclose(fileID);
        fprintf('  > 文件 %s 已达到64MB上限。\n', output_bin_path);
        
        bin_file_index = bin_file_index + 1;
        output_bin_path = GenerateBinOutputFullPath(output_path, bin_file_index);
        fileID = fopen(output_bin_path, 'w');
        if fileID == -1
           warning('无法创建新的.bin文件: %s，跳过此帧。', output_bin_path);
           continue;
        end
        fprintf('  > 正在写入新的文件: %s\n', output_bin_path);
    end
    
    % --- 调用核心写入函数 ---
    write_frame_pack_to_bin(fileID, current_frame_data);

end
toc;

%% 6. 循环结束后，关闭最后一个打开的文件（bin）
if fileID ~= -1
    fclose(fileID);
end
fprintf('--- 所有文件转换完成 ---\n');




%% ========================================================================
%  本地调用的子函数


% get_frame_pack_size_bytes.m: 本函数精确计算一个两层结构体将占用的字节数
function bytes = get_frame_pack_size_bytes(frame_pack)
    
    
    % 计算头部大小
    header_bytes = 1 + 1 + 1 + 2 + 2 + 4 + 8 + 2; % char,char,char,short,ushort,float,double,ushort
    
    % 计算每个目标的字节大小
    spec_data_len = 128; % 假设 SPECDATA_LEN 为 128
    bytes_per_goal = (8 * 4) + (spec_data_len * 4); % 8个float + spec_len个float
    
    % 计算总字节数
    bytes = header_bytes + frame_pack.iGoalNum * bytes_per_goal;
end


% reorganizeStructFields.m: 对结构体数组的字段进行重组（选择子集或重新排序）。
function reorganizedStructArray = reorganizeStructFields(originalStructArray, desiredFieldNames)
 
    %   reorganizedStructArray = reorganizeStructFields(originalStructArray, desiredFieldNames)
    %
    %   输入:
    %     originalStructArray: 原始的结构体数组。
    %     desiredFieldNames: 一个 cell 数组，包含你希望在新结构体中保留的字段名，
    %                        以及它们在新结构体中的顺序。
    %                        如果 originalStructArray 中不包含某个 desiredFieldNames，
    %                        则该字段在新结构体中将为空 ([]).
    %
    %   输出:
    %     reorganizedStructArray: 一个新的结构体数组，包含按指定顺序排列的字段子集。

    % --- 输入参数校验 ---
    if ~isstruct(originalStructArray)
        error('reorganizeStructFields:InvalidInput', '输入 originalStructArray 必须是一个结构体数组。');
    end
    if ~iscellstr(desiredFieldNames) || isempty(desiredFieldNames)
        error('reorganizeStructFields:InvalidInput', 'desiredFieldNames 必须是一个非空的字符串 cell 数组。');
    end

    numElements = numel(originalStructArray);
    numDesiredFields = numel(desiredFieldNames);

    % --- 初始化新的结构体数组 ---
    % 预分配可以提高效率。这里我们创建第一个结构体元素，然后用 repmat 复制。
    if numElements > 0
        % 构建第一个（空值）结构体，包含所有期望的字段
        firstElementTemplate = struct();
        for k = 1:numDesiredFields
            fieldName = desiredFieldNames{k};
            % 初始赋值为空，后续填充实际数据
            firstElementTemplate.(fieldName) = []; 
        end
        % 预分配整个结构体数组
        reorganizedStructArray = repmat(firstElementTemplate, numElements, 1);
    else
        % 如果原始数组为空，则返回一个相同维度的空结构体数组
        reorganizedStructArray = originalStructArray;
        return;
    end

    % --- 遍历并填充新的结构体数组 ---
    for i = 1:numElements
        currentOriginalStruct = originalStructArray(i);
        
        for j = 1:numDesiredFields
            fieldName = desiredFieldNames{j};
            
            % 检查原始结构体中是否存在该字段
            if isfield(currentOriginalStruct, fieldName)
                reorganizedStructArray(i).(fieldName) = currentOriginalStruct.(fieldName);
            else
                % 如果原始结构体中没有这个字段，则保持为空或根据需要赋默认值
                % reorganizedStructArray(i).(fieldName) 已经由预分配初始化为空，这里无需重复赋值
                warning('reorganizeStructFields:FieldNotFound', ...
                        '元素 %d 中，字段 "%s" 在原始结构体中不存在，在新结构体中将为空。', i, fieldName);
            end
        end
    end
end


%% 检测伺服角（校正后）临时程序
% j = 1 ;
% for i = 1 : length(all_frames_data)
%     if reorganized_frames_data(i).iGoalNum ~= 0;
%         servo_angle(j) = reorganized_frames_data(i).Goal_Para_Frame(1).fAmuAngle
%         j = j+1;
%     end
% end
% 
% plot(servo_angle);