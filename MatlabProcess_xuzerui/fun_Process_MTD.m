% 速度-距离 FFT，动目标检测

function MTD_Signal = fun_Process_MTD( ProSignal,Len_PRT,Num_PRTperFrame )
%fun_Process_MTD MTD处理函数
%   MTD处理函数对每个距离单元的数据进行 FFT, abs, max 处理
%  输入函数：ProSignal              待处理数据 矩阵形式：Num_PRTperFrame*Len_PRT
%            Len_PRT                信号脉冲数据长度
%            Num_PRTperFrame        信号相参积累点数
%  输出函数：MTD_Signal_R           MTD距离维处理结果 矢量形式：1*Len_PRT
%            MTD_Signal_V           MTD速度维处理结果  矢量形式：1*Num_PRTperFrame
%% MTD处理
% 生成窗函数 - 矩形窗
betaMTD = 8;
WindowData= kaiser(Num_PRTperFrame,betaMTD);
% WindowData=load('kaiser_win.mat').kaiser_win;
% WindowData = ones(Num_PRTperFrame,1);                                    %%矩形窗 即不加窗
MTD_Signal = zeros(Num_PRTperFrame,Len_PRT);                               %%MTD处理结果
MTD_Signal_R = zeros(1,Len_PRT);                                           %%MTD距离维处理结果
% 每个距离单元的数据进行 MTD 处理
for Index=1:Len_PRT
    % 加窗处理
    Signal_Win = ProSignal(:,Index) .* WindowData; 
    % FFT处理
    FFT_Signal = fftshift(fft(Signal_Win, Num_PRTperFrame));
    % 求模值
    Abs_Signal = abs(FFT_Signal);
    % 距离单元选大
    [MTD_Signal_R(Index),~] = max(Abs_Signal);  
    MTD_Signal(:,Index) = Abs_Signal;  
end
% 速度单元选大
MTD_Signal_V = max(MTD_Signal,[],2)';
end

