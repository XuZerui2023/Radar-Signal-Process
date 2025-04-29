function signal_PC=fun_pulse_compression(s0,s_echo)

%匹配滤波
h=conj(s0(1,end:-1:1));         %匹配滤波器的的冲激响应函数
[m,n]=size(h);
point_pulse=n;

%加窗
% hamm=hamming(point_pulse)';%生成海明窗
% h=h.*hamm;
% kaisa=kaiser(point_pulse,20)';
% h=h.*kaisa;

[m,n]=size(s_echo);
point_prt=n;
point_signal_PC=point_pulse+point_prt-1;            %滤波相当于回波信号与匹配滤波器两者卷积，YN为卷积后的点数

%利用FFT实现快速卷积
S=fft(s_echo,point_signal_PC);                     %分别求出s(t)和h(t)的频谱
H=fft(h,point_signal_PC);
Y=S.*H;                          %频域相乘即为时域卷积
y=ifft(Y,point_signal_PC);                    %对频域乘积做傅里叶反变换，求时域信号即为匹配滤波器作用后的输出
signal_PC=y;
end




