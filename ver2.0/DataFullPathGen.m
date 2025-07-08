% dataFullPathGen.m 程序用于拼接信号采集文件的名称，按照格式要求调整
function dataFileFullPath = DataFullPathGen(DataFilePath, fileInd)

% 检查输入路径是否存在
if ~exist(DataFilePath, 'dir')
    error('数据目录不存在: %s', DataFilePath);
end

% 根据文件索引生成文件名
if fileInd < 10
    dataFileName = strcat('1.00000', num2str(fileInd), '.bin');
elseif fileInd < 100
    dataFileName = strcat('1.0000', num2str(fileInd), '.bin');
else
    dataFileName = strcat('1.000', num2str(fileInd), '.bin');
end

% 检查是否需要添加雷达原始数据子目录
radarDataDir = fullfile(DataFilePath, '雷达原始数据');
if exist(radarDataDir, 'dir')
    % 使用雷达原始数据子目录
    dataFileFullPath = fullfile(radarDataDir, dataFileName);
    fprintf('使用雷达原始数据子目录: %s\n', radarDataDir);
else
    % 直接使用输入路径
    dataFileFullPath = fullfile(DataFilePath, dataFileName);
end

% 输出调试信息
fprintf('生成文件路径: %s\n', dataFileFullPath);

% 检查文件是否存在
if ~exist(dataFileFullPath, 'file')
    warning('文件不存在: %s', dataFileFullPath);
end