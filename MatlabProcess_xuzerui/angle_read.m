  
%% 
clc;clear; close all;

n_exp=6;
tic;
fileFolder=fullfile('G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %���������ļ��ĺ�׺��д'.png'���ȡ��׺Ϊ'.png'���ļ�
fileNames={dirOutput.name}; %�������ļ������Ծ�����ʽ�������У����浽fileNames��   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/angles.mat'],'angles');

%% 
clc;clear; close all;
n_exp=7;
tic;
fileFolder=fullfile('G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %���������ļ��ĺ�׺��д'.png'���ȡ��׺Ϊ'.png'���ļ�
fileNames={dirOutput.name}; %�������ļ������Ծ�����ʽ�������У����浽fileNames��   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/angles.mat'],'angles');


%% 
clc;clear; close all;
n_exp=8;
tic;
fileFolder=fullfile('G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %���������ļ��ĺ�׺��д'.png'���ȡ��׺Ϊ'.png'���ļ�
fileNames={dirOutput.name}; %�������ļ������Ծ�����ʽ�������У����浽fileNames��   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/angles.mat'],'angles');

%% 
clc;clear; close all;
n_exp=9;
tic;
fileFolder=fullfile('G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat');
dirOutput=dir(fullfile(fileFolder,'*.mat')); %���������ļ��ĺ�׺��д'.png'���ȡ��׺Ϊ'.png'���ļ�
fileNames={dirOutput.name}; %�������ļ������Ծ�����ʽ�������У����浽fileNames��   

for frameRInd=0:length(fileNames)-2
echoes=load(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']);
angle=echoes.angleCodeSeries;
angles(frameRInd+1,:)=angle;
frameRInd
toc
end
save(['G:\20221109�����¥�������źŲɼ�\',num2str(n_exp),'/angles.mat'],'angles');
