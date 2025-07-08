% �ú����Ƕ�������ͳ������źŽ���ƥ���˲�����ѹ��
% �������:
%   s0     - (1xN double/complex) �����źŵĲο����Σ���������ƥ���˲�����
%            N�ǲο����εĲ���������
%   s_echo - (1xM double/complex) ����PRT���յ���ԭʼ�ز��źš�
%            M�ǻز��źŵĲ���������
% �������:
%   signal_PC - (1x(N+M-1) double/complex) ��������ѹ���������źš�
%
function signal_PC = fun_pulse_compression(s0, s_echo)

% 1. ����ƥ���˲���
h = conj(s0(1,end:-1:1));   % ƥ���˲����ĵĳ弤��Ӧ������end:-1:1 ʵ�����з�ת��conj() ʵ�ָ����                   
[~, point_pulse] = size(h); % ��ȡ�ο����壨��ƥ���˲����弤��Ӧ���ĳ���  

% �Ӵ�
% �Ӵ����Խ�������ѹ�����źŵķ�ֵ�԰�ȣ�PSLR����������΢չ�����꣬������һ�����������ʧ��
% hamm = hamming(point_pulse)';     % ���ɺ�����
% h = h.*hamm;
% kaise = kaiser(point_pulse,20)';  % ���ɿ�������
% h = h.*kaisa;

% 2. ����FFT������ʵ�����Ծ��
[~, point_prt] = size(s_echo);      % ��ȡ�ز��źŵĳ���

point_signal_PC = point_pulse + point_prt - 1;  % �˲��൱�ڻز��ź���ƥ���˲������߾�����������ȷֱ�ΪN��M�����У������Ծ������ĳ���Ϊ N+M-1������Ϊ�˱���FFT����ѭ�����������


% 3. ����FFTʵ�ֿ��پ����ƥ���˲���
% �ֱ����s(t)��h(t)��Ƶ��
S = fft(s_echo, point_signal_PC);   % �Իز��ź� s_echo ����FFT�������㵽���վ������ĳ��ȡ�
H = fft(h, point_signal_PC);        % ��ƥ���˲����ĳ弤��Ӧ h ����FFT��ͬ�����㡣

Y = S.*H;                           % Ƶ������൱��ʱ����
y = ifft(Y,point_signal_PC);        % ��Ƶ����˵Ľ��ͨ����FFT(ifft)�任��ʱ�򣬵õ����յľ�������

signal_PC = y;

end




