% main_produce_dataset_win.m 函数用于文件处理，产生数据集窗口，到MTD环节

clc;clear; close all;
%% Generate MTD per frame
n_exp=4;
tic;
win_size = 4;  % 窗口大小设置为4
mkdir(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\',num2str(n_exp),'/MTD_data_win',num2str(win_size)]);     % 创建存储MTD数据的文件夹，路径根据实验编号和窗口大小动态生成
fileFolder = fullfile('G:\20220420气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat');  % 设置基带原始数据的文件夹路径
dirOutput = dir(fullfile(fileFolder,'*.mat'));                                                    % 获取所有以.mat为后缀的文件列表，引号内是文件的后缀，写'.mat'则读取后缀为'.mat'的文件
fileNames = {dirOutput.name};                                                                     % 将所有文件名，以矩阵形式按行排列，保存到fileNames中                    

for frameRInd = 0:2000                                                                              % 循环索引0:3000，表示处理的帧编号
echo_now = load(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']); % 加载当前帧（由frameRInd指定）的.mat文件并赋值给echo_now，该文件包含该帧的基带信号数据。
echo_now_0 = echo_now.echoData_Frame_0;                                                             % 提取当前帧信号数据
echo_now_1 = echo_now.echoData_Frame_1;
angles_now = echo_now.angleCodeSeries;                                                              % 提取当前帧角度编码数据

echo_next = load(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd+1),'.mat']); % 加载下一帧信号数据
echo_next_0 = echo_next.echoData_Frame_0;
echo_next_1 = echo_next.echoData_Frame_1;
angles_next = echo_next.angleCodeSeries;

echo_win_0 = [echo_now_0',echo_next_0']';  % 将当前帧和下一帧的信号数据echoData_Frame_0和echoData_Frame_1进行拼接，形成一个新的信号窗口
echo_win_1 = [echo_now_1',echo_next_1']';
angles_win = [angles_now,angles_next];

MTD_win_0 = []; % 初始化MTD数据窗口
MTD_win_1 = [];
    
    for i = 0:win_size-1
    
        echo_0 = echo_win_0(round(i*1536/win_size)+1 : round(i*1536/win_size)+1536, :); % 从echo_win_0和echo_win_1中切割出每个窗口的信号段。每个窗口的大小为1536，并根据i的不同切割不同部分。
        echo_1 = echo_win_1(round(i*1536/win_size)+1 : round(i*1536/win_size)+1536, :);
        angles_wins(frameRInd+1,i+1,:) = angles_win(round(i*1536/win_size)+1:round(i*1536/win_size)+1536);

        MTD_0 = fun_MTD_produce(echo_0);    % 调用函数 fun_MTD_produce 计算信号 echo_0 的MTD
        MTD_1 = fun_MTD_produce(echo_1);    % 调用函数 fun_MTD_produce 计算信号 echo_1 的MTD
        MTD_0 = MTD_0(691:845,:);           % 从MTD结果中提取特定的行数据，为什么是第691行到第845行？ 看下波束划分？
        MTD_1 = MTD_1(691:845,:);          
        MTD_win_0(i+1,:,:) = MTD_0;         % 以矩阵形式保存MTD数据
        MTD_win_1(i+1,:,:) = MTD_1;
    end

% 将处理后的MTD数据保存到指定路径中，文件名以当前帧编号frameRInd命名。当前文件路径示例：E:\20220421气象局楼顶基带信号采集\4\MTD_data_win4\frame_10.mat
save(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\',num2str(n_exp),'/MTD_data_win',num2str(win_size),'/frame_',num2str(frameRInd),'.mat'],'MTD_win_0','MTD_win_1');

frameRInd
toc

end






