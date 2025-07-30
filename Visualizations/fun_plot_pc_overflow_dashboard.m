function fun_plot_pc_overflow_dashboard(h_fig, plot_params)
% FUN_PLOT_PC_OVERFLOW_DASHBOARD - 统一的脉冲压缩数据溢出点可视化仪表盘
%
% 本函数接收累积的溢出点日志，并根据指定的绘图模式，
% 生成PPI图或距离-方位图。
%
% 输入参数:
%   h_fig       - (figure handle) 用于绘图的图窗句柄。
%   plot_params - (struct) 包含所有绘图和分析所需参数的结构体。

%% 1. 清空整个图窗并获取参数
figure(h_fig);
clf; 

plot_mode = plot_params.plot_mode;
range_to_plot = plot_params.range_to_plot;
overflow_log = plot_params.overflow_log;
beam_to_plot = plot_params.beam_to_plot;

%% 2. 根据绘图模式选择并执行绘图逻辑
switch plot_mode
    case 'ppi'
        % --- 模式A: 绘制极坐标PPI图 ---
        pax = polaraxes(h_fig);
        pax.ThetaZeroLocation = 'top';
        pax.ThetaDir = 'clockwise';
        pax.ThetaLim = [0 360];
        pax.RLim = [0 max(range_to_plot)];
        draw_overflow_points(pax, overflow_log, plot_params);
        
    case 'az_range'
        % --- 模式B: 绘制直角坐标距离-方位图 ---
        ax = axes(h_fig);
        draw_overflow_points(ax, overflow_log, plot_params);
        
    case 'summary'
        % --- 模式C: 并排显示PPI图和距离-方位图 ---

        fig1 = figure(1);
        pax = polaraxes(fig1);
        pax.ThetaZeroLocation = 'top'; pax.ThetaDir = 'clockwise';
        pax.ThetaLim = [0 360]; 
        pax.RLim = [0 max(plot_params.range_to_plot)];
        draw_overflow_points(pax, overflow_log, plot_params);
        
        fig2 = figure(2);
        ax = axes(fig2);
        draw_overflow_points(ax, overflow_log, plot_params);
        
    otherwise
        warning('未知的绘图模式: %s', plot_mode);
end

end

%% ========================================================================
% 本地绘图核心函数 (Local Helper Function)
% ========================================================================
function draw_overflow_points(ax, overflow_log, plot_params)
    % 这个函数包含了在指定坐标轴上绘制溢出点的逻辑

    % --- 1. 获取参数 ---
    plot_mode = plot_params.plot_mode;
    range_to_plot = plot_params.range_to_plot;
    beam_to_plot = plot_params.beam_to_plot;

    % --- 2. 准备数据 ---
    all_angles_deg = [overflow_log.angle_deg];
    all_ranges_bin = [overflow_log.range_bin];
    
    % --- 3. 标记溢出点 ---
    if strcmp(plot_mode, 'ppi') || (isa(ax, 'matlab.graphics.axis.PolarAxes'))
        % 如果是极坐标模式
        h_plot = polarplot(ax, deg2rad(all_angles_deg), all_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        title(ax, sprintf('累积溢出点PPI图 (波束 #%d)', beam_to_plot));
    else 
        % 如果是直角坐标模式
        h_plot = plot(ax, all_angles_deg, all_ranges_bin, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
        xlabel(ax, '方位角 (度)');
        ylabel(ax, '距离单元');
        grid(ax, 'on');
        xlim(ax, [-180, 180]);
        % ylim(ax, [0, max(range_to_plot)]);
        title(ax, sprintf('累积溢出点距离-方位图 (波束 #%d)', beam_to_plot));
    end
    
    % --- 4. 美化图形 ---
    if ~isempty(h_plot)
        legend(ax, '脉冲压缩后溢出点', 'Location', 'southoutside');
    end
end
