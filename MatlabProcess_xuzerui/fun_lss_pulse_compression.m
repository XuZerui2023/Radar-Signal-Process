% 多脉冲压缩

function s_PC_0=fun_lss_pulse_compression(echoData_Frame_0,show_PC,pulse1,pulse2,pulse3)


point_prt1 = 82;    %1脉冲prt点数
point_prt2 = 242;    %2脉冲prt点数   
point_prt3=707;     %3脉冲prt点数  

%将三个脉冲分开
[m,n]=size(echoData_Frame_0);
prtNum=m;
point_prt=n;
signal_01=echoData_Frame_0(:,1:point_prt1);%1-82
signal_02=echoData_Frame_0(:,point_prt1+1:point_prt1+point_prt2);%83-324
signal_03=echoData_Frame_0(:,point_prt1+point_prt2+1:point_prt);%325-1031

s_PC_0=zeros(prtNum,point_prt);%脉冲压缩后再合到一起

%FIR滤波器系数
filter_coef = [-9,-7,-2,10,27,40,42,24,-13,-57,-89,-86,-30,77,220,364,471,511,471,364,220,77,-30,-86,-89,-57,-13,24,42,40,27,10,-2,-7,-9];
filter_coef =filter_coef /max(filter_coef );
%脉冲压缩
for i_prt=1:prtNum
signal_PC_01 = filter(filter_coef,1,signal_01(i_prt,:).').';%窄脉冲作fir滤波
signal_PC_01 = signal_PC_01/1.2;

signal_PC_02=fun_pulse_compression(pulse2,signal_02(i_prt,:));%中脉冲压缩
signal_PC_03=fun_pulse_compression(pulse3,signal_03(i_prt,:));%长脉冲压缩

s_PC_0(i_prt,1:point_prt1)=signal_PC_01(1:point_prt1);%%向量对齐
%pluse1采用filter进行脉压，结果总是会导致尖峰比实际位置延后12个点，所以就将输出前移12点
% s_PC_0(i_prt,1:point_prt1-12)=signal_PC_01(13:point_prt1);
% s_PC_0(i_prt,point_prt1-12+1:point_prt1)=signal_PC_01(1:12);

s_PC_0(i_prt,point_prt1+1:point_prt1+point_prt2)=signal_PC_02(75:end);%向量对齐
s_PC_0(i_prt,point_prt1+point_prt2+1:point_prt)=signal_PC_03(160:end);%向量对齐


    if show_PC==1
    figure(5)
    plot(20*log10(abs(s_PC_0(i_prt,:)))),title('脉压');
    pause(0.05)
    end
end



end