
function fun_plot_visualizations(plot_type, data, params)
% FUN_PLOT_VISUALIZATIONS - 集中管理所有绘图功能的函数
%
% 输入参数:
%   plot_type - (string) 指定要绘制的图形类型。
%               可选值: 'pulse_compression', 'fft_dynamic', 'mtd_3d'
%   data      - (struct) 包含绘图所需数据的结构体。
%   params    - (struct) 包含绘图所需参数的结构体。

switch plot_type
    case 'pulse_compression'
        % 调用本地函数绘制脉冲压缩的动态图
        plot_pulse_compression_dynamic(data.pc_signal,data.prt_index,params);
        
    case 'fft_dynamic'
        % 调用本地函数绘制速度维FFT的动态图
        plot_fft_dynamic(data.mtd_signal);
        
    case 'mtd_3d'
        % 调用本地函数绘制最终的MTD三维图
        plot_mtd_3d(data.mtd_signal, params);
        
    otherwise
        warning('未知的绘图类型: %s', plot_type);
end

end


% --- 本地子函数 ---

function plot_pulse_compression_dynamic(pc_signal, prt_index, params)
    % 动态展示单个PRT的脉冲压缩结果
    
    % --- 从params结构体中获取当前帧编号 ---
    current_frame = params.current_frame;

    figure(5);
    plot(20*log10(abs(pc_signal) + 1e-6));
    
    % --- 更新标题，同时显示帧号和PRT号 ---
    title(sprintf('帧 #%d, PRT #%d 的脉冲压缩结果', current_frame, prt_index));
    
    xlabel('距离单元');
    ylabel('幅度 (dB)');
    grid on;
    pause(0.05);
end

function plot_fft_dynamic(mtd_signal)
    % 动态展示单个距离单元的速度维FFT结果
    [~, num_range_bins] = size(mtd_signal);
    for i = 1:num_range_bins
        figure(2);
        plot(20 * log10(abs(mtd_signal(:, i)) + 1e-6));
        title(['距离单元 ', num2str(i), ' 的多普勒频谱']);
        xlabel('速度单元');
        ylabel('幅度 (dB)');
        grid on;
        pause(0.05);
    end
end


function plot_mtd_3d(mtd_signal, sys_params)
    % 绘制最终的速度-距离-幅度三维图
    
    % --- 从参数结构体中获取所需参数 ---
    prf = sys_params.prf;
    wavelength = sys_params.wavelength;
    deltaR = sys_params.deltaR;
    [num_vel_bins, num_range_bins] = size(mtd_signal);

    % --- 计算物理坐标轴 ---
    % 距离轴 (m)
    r_axis = (0:num_range_bins-1) * deltaR;
    % 速度轴 (m/s)
    v_axis = linspace(-prf/2, prf/2, num_vel_bins) * wavelength / 2;
    
    % --- 数据归一化和对数化 ---
    max_val = max(mtd_signal(:));
    if max_val == 0, max_val = 1; end % 避免除以0
    mtd_log = 20 * log10(mtd_signal / max_val + 1e-6);

    % --- 绘图 ---
    figure(3);
    mesh(r_axis, v_axis, mtd_log);
    
    % --- 美化图形 ---
    xlabel('距离 (m)');
    ylabel('速度 (m/s)');
    zlabel('归一化幅度 (dB)');
    title('速度-距离-幅度图 (RDM)');
    colorbar; % 显示颜色条
    view(3);  % 设置为三维视角
    grid on;
end









