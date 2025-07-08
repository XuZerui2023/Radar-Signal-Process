% main_cfar.m
% 本脚本是CFAR目标检测的主流程控制文件。
% 它负责加载经过MTD处理后的数据，配置并执行CFAR检测算法，
% 最终生成目标的检测标志矩阵，并包含了性能评估和可视化的功能。

clc;clear; close all;

%% 1. 参数定义
% 1.1 常数定义
cj = sqrt(-1);
c  =  2.99792458e8;       % 电磁波传播速度
PI2 = 2*pi;
MHz = 1e+6;               % frequency unit(MHz)
us  = 1e-6;               % time unit(us)
ns  = 1e-9;               % time unit(ns)
KHz = 1e+3;               % frequency unit(KHz)
GHz = 1e+9;               % frequency unit(GHz)

%fileTotalNums = 380;     % 数据bin文件个数19*20=380
%framesEachFile = 10;     % 每个新文件存储的帧数10个1536PRT

% 1.2 雷达系统参数
params.prtNum = 332;      % 每帧信号的脉冲数
params.prt = 232.76e-6;   % 脉冲重复时间 (s)
params.beam_num = 13;     % 雷达波束数量
params.fs = 25e6;         % 原始信号采样频率 (Hz)
params.fc = 9450e6;       % 中心频率 (Hz)
params.B = 20e6;          % 带宽 (Hz)
params.tao = [0.16e-6, 8e-6, 28e-6];        % 脉宽 [窄, 中, 长]
params.point_prt = [3404, 228, 723, 2453];  % 采集点数 [总采集点数，窄脉冲采集点数，中脉冲采集点数，长脉冲采集点数]   

f0 = 0*MHz;               % 零频
ts = 1/params.fs;
deltaR = c*ts/2;
prf  = 1/params.prt;
tao1 = params.tao(1);     % 窄脉宽 
tao2 = params.tao(2);     % 中脉宽
tao3 = params.tao(3);     % 长脉宽
K1   = params.B/tao1;     % 短脉冲调频斜率
K2   = -params.B/tao2;    % 中脉冲调频斜率
K3   = params.B/tao3;     % 长脉冲调频斜率
wavelength = c/params.fc; % 信号波长

% 1.3 实验数据路径
base_path = 'D:\MATLAB_Project\X3D8K DMX回波模拟状态采集数据250520\X3D8K DMX回波模拟状态采集数据250520\X8数据采集250522\';
n_exp = 1;
win_size = 4;

%% 2. CFAR处理参数设置

for T = [5]               % 通过循环测试不同的门限因子T
    % --- CFAR核心参数 ---
    MTD_V = 3;            % 杂波区速度范围，速度在 -3 m/s 到 +3 m/s 范围内的区域都当作是地杂波区域，在CFAR检测中忽略掉。
    T_CFAR = T;           % 门限因子
    
    % --- 速度维参数 ---
    refCells_V = 5;       % 速度维 参考单元数
    saveCells_V = 7;      % 速度维 保护单元数
    T_CFAR_V = T_CFAR;    % 速度维恒虚警标称化因子
    CFARmethod_V = 0;     % 噪声估计：0--选大；1--选小
    
    % --- 距离维参数 ---
    rCFARDetect_Flag = 1; % 距离维CFAR检测操作标志。 0-否； 1-是
    refCells_R = 5;       % 距离维 参考单元数
    saveCells_R = 7;      % 距离维 保护单元数
    T_CFAR_R = T_CFAR;    % 距离维恒虚警标称化因子7,越低，门限越低，虚警率越高
    CFARmethod_R = 0;     % 0--选大；1--选小
    
    % --- 计算杂波区对应的速度单元数 ---
    deltaDoppler = prf/params.prtNum;     % 计算多普勒频率分辨率
    deltaV = wavelength*deltaDoppler/2;   % 计算速度分辨率：计算出了一个频率单元（deltaDoppler）等效于多少米/秒（m/s）的速度。这个 deltaV 就是雷达能分辨的最小速度差。
    MTD_0v_num = floor(MTD_V/deltaV);     % 计算杂波区的宽度（以单元数计），在进行CFAR检测时，需要以零速为中心，向两侧各跳过 MTD_0v_num 个速度单元，以避开强大的地杂波对噪声估计的干扰。

    % --- 画图参数（绘图坐标轴参数）---
    graph = 0; 
    prtNum = params.prtNum;           % 每帧信号prt数量
    point_prt = params.point_prt(1);  % 3个脉冲的PRT采集点数
    R_point = 6;                      % 每个距离单元长度（两点间距6m）
    r_axis = 0:R_point:point_prt*R_point-R_point; % 距离轴
    fd = linspace(-prf/2,prf/2,prtNum);
    v_axis = fd*wavelength/2;                     % 速度轴
    % v_axis = v_axis(691:845);
    
    % CFAR 参数
    CFAR_params.refCells_R = refCells_R;
    CFAR_params.saveCells_R = saveCells_R;
    CFAR_params.T_CFAR_R = T_CFAR_R;
    CFAR_params.CFARmethod_R = CFARmethod_R;
    CFAR_params.refCells_V = refCells_V;
    CFAR_params.saveCells_V = saveCells_V;
    CFAR_params.T_CFAR_V = T_CFAR_V;
    CFAR_params.CFARmethod_V = CFARmethod_V;
    CFAR_params.MTD_0v_num = MTD_0v_num;
    CFAR_params.rCFARDetect_Flag = rCFARDetect_Flag;

    %% 3. 主处理流程 
    % --- 创建输出目录 ---
    mkdir([base_path, num2str(n_exp), '/cfarFlag4_T',num2str(T_CFAR)]);
    % --- 获取MTD数据文件列表 ---
    fileFolder = fullfile(base_path,num2str(n_exp),'\MTD_data_win4');
    dirOutput = dir(fullfile(fileFolder,'*.mat')); %引号内是文件的后缀，写'.png'则读取后缀为'.png'的文件
    fileNames = {dirOutput.name}; %将所有文件名，以矩阵形式按行排列，保存到fileNames中    
    
    tic;
    % frameRInd = 1; 测试用
    % 循环体处理流程：帧 -> 波束 -> 切片
    for frameRInd = 0:139 
        % 加载已生成的MTD数据
        load([base_path,num2str(n_exp),'\MTD_data_win4/frame_',num2str(frameRInd),'.mat']);
        % 遍历每一个雷达信号波束
        for b = 1:params.beam_num 
            MTD_win_single_beam = MTD_win_all_beams{b};
        
            % 对每个数据切片都进行CFAR处理
            for i = 1:win_size
                MTD_win_single_beam_single_slice = squeeze(MTD_win_single_beam(i,:,:));
                MTD_temp = abs(MTD_win_single_beam_single_slice);

                % 进行零速抑制
                MTD_temp = fun_0v_pressing(MTD_temp);

                % 调用本地CFAR处理函数 
                cfarFlag_temp = fun_CFARflag(MTD_temp,CFAR_params);
                cfarFlag_win_temp(i,:,:) = cfarFlag_temp;
            
            end
           
            cfarFlag_win_all_beams{b} = cfarFlag_win_temp;
        end
        % 将当前帧所有切片的CFAR结果保存到文件
        save([base_path,num2str(n_exp),'/cfarFlag4_T',num2str(T_CFAR),'/frame_',num2str(frameRInd),'.mat'],'cfarFlag_win_all_beams');   
        fprintf('第 %d 帧CFAR处理完成', frameRInd);
        toc;
        
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

%% 本地子函数定义

function [cfarFlag] = fun_CFARflag(MTD_data,CFAR_params)
    % 按雷达信号波形窄中长三脉冲重新划分
    MTD_p0 = MTD_data(:,1:228);
    MTD_p1 = MTD_data(:,229:951);
    MTD_p2 = MTD_data(:,952:3404);

    [cfar_0,cfarResultFlag_MatrixV_0] = executeCFAR(MTD_p0,CFAR_params);  % 0脉冲

    [cfar_1,cfarResultFlag_MatrixV_1] = executeCFAR(MTD_p1,CFAR_params);  % 0脉冲

    [cfar_2,cfarResultFlag_MatrixV_2] = executeCFAR(MTD_p2,CFAR_params);  % 0脉冲

    cfarFlag=zeros(size(MTD_data));
    cfarFlag(:,1:228) = cfar_0;
    cfarFlag(:,229:951) = cfar_1;
    cfarFlag(:,952:3404) = cfar_2;

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
