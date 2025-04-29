%% �ú��� fun_SCR.m ���ڿ��Ʒ���Ŀ��ز������ӱȣ�SCR, Signal-to-Clutter Ratio��
% fun_SCR  ��������ز��ķ��ȣ�ʹ������趨��SCR
% 
% ���룺
%   prtNum - ÿ֡��������
%   Echo_simu - Ŀ��ز��ź�
%   echoData_Frame_0 - ʵ����״�ز�����
%   SCR - �趨�����ӱȣ�Signal-to-Clutter Ratio��
%
% �����
%   Echo_simu - ����SCR������ķ���Ŀ��ز��ź�

%% ���ԣ�������ʱ��ע�͸öδ���
% SCR=10;

%%

function Echo_simu = fun_SCR(prtNum,Echo_simu,echoData_Frame_0,SCR)%����ز����ȿ���
point_prt1 = 82;    % ����1 �������
point_prt2 = 242;   % ����2 �������    
point_prt3 = 707;     % ����3 �������    

SCRs=[10^((SCR+10)/10),10^(SCR/10),10^((SCR)/10)];
points1=[1:point_prt1];
points2=[point_prt1+1:point_prt1+point_prt2];
points3=[point_prt1+point_prt2+1:point_prt1+point_prt2+point_prt3];


SCR_=SCRs(1);
points=points1;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%��Ҫ���źŹ���
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end
    
    
SCR_=SCRs(2);
points=points2;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%��Ҫ���źŹ���
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end    
    
    
SCR_=SCRs(3);
points=points3;
P_s=mean(Echo_simu(1,points).^2)+eps;
    for i=1:prtNum
        P_echo=mean(echoData_Frame_0(i,points).^2);
        P_s_need= P_echo*SCR_;%��Ҫ���źŹ���
        g=P_s_need/P_s;
        Echo_simu(i,points)= Echo_simu(i,points)*sqrt(g);
    end    
        
    
end