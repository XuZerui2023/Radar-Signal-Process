% main_cfar.m 函数文件主要用于文件处理，MTD处理后进行CFAR目标检测


clc;clear; close all;

%% 常数定义
cj = sqrt(-1);
c  =  2.99792458e8;       % 电磁波传播速度

PI2 = 2*pi;
MHz = 1e+6;            % frequency unit(MHz)
us  = 1e-6;            % time unit(us)
ns  = 1e-9;            % time unit(ns)
KHz = 1e+3;            % frequency unit(KHz)
GHz = 1e+9;            % frequency unit(GHz)

fileTotalNums = 380;   % 数据bin文件个数19*20=380
framesEachFile = 10;   % 每个新文件存储的帧数10个1536PRT

%% 系统参数
fs = 25*MHz;           % 生成原始信号的采样频率
ts = 1/fs;
deltaR = c*ts/2;
tao1  = 0.28*us;       % 脉冲1脉宽
tao2  = 3*us;          % 脉冲2脉宽
tao3  = 6.4*us;        % 脉冲3脉宽
f0=0*MHz;
fc=5500*MHz;
prt   = 64.88*us;
prf   = 1/prt;
wavelength=c/fc;
B     = 10*MHz;        % 带宽
K1    = B/tao1;        % 短脉冲调频斜率
K2    = B/tao2;        % 长脉冲调频斜率
K3    = -B/tao3;       % 长脉冲调频斜率
%% 不同的检测门限
data_path='D:\MATLAB_Project\20220420气象局楼顶基带信号采集\';
n_exp=4;

for T=[5]
    %% CFAR参数
    MTD_V = 3;    % 杂波区速度范围
    T_CFAR=T;
    % 速度维度
    refCells_V = 5;    % 速度维 参考单元数
    saveCells_V = 7;   % 速度维 保护单元数
    T_CFAR_V = T_CFAR;      % 速度维恒虚警标称化因子7
    CFARmethod_V = 0;  % 0--选大；1--选小
    % 距离维
    rCFARDetect_Flag = 1; % 距离维CFAR检测操作标志。 0-否； 1-是
    refCells_R = 5;    % 距离维 参考单元数
    saveCells_R = 7;   % 距离维 保护单元数
    T_CFAR_R = T_CFAR;      % 距离维恒虚警标称化因子7,越低，门限越低，虚警率越高
    CFARmethod_R = 0;  % 0--选大；1--选小

    deltaDoppler = prf/1536;
    deltaV = wavelength*deltaDoppler/2;
    MTD_0v_num = floor(MTD_V/deltaV);

    %% 画图参数
    graph = 1; 
    prtNum = 1536;
    point_prt = 1031;      % 3个脉冲的PRT采集点数
    R_point = 6;              % 两点间距6m
    r_axis = 0:R_point:point_prt*R_point-R_point;     % 距离轴
    fd = linspace(-prf/2,prf/2,prtNum);
    v_axis = fd*wavelength/2; % 速度轴
    v_axis = v_axis(691:845);




    %% Generate cfarflag per frame
    mkdir([data_path,num2str(n_exp),'/cfarFlag4_T',num2str(T_CFAR)])
    fileFolder = fullfile(data_path,num2str(n_exp),'\MTD_data_win4');
    dirOutput = dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
    fileNames = {dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中    
    
    tic;
    win_size=4;
    
    for frameRInd=0:1999
        load([data_path,num2str(n_exp),'\MTD_data_win4/frame_',num2str(frameRInd),'.mat']);

        for i=1:win_size
            MTD_0=squeeze(MTD_win_0(i,:,:));
            MTD_1=squeeze(MTD_win_1(i,:,:));
            MTD_0=abs(MTD_0);
            MTD_1=abs(MTD_1);
            MTD_0=fun_0v_pressing(MTD_0);
            MTD_1=fun_0v_pressing(MTD_1);
            cfarFlag_0=fun_CFARflag(MTD_0,refCells_R,saveCells_R,T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0v_num,rCFARDetect_Flag);
            cfarFlag_1=fun_CFARflag(MTD_1,refCells_R,saveCells_R,T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0v_num,rCFARDetect_Flag);
            cfarFlag_win_0(i,:,:)=cfarFlag_0;
            cfarFlag_win_1(i,:,:)=cfarFlag_1;
        end
        save([data_path,num2str(n_exp),'/cfarFlag4_T',num2str(T_CFAR),'/frame_',num2str(frameRInd),'.mat'],'cfarFlag_win_0','cfarFlag_win_1');
        frameRInd
    toc
        if(graph==1)
    
            figure(8);
            MTD_data_log= 20*log10(abs(MTD_0)/max(max(abs(MTD_0))));
            mesh(r_axis, v_axis, MTD_data_log);
            xlabel('距离');
            ylabel('速度m/s');
            zlabel('幅度dB');
            title('MTD');
    
            MTD_max=max(max(MTD_data_log));
            [vindex,rindex]=find(MTD_data_log(:,:)==MTD_max);
    
            % 画出速度维
            figure(9);
            plot(v_axis,(MTD_data_log(:,rindex)));
            xlabel('速度m/s');
            ylabel('幅度dB');
            title('速度维');
    
            % 画出距离维
            figure(11);
            plot(r_axis,(MTD_data_log(vindex,:)));
            xlabel('距离');
            ylabel('幅度dB');
            title('距离维');
    
            %CFAR检测结果
            figure(12);
            imagesc(r_axis,v_axis,cfarFlag_0);
            colormap(gca,jet);
            % colorbar;
    
            pause(1)
    
    
        end
    
    end

end

function [cfarFlag]=fun_CFARflag(MTD_data,refCells_R,saveCells_R,T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag)
    MTD_p0=MTD_data(:,1:82);
    MTD_p1=MTD_data(:,83:318);
    MTD_p2=MTD_data(:,319:868);

    [cfar_0,cfarResultFlag_MatrixV_0] = executeCFAR(MTD_p0,refCells_R,saveCells_R,...
            T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 0脉冲

    [cfar_1,cfarResultFlag_MatrixV_1] = executeCFAR(MTD_p1,refCells_R,saveCells_R,...
            T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 0脉冲

    [cfar_2,cfarResultFlag_MatrixV_2] = executeCFAR(MTD_p2,refCells_R,saveCells_R,...
            T_CFAR_R,CFARmethod_R,refCells_V,saveCells_V,T_CFAR_V,CFARmethod_V,MTD_0_num,rCFARDetect_Flag);  % 0脉冲

    cfarFlag=zeros(size(MTD_data));
    cfarFlag(:,1:82)=cfar_0;
    cfarFlag(:,83:318)=cfar_1;
    cfarFlag(:,319:868)=cfar_2;

end

function [fa]=fun_frame_fa(cfarFlag,R_True,V_True,R_True_index,V_True_index)
[m,n]=size(cfarFlag);
if((abs(V_True)>3)&&(abs(V_True)<20)&&(R_True>400)&&((R_True<2000)))
    cfarFlag_temp=cfarFlag;
    cfarFlag_temp(V_True_index-3:V_True_index+3,R_True_index-7:R_True_index+7)=0;
    n_p_1_0=sum(sum(cfarFlag_temp));
    n_p_0_0=m*n-n_p_1_0;
else
    n_p_1_0=sum(sum(cfarFlag));
    n_p_0_0=m*n-n_p_1_0;
end
fa=n_p_1_0/(n_p_1_0+n_p_0_0);
end

function [drate]=fun_drate(cfarFlag_all,R,V,r_axis,v_axis,frameRInds)
n_p_1_1=0;n_p_0_1=0;
for i=1:length(cfarFlag_all)
    frameRInd=frameRInds(i);
    cfarFlag(:,:)=cfarFlag_all(i,:,:);
    R_True=R(frameRInd);V_True=V(frameRInd);
    R_True_index=find(min(abs(r_axis-R_True))==abs(r_axis-R_True));
    V_True_index=find(min(abs(v_axis-V_True))==abs(v_axis-V_True));
    
    if((abs(V_True)>3)&&(abs(V_True)<20)&&(R_True>400)&&((R_True<2000)))
        
        t=sum(sum(cfarFlag(V_True_index-3:V_True_index+3,R_True_index-7:R_True_index+7)));
%         cfarFlag_True=zeros(size(cfarFlag));
%         cfarFlag_True([V_True_index-3,V_True_index+3],R_True_index-7:R_True_index+7)=1;
%         cfarFlag_True(V_True_index-3:V_True_index+3,[R_True_index-7,R_True_index+7])=1;
%         figure(13);
%         imagesc(r_axis,v_axis,cfarFlag+cfarFlag_True);
%         colormap(gca,jet);
%         colorbar;
        
        if(t>0)
            n_p_1_1=n_p_1_1+1;
        end
        if(t==0)
            n_p_0_1=n_p_0_1+1;
        end
    end
end
drate=n_p_1_1/(n_p_1_1+n_p_0_1);
end

function [acc]=fun_accuracy(cfarFlag_all,R,V,r_axis,v_axis,frameRInds)
n_p_1_1=0;n_p_0_0=0;
for i=1:length(cfarFlag_all)
    frameRInd=frameRInds(i);
    cfarFlag(:,:)=cfarFlag_all(i,:,:);
    R_True=R(frameRInd);V_True=V(frameRInd);
    R_True_index=find(min(abs(r_axis-R_True))==abs(r_axis-R_True));
    V_True_index=find(min(abs(v_axis-V_True))==abs(v_axis-V_True));
    
    if((abs(V_True)>3)&&(abs(V_True)<20)&&(R_True>400)&&((R_True<2000)))
        
        t=sum(sum(cfarFlag(V_True_index-3:V_True_index+3,R_True_index-7:R_True_index+7)));
        if(t>0)
            n_p_1_1=n_p_1_1+1;
        end
    else
        t=sum(sum(cfarFlag(:,:)));
        if(t>0)
            n_p_0_0=n_p_0_0+1;
        end
    end
    
    
end
acc=(n_p_1_1+n_p_0_0)/length(cfarFlag_all);

end

function [pof]=fun_PCF(cfarFlag_all,R,V,r_axis,v_axis,frameRInds,MTD_data_all)
dv_base=1/0.2719;dr_base=30/6;cnt=0;pof_list=[];
for i=1:length(cfarFlag_all)
    frameRInd=frameRInds(i);
    MTD_data(:,:)=MTD_data_all(i,:,:);
    cfarFlag(:,:)=cfarFlag_all(i,:,:);
    R_True=R(frameRInd);V_True=V(frameRInd);
    R_True_index=find(min(abs(r_axis-R_True))==abs(r_axis-R_True));
    V_True_index=find(min(abs(v_axis-V_True))==abs(v_axis-V_True));

    if((abs(V_True)>3)&&(abs(V_True)<20)&&(R_True>400)&&((R_True<2000)))
        n_cell=20;
        if(V_True_index-n_cell<1)
           V_range=[1:V_True_index+n_cell];R_range=[R_True_index-n_cell:R_True_index+n_cell];  
        elseif(V_True_index+n_cell>155)
            V_range=[V_True_index-n_cell:155];R_range=[R_True_index-n_cell:R_True_index+n_cell];
        elseif(R_True_index-n_cell<1)    
            V_range=[V_True_index-n_cell:V_True_index+n_cell];R_range=[1:R_True_index+n_cell];
        elseif(R_True_index+n_cell>288)           
            V_range=[V_True_index-n_cell:V_True_index+n_cell];R_range=[R_True_index-n_cell:288];    
        else        
            V_range=[V_True_index-n_cell:V_True_index+n_cell];R_range=[R_True_index-n_cell:R_True_index+n_cell];
        end
        t=sum(sum(cfarFlag(V_range,R_range)));
        if(t>0)
        local_max=max(max(MTD_data(V_range,R_range)));
        [v_ind,r_ind]=find(local_max==MTD_data);

        dv=abs(V_True_index-v_ind);dr=abs(R_True_index-r_ind);
        l=dv^2+dr^2;
        l_base=dv_base^2+dr_base^2;
        if(l<l_base)
            pof=1-l/l_base;
        else
            pof=exp(1-l/l_base)-1;
        end
        cnt=cnt+1;
        pof_list(cnt)=pof;

        end
    end
end
pof=sum(pof_list)/length(pof_list);
end
