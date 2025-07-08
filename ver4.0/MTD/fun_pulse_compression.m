% 该函数是对中脉冲和长脉冲信号进行匹配滤波脉冲压缩
% 输入参数:
%   s0     - (1xN double/complex) 发射信号的参考波形，用于生成匹配滤波器。
%            N是参考波形的采样点数。
%   s_echo - (1xM double/complex) 单个PRT接收到的原始回波信号。
%            M是回波信号的采样点数。
% 输出参数:
%   signal_PC - (1x(N+M-1) double/complex) 经过脉冲压缩后的输出信号。
%
function signal_PC = fun_pulse_compression(s0, s_echo)

% 1. 生成匹配滤波器
h = conj(s0(1,end:-1:1));   % 匹配滤波器的的冲激响应函数，end:-1:1 实现序列翻转，conj() 实现复共轭。                   
[~, point_pulse] = size(h); % 获取参考脉冲（即匹配滤波器冲激响应）的长度  

% 加窗
% 加窗可以降低脉冲压缩后信号的峰值旁瓣比（PSLR），但会轻微展宽主瓣，并带来一定的信噪比损失。
% hamm = hamming(point_pulse)';     % 生成汉明窗
% h = h.*hamm;
% kaise = kaiser(point_pulse,20)';  % 生成凯塞尔窗
% h = h.*kaisa;

% 2. 设置FFT参数以实现线性卷积
[~, point_prt] = size(s_echo);      % 获取回波信号的长度

point_signal_PC = point_pulse + point_prt - 1;  % 滤波相当于回波信号与匹配滤波器两者卷积，两个长度分别为N和M的序列，其线性卷积结果的长度为 N+M-1。这是为了避免FFT计算循环卷积而出错。


% 3. 利用FFT实现快速卷积（匹配滤波）
% 分别求出s(t)和h(t)的频谱
S = fft(s_echo, point_signal_PC);   % 对回波信号 s_echo 进行FFT，并补零到最终卷积结果的长度。
H = fft(h, point_signal_PC);        % 对匹配滤波器的冲激响应 h 进行FFT，同样补零。

Y = S.*H;                           % 频域相乘相当于时域卷积
y = ifft(Y,point_signal_PC);        % 将频域相乘的结果通过逆FFT(ifft)变换回时域，得到最终的卷积结果。

signal_PC = y;

end




