% 本函数对多脉冲体制的雷达回波进行分段脉冲压缩
% 本函数专门处理一种由三种不同脉冲（短、中、长）拼接而成的复合雷达波形。
% 它首先将回波信号按脉冲类型分割，然后对每一段使用不同的方法进行脉冲压缩，最后将结果重新合并。
%
% 输入参数:
%   echoData_Frame_0 - (prtNum x point_prt) 原始回波数据矩阵，每一行是一个完整的PRT回波。
%   show_PC          - (logical) 绘图开关，为1时显示每个PRT的脉压结果，用于调试。
%   pulse1           - (1xN1) 第1种脉冲（窄脉冲）的参考波形。
%   pulse2           - (1xN2) 第2种脉冲（中脉冲）的参考波形。
%   pulse3           - (1xN3) 第3种脉冲（长脉冲）的参考波形。
%   point_prt1       - 短脉冲的采样点数
%   point_prt2       - 中脉冲的采样点数
%   point_prt3       - 长脉冲的采样点数
% 输出参数:
%   s_PC_0           - (prtNum x point_prt) 脉冲压缩并重组后的信号矩阵。
%
function s_PC_0 = fun_lss_pulse_compression(echoData,params,show_PC,pulse1,pulse2,pulse3,point_prt1,point_prt2,point_prt3)

%将三个脉冲分开                     为什么总采集点数~= 窄脉冲采集点数 + 中脉冲采集点数 + 长脉冲采集点数 !!!!!!
[m,n] = size(echoData);
prtNum = m;
point_prt = n;
signal_01 = echoData( :, 1:point_prt1);                          % 1-228
signal_02 = echoData( :, point_prt1+1 : point_prt1+point_prt2);  % 229-951
signal_03 = echoData( :, point_prt1+point_prt2+1 : point_prt);   % 952-3404

s_PC_0 = zeros(prtNum, point_prt); % 脉冲压缩后再合到一起


% FIR滤波器系数（这个缺失）
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9];
filter_coef = filter_coef /max(filter_coef ); % 归一化


% 脉冲压缩
for i_prt = 1:prtNum
    % 各子脉冲 脉冲压缩
    signal_PC_01 = filter(filter_coef,1,signal_01(i_prt,:).').';        % 窄脉冲作fir滤波
    signal_PC_01 = signal_PC_01/1.2;

    signal_PC_02 = fun_pulse_compression(pulse2, signal_02(i_prt,:));   % 中脉冲压缩
    signal_PC_03 = fun_pulse_compression(pulse3, signal_03(i_prt,:));   % 长脉冲压缩

    % 脉冲压缩结果对齐
    % s_PC_0(i_prt,1:point_prt1) = signal_PC_01(1:point_prt1);          % 向量对齐
    % 自动计算FIR滤波器的群延迟 (通常为整数)
    delay1 = round(mean(grpdelay(filter_coef)));                        % 计算FIR滤波器的群延迟

    % 使用循环移位来校正这个延迟 (将结果向前移动 delay1 个点)
    temp_signal = circshift(signal_PC_01, -delay1);                     % 将结果循环前移，从而补偿延迟
    s_PC_0(i_prt, 1:point_prt1) = temp_signal(1:point_prt1);            % 向量对齐
    
    %pluse1采用filter进行脉压，结果总是会导致尖峰比实际位置延后12个点，所以就将输出前移12点
    % s_PC_0(i_prt,1:point_prt1-12)=signal_PC_01(13:point_prt1);
    % s_PC_0(i_prt,point_prt1-12+1:point_prt1)=signal_PC_01(1:12);

    % s_PC_0(i_prt,point_prt1+1:point_prt1+point_prt2) = signal_PC_02(75:end); % 向量对齐
    offset2 = length(pulse2); % 获取中脉冲参考信号的实际长度
    % 从脉压结果的第 offset2 个点开始截取，截取 point_prt2 个点
    s_PC_0(i_prt, point_prt1+1 : point_prt1+point_prt2) = signal_PC_02(offset2 : offset2+point_prt2-1); % 向量对齐

    % s_PC_0(i_prt,point_prt1+point_prt2+1:point_prt) = signal_PC_03(160:end); % 向量对齐
    offset3 = length(pulse3); % 获取长脉冲参考信号的实际长度
    % 从脉压结果的第 offset3 个点开始截取，截取 point_prt3 个点
    s_PC_0(i_prt, point_prt1+point_prt2+1 : point_prt1+point_prt2+point_prt3) = signal_PC_03(offset3 : offset3+point_prt3-1); % 向量对齐


    % --- 可选的绘图功能 ---
    if show_PC == 1
        % 1. 将当前PRT的脉压结果打包成一个结构体
        plot_data.pc_signal = s_PC_0(i_prt, :);
        plot_data.prt_index = i_prt;           % 将当前循环的索引i_prt加进去
        
        % 2. 调用封装好的绘图函数，并指定绘图类型
        fun_plot_visualizations('pulse_compression', plot_data, params);
    end

end

end