function fun_plot_cfar_dashboard_v1(mtd_signal, cfar_flag, sys_params)
% FUN_PLOT_CFAR_DASHBOARD - 创建一个MTD和CFAR结果的综合分析仪表盘
%
% 本函数在一个窗口中通过四个子图对MTD处理结果和CFAR检测结果进行可视化。
%
% 输入参数:
%   mtd_signal  - (double matrix) 单个切片的二维速度-距离矩阵。
%   cfar_flag   - (logical matrix) 与mtd_signal对应的CFAR检测结果(0-1矩阵)。
%   sys_params  - (struct) 包含雷达系统参数的结构体。

%% 1. 数据准备和参数获取
% --- 从参数结构体中获取绘图所需参数 ---
prf = sys_params.prf;
wavelength = sys_params.wavelength;
deltaR = sys_params.deltaR;
frame_to_load = sys_params.frame_to_load;
beam_to_plot = sys_params.beam_to_plot;
slice_to_plot = sys_params.slice_to_plot;

[num_vel_bins, num_range_bins] = size(mtd_signal);

% --- 数据归一化和对数化 ---
mtd_abs = abs(mtd_signal);
max_val = max(mtd_abs(:));
if max_val == 0, max_val = 1; end
mtd_log = 20 * log10(mtd_abs / max_val + 1e-9);

% --- 计算物理坐标轴 ---
r_axis = (0:num_range_bins-1) * deltaR;
v_axis = linspace(-prf/2, prf/2, num_vel_bins) * wavelength / 2;

% --- 从CFAR结果中找到最强的目标点用于切片分析 ---
% 将CFAR检测到的目标点位置的MTD信号强度提取出来
detected_signals = mtd_abs .* cfar_flag;
[peak_signal_val, peak_idx] = max(detected_signals(:));

if peak_signal_val > 0
    % 如果有检测到的目标，则以最强目标为中心进行切片
    [peak_vel_idx, peak_range_idx] = ind2sub(size(mtd_abs), peak_idx);
else
    % 如果没有检测到目标，则以整个画面的最强点为中心进行切片
    [~, peak_idx] = max(mtd_abs(:));
    [peak_vel_idx, peak_range_idx] = ind2sub(size(mtd_abs), peak_idx);
end
peak_range = r_axis(peak_range_idx);
peak_velocity = v_axis(peak_vel_idx);


%% 2. 创建并绘制四个子图
fig_title = sprintf('MTD与CFAR分析仪表盘 (帧 #%d, 波束 #%d, 切片 #%d)', ...
                    sys_params.frame_to_load, sys_params.beam_to_plot, sys_params.slice_to_plot);
figure('Name', fig_title, 'NumberTitle', 'off', 'Position', [100, 100, 1200, 800]);

% --- 子图 1: 3D MTD视图 ---
subplot(2, 2, 1);
mesh(r_axis, v_axis, mtd_log);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
zlabel('归一化幅度 (dB)');
title('3D 速度-距离图');
grid on; view(3);

% --- 子图 2: 2D RDM 及 CFAR检测结果 ---
subplot(2, 2, 2);
% imagesc(r_axis, v_axis, mtd_log);
% colorbar; 
axis xy;
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title('2D RDM 及 CFAR检测点');
hold on;
% 寻找所有CFAR检测点并用红色'+'标记
[detected_v_indices, detected_r_indices] = find(cfar_flag);
detected_ranges = r_axis(detected_r_indices);
detected_velocities = v_axis(detected_v_indices);
plot(detected_ranges, detected_velocities, 'r+', 'MarkerSize', 8);
hold off;

% --- 子图 3: 速度维切片 ---
subplot(2, 2, 3);
plot(v_axis, mtd_log(:, peak_range_idx));
grid on;
xlabel('速度 (m/s)');
ylabel('归一化幅度 (dB)');
title(sprintf('速度维切片 @ 距离 = %.2f m', peak_range));
hold on;
xline(peak_velocity, '--r', sprintf('峰值 @ %.2f m/s', peak_velocity));
hold off;

% --- 子图 4: 距离维切片 ---
subplot(2, 2, 4);
plot(r_axis, mtd_log(peak_vel_idx, :));
grid on;
xlabel('距离 (m)');
ylabel('归一化幅度 (dB)');
title(sprintf('距离维切片 @ 速度 = %.2f m/s', peak_velocity));
hold on;
xline(peak_range, '--r', sprintf('峰值 @ %.2f m', peak_range));
hold off;

end
