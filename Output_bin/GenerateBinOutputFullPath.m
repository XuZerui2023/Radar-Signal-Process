function dataFileFullPath = GenerateBinOutputFullPath(output_path, fileInd)
% GenerateBinOutputFullPath - 为输出的bin文件生成符合命名规则的完整路径
%
% 本函数是 DataFullPathGen.m 的修改版，专门用于生成输出文件的路径。
%
% 输入参数:
%   output_path - (string) 保存.bin文件的目标文件夹路径。
%   fileInd     - (double) 文件索引号 (从1开始)。
%
% 输出:
%   dataFileFullPath - (string) 生成的完整文件路径。

% 检查输出目录是否存在，如果不存在则创建
if ~exist(output_path, 'dir')
    mkdir(output_path);
    fprintf('输出目录不存在，已创建: %s\n', output_path);
end

% 根据文件索引生成文件名，与DataFullPathGen.m的逻辑完全一致
if fileInd < 10
    dataFileName = strcat('1.00000', num2str(fileInd), '.bin');
elseif fileInd < 100
    dataFileName = strcat('1.0000', num2str(fileInd), '.bin');
else
    dataFileName = strcat('1.000', num2str(fileInd), '.bin');
end

% 拼接成完整路径
dataFileFullPath = fullfile(output_path, dataFileName);

end
