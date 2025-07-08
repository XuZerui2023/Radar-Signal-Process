% fun_Process_MTD MTD处理函数
% 速度-距离 FFT，动目标检测
% 本函数接收一个经过脉冲压缩的"距离-脉冲"域数据矩阵，通过对每个距离单元的脉冲串进行慢时间FFT（按列方向），将其转换为"距离-速度"域矩阵（距离-多普勒图, RDM）。
%
% 输入参数:
%   ProSignal       - (Num_PRTperFrame x Len_PRT) 输入的信号矩阵，行方向代表快时间（距离），列方向代表慢时间（脉冲）。
%   Len_PRT         - (double) 距离单元（一个采样点对应一个距离单元）的数量，即矩阵的列数。
%   Num_PRTperFrame - (double) 一个相参处理间隔（CPI）中的脉冲数量，即矩阵的行数。
%
% 输出参数:
%   MTD_Signal      - (Num_PRTperFrame x Len_PRT) 输出的速度-距离矩阵。行代表速度单元，列代表距离单元。

function MTD_Signal = fun_Process_MTD(ProSignal, Len_PRT, Num_PRTperFrame)
%% MTD处理
% 1. 生成窗函数
% 在进行FFT之前对信号加窗，可以有效抑制频谱泄漏，防止强信号能量泄露到相邻的频率单元，从而提高对弱小目标的检测能力。
betaMTD = 8;
WindowData= kaiser(Num_PRTperFrame,betaMTD);                   % 加窗
% WindowData=load('kaiser_win.mat').kaiser_win;
% WindowData = ones(Num_PRTperFrame,1);                        % 矩形窗 即不加窗

% 2. 初始化输出矩阵
MTD_Signal = zeros(Num_PRTperFrame,Len_PRT);                   % MTD处理结果
MTD_Signal_R = zeros(1,Len_PRT);                               % MTD距离维处理结果

% 3. 逐个距离单元进行MTD处理 (多普勒FFT)
for Index=1:Len_PRT
    % 加窗处理
    Signal_Win = ProSignal(:,Index) .* WindowData;             % 提取出当前距离单元的所有脉冲回波，形成一个列向量。
    % FFT处理
    FFT_Signal = fftshift(fft(Signal_Win, Num_PRTperFrame));   % 按列进行FFT
    % 求模值
    Abs_Signal = abs(FFT_Signal);
    % 距离单元选大
    [MTD_Signal_R(Index),~] = max(Abs_Signal);    % 找出当前距离单元所有速度中的最大能量值，这是一种简单的非相参累积。
    MTD_Signal(:,Index) = Abs_Signal;             % 将当前距离单元的速度谱存入最终的RDM矩阵
end
% 提取每个速度单元的最大距离响应
MTD_Signal_V = max(MTD_Signal,[],2)';             % 对整个RDM矩阵，沿着距离维（行方向）求最大值，
end

