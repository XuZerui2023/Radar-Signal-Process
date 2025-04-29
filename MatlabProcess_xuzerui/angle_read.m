  
%% 
clc;clear; close all;

n_exp=6;
tic;
fileFolder=fullfile('G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
fileNames={dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/angles.mat'],'angles');

%% 
clc;clear; close all;
n_exp=7;
tic;
fileFolder=fullfile('G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
fileNames={dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/angles.mat'],'angles');


%% 
clc;clear; close all;
n_exp=8;
tic;
fileFolder=fullfile('G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
fileNames={dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/angles.mat'],'angles');

%% 
clc;clear; close all;
n_exp=9;
tic;
fileFolder=fullfile('G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
fileNames={dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109气象局楼顶基带信号采集\',num2str(n_exp),'/angles.mat'],'angles');
