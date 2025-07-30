function fun_plot_combined_az_range(h_fig, detection_log, overflow_log, params)
% FUN_PLOT_COMBINED_AZ_RANGE - 在同一张图上绘制CFAR检测点和溢出点
%
% 本函数接收CFAR目标日志和溢出点日志，并将它们同时绘制在一个
% 直角坐标系的距离-方位图上，用不同的符号和颜色进行区分。
%
% 输入参数:
%   h_fig         - (figure handle) 用于绘图的图窗句柄。
%   detection_log - (struct array) 累积的CFAR目标检测日志。
%   overflow_log  - (struct array) 累积的信号溢出点日志。
%   params        - (struct) 包含角度修正等参数的结构体。

%% 1. 准备绘图环境
figure(h_fig);
ax = axes(h_fig);
hold(ax, 'on'); % 关键步骤：保持坐标轴，以便叠加绘图
grid(ax, 'on');

%% 2. 绘制CFAR目标检测点
if ~isempty(detection_log)
    % 初始化
    azimuths_cfar = [];
    ranges_cfar = [];
    snr_cfar = [];

    for i = 1 : length(detection_log)
        % CFAR日志中的方位角是修正后伺服角值
        azimuths_cfar_i = [detection_log(i).Goal_Para_Frame.fAmuAngle];

        % --- 提取距离和SNR ---
        ranges_cfar_i = [detection_log(i).Goal_Para_Frame.fRange];
        snr_cfar_i = [detection_log(i).Goal_Para_Frame.fSnr];
        
        azimuths_cfar = [azimuths_cfar, azimuths_cfar_i];
        ranges_cfar = [ranges_cfar, ranges_cfar_i];
        %snr_cfar = [snr_cfar, snr_cfar_i];
    end

    % --- 绘制散点图 ---
    % 使用蓝色的圆圈 'o' 表示CFAR检测点
    % 点的大小映射到其信噪比(SNR)，SNR越高的点越大
    h_cfar = scatter(ax, azimuths_cfar, ranges_cfar, 'b', 'o', 'filled', 'MarkerFaceAlpha', 0.6);
end

%% 3. 绘制信号溢出点
if ~isempty(overflow_log)
    % --- 提取并修正溢出点的角度 ---
    % 假设溢出点日志中的角度已经是修正后的
    corrected_azimuths_overflow = [overflow_log.angle_deg];
    
    % --- 提取距离单元 ---
    ranges_overflow = [overflow_log.range_bin]; % 注意：这里是距离单元
    
    % --- 绘制散点图 ---
    % 使用红色的叉 'x' 表示溢出点
    h_overflow = plot(ax, corrected_azimuths_overflow, ranges_overflow, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
end

%% 4. 美化图形
xlabel(ax, '方位角 (度)');
ylabel(ax, '距离 (m 或 距离单元)');
title(ax, 'CFAR目标检测点 vs. 脉冲压缩后信号溢出点');
xlim(ax, [-180, 180]);

% --- 创建图例 ---
legend_handles = [];
legend_texts = {};
if exist('h_cfar', 'var') && ~isempty(h_cfar)
    legend_handles(end+1) = h_cfar;
    legend_texts{end+1} = 'CFAR 检测目标 (大小与SNR相关)';
end
if exist('h_overflow', 'var') && ~isempty(h_overflow)
    legend_handles(end+1) = h_overflow;
    legend_texts{end+1} = '信号溢出点';
end

if ~isempty(legend_handles)
    legend(ax, legend_handles, legend_texts, 'Location', 'southoutside');
end

hold(ax, 'off');

end
