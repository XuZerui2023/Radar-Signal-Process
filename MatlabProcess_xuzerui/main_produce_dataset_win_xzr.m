% main_produce_dataset_win.m ���������ļ������������ݼ����ڣ���MTD����

clc;clear; close all;
%% Generate MTD per frame
n_exp=4;
tic;
win_size = 4;  % ���ڴ�С����Ϊ4
mkdir(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\',num2str(n_exp),'/MTD_data_win',num2str(win_size)]);     % �����洢MTD���ݵ��ļ��У�·������ʵ���źʹ��ڴ�С��̬����
fileFolder = fullfile('G:\20220420�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat');  % ���û���ԭʼ���ݵ��ļ���·��
dirOutput = dir(fullfile(fileFolder,'*.mat'));                                                    % ��ȡ������.matΪ��׺���ļ��б����������ļ��ĺ�׺��д'.mat'���ȡ��׺Ϊ'.mat'���ļ�
fileNames = {dirOutput.name};                                                                     % �������ļ������Ծ�����ʽ�������У����浽fileNames��                    

for frameRInd = 0:2000                                                                              % ѭ������0:3000����ʾ�����֡���
echo_now = load(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd),'.mat']); % ���ص�ǰ֡����frameRIndָ������.mat�ļ�����ֵ��echo_now�����ļ�������֡�Ļ����ź����ݡ�
echo_now_0 = echo_now.echoData_Frame_0;                                                             % ��ȡ��ǰ֡�ź�����
echo_now_1 = echo_now.echoData_Frame_1;
angles_now = echo_now.angleCodeSeries;                                                              % ��ȡ��ǰ֡�Ƕȱ�������

echo_next = load(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\',num2str(n_exp),'/BasebandRawData_mat/frame_',num2str(frameRInd+1),'.mat']); % ������һ֡�ź�����
echo_next_0 = echo_next.echoData_Frame_0;
echo_next_1 = echo_next.echoData_Frame_1;
angles_next = echo_next.angleCodeSeries;

echo_win_0 = [echo_now_0',echo_next_0']';  % ����ǰ֡����һ֡���ź�����echoData_Frame_0��echoData_Frame_1����ƴ�ӣ��γ�һ���µ��źŴ���
echo_win_1 = [echo_now_1',echo_next_1']';
angles_win = [angles_now,angles_next];

MTD_win_0 = []; % ��ʼ��MTD���ݴ���
MTD_win_1 = [];
    
    for i = 0:win_size-1
    
        echo_0 = echo_win_0(round(i*1536/win_size)+1 : round(i*1536/win_size)+1536, :); % ��echo_win_0��echo_win_1���и��ÿ�����ڵ��źŶΡ�ÿ�����ڵĴ�СΪ1536��������i�Ĳ�ͬ�иͬ���֡�
        echo_1 = echo_win_1(round(i*1536/win_size)+1 : round(i*1536/win_size)+1536, :);
        angles_wins(frameRInd+1,i+1,:) = angles_win(round(i*1536/win_size)+1:round(i*1536/win_size)+1536);

        MTD_0 = fun_MTD_produce(echo_0);    % ���ú��� fun_MTD_produce �����ź� echo_0 ��MTD
        MTD_1 = fun_MTD_produce(echo_1);    % ���ú��� fun_MTD_produce �����ź� echo_1 ��MTD
        MTD_0 = MTD_0(691:845,:);           % ��MTD�������ȡ�ض��������ݣ�Ϊʲô�ǵ�691�е���845�У� ���²������֣�
        MTD_1 = MTD_1(691:845,:);          
        MTD_win_0(i+1,:,:) = MTD_0;         % �Ծ�����ʽ����MTD����
        MTD_win_1(i+1,:,:) = MTD_1;
    end

% ��������MTD���ݱ��浽ָ��·���У��ļ����Ե�ǰ֡���frameRInd��������ǰ�ļ�·��ʾ����E:\20220421�����¥�������źŲɼ�\4\MTD_data_win4\frame_10.mat
save(['D:\MATLAB_Project\20220420�����¥�������źŲɼ�\',num2str(n_exp),'/MTD_data_win',num2str(win_size),'/frame_',num2str(frameRInd),'.mat'],'MTD_win_0','MTD_win_1');

frameRInd
toc

end






