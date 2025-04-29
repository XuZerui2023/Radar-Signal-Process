%% 该函数 fun_SCR.m 用于控制仿真目标回波的信杂比（SCR, Signal-to-Clutter Ratio）
% fun_SCR  控制无噪回波的幅度，使其符合设定的SCR
% 
% 输入：
%   prtNum - 每帧的脉冲数
%   Echo_simu - 目标回波信号
%   echoData_Frame_0 - 实测的雷达回波数据
%   SCR - 设定的信杂比（Signal-to-Clutter Ratio）
%
% 输出：
%   Echo_simu - 经过SCR调整后的仿真目标回波信号

%% 测试，不测试时请注释该段代码
% SCR=10;

%%

function Echo_simu = fun_SCR(prtNum,Echo_simu,echoData_Frame_0,SCR)%无噪回波幅度控制
point_prt1 = 82;    % 脉冲1 区间点数
point_prt2 = 242;   % 脉冲2 区间点数    
point_prt3 = 707;     % 脉冲3 区间点数    

SCRs=[10^((SCR+10)/10),10^(SCR/10),10^((SCR)/10)];
points1=[1:point_prt1];
points2=[point_prt1+1:point_prt1+point_prt2];
points3=[point_prt1+point_prt2+1:point_prt1+point_prt2+point_prt3];


SCR_=SCRs(1);
points=points1;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%需要的信号功率
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end
    
    
SCR_=SCRs(2);
points=points2;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%需要的信号功率
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end    
    
    
SCR_=SCRs(3);
points=points3;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%需要的信号功率
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end    
        
    
end