 % ���ļ����ڶ�ȡ�ز����ݣ���������bin�ļ���ʽת��ΪMATLAB��mat�ļ���ʽ
% ������ frameDataRead_A.m ����
% 
clc;clear; close all;

%% 
prtNum = 1536;   % ����ÿ֡�źŵ���������ÿ֡�źŰ���1536������
n_exp = 4;       % ���ļ��б��
orgDataFilePath=['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\2\����ԭʼ����'];
mkdir(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\', num2str(n_exp)']);    % �½�һ���ļ������ڴ洢ת�����mat�ļ�

tic;
for frameRInd=0:2000  % ȫ����֡��
[echoData_Frame_0,echoData_Frame_1,frameInd,modFlag,beamPosNum,beamNums,freInd,angleCodeSeries] = frameDataRead_A_xzr(orgDataFilePath,frameRInd,prtNum);
%angleCode�����һ��prt�ĽǶ�,angleCodeSeries������prt�ĽǶ�

% ��frameDataRead_A_xzr.m ������ÿ֡�źŵ�'echoData_Frame_0','echoData_Frame_1','angleCodeSeries' ����mat�ļ�
% save(['G:\20220420�����¥�������źŲɼ�\4\BasebandRawData_mat', num2str(n_exp),'/frame_',num2str(frameRInd),'.mat'],'echoData_Frame_0','echoData_Frame_1','angleCodeSeries');
save(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\4\BasebandRawData_mat','/frame_',num2str(frameRInd),'.mat'],'echoData_Frame_0','echoData_Frame_1','angleCodeSeries');
disp(frameRInd);
disp(toc);
end


