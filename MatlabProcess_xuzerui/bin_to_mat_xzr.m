 % 此文件用于读取回波数据，将二进制bin文件格式转换为MATLAB的mat文件格式
% 引用了 frameDataRead_A.m 函数
% 
clc;clear; close all;

%% 
prtNum = 1536;   % 定义每帧信号的脉冲数，每帧信号包含1536个脉冲
n_exp = 4;       % 子文件夹编号
orgDataFilePath=['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\2\基带原始数据'];
mkdir(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\', num2str(n_exp)']);    % 新建一个文件夹用于存储转换后的mat文件

tic;
for frameRInd=0:2000  % 全部的帧数
[echoData_Frame_0,echoData_Frame_1,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCodeSeries] = frameDataRead_A_xzr(orgDataFilePath,frameRInd,prtNum);
%angleCode是最后一个prt的角度,angleCodeSeries是所有prt的角度

% 把frameDataRead_A_xzr.m 读出的每帧信号的'echoData_Frame_0','echoData_Frame_1','angleCodeSeries' 存入mat文件
% save(['G:\20220420气象局楼顶基带信号采集\4\BasebandRawData_mat', num2str(n_exp),'/frame_',num2str(frameRInd),'.mat'],'echoData_Frame_0','echoData_Frame_1','angleCodeSeries');
save(['D:\MATLAB_Project\20220420气象局楼顶基带信号采集\4\BasebandRawData_mat','/frame_',num2str(frameRInd),'.mat'],'echoData_Frame_0','echoData_Frame_1','angleCodeSeries');
disp(frameRInd);
disp(toc);
end


