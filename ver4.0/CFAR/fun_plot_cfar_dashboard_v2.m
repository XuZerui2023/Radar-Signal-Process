% FUN_PLOT_CFAR_DASHBOARD - 创建一个MTD和CFAR结果的综合分析仪表盘 (v2)
%
% v2更新：接收一个figure句柄h_fig，并在指定的窗口上进行绘图，而不是创建新窗口。
%
% 输入参数:
%   h_fig       - (figure handle) 用于绘图的图窗句柄。
%   mtd_signal  - (double matrix) 单个切片的二维速度-距离矩阵。
%   cfar_flag   - (logical matrix) 与mtd_signal对应的CFAR检测结果(0-1矩阵)。
%   sys_params  - (struct) 包含雷达系统参数的结构体。

function fun_plot_cfar_dashboard_v2(h_fig, mtd_signal, cfar_flag, sys_params)
%% 0. 激活并清空指定的图窗
figure(h_fig); % 激活由主函数创建的图窗
clf;           % 清空当前图窗的内容，为新的绘图做准备

%% 1. 数据准备和参数获取
% --- 从参数结构体中获取绘图所需参数 ---
prf = sys_params.prf;
wavelength = sys_params.wavelength;
deltaR = sys_params.deltaR;
[num_vel_bins, num_range_bins] = size(mtd_signal);

% --- 数据归一化和对数化 ---
mtd_abs = abs(mtd_signal);
max_val = max(mtd_abs(:));
if max_val == 0, max_val = 1; end % 避免除以0
mtd_log = 20 * log10(mtd_abs / max_val + 1e-9);

% --- 计算物理坐标轴 ---
r_axis = (0:num_range_bins-1) * deltaR;
v_axis = linspace(-prf/2, prf/2, num_vel_bins) * wavelength / 2;

% --- 从CFAR结果中找到最强的目标点用于切片分析 ---
detected_signals = mtd_abs .* cfar_flag;
[peak_signal_val, peak_idx] = max(detected_signals(:));

if peak_signal_val > 0
    [peak_vel_idx, peak_range_idx] = ind2sub(size(mtd_abs), peak_idx);
else
    [~, peak_idx] = max(mtd_abs(:));
    [peak_vel_idx, peak_range_idx] = ind2sub(size(mtd_abs), peak_idx);
end
peak_range = r_axis(peak_range_idx);
peak_velocity = v_axis(peak_vel_idx);


%% 2. 创建并绘制四个子图
%--- 子图 1: 3D MTD视图 ---
subplot(2, 2, 1);
mesh(r_axis, v_axis, mtd_log);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
zlabel('归一化幅度 (dB)');
title('3D 速度-距离图');
grid on; view(3);

% --- 子图 2: 2D RDM 及 CFAR检测结果 ---
subplot(2, 2, 2);
imagesc(r_axis, v_axis, mtd_log);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title('2D RDM 及 CFAR检测点');
colorbar; axis xy;
hold on;
[detected_v_indices, detected_r_indices] = find(cfar_flag);
detected_ranges = r_axis(detected_r_indices);
detected_velocities = v_axis(detected_v_indices);
plot(detected_ranges, detected_velocities, 'r+', 'MarkerSize', 8);
hold off;

%--- 子图 3: 速度维切片 ---
subplot(2, 2, 3);
plot(v_axis, mtd_log(:, peak_range_idx));
grid on;
xlabel('速度 (m/s)');
ylabel('归一化幅度 (dB)');
title(sprintf('速度维切片 @ 距离 = %.2f m', peak_range));
hold on;
xline(peak_velocity, '--r', sprintf('峰值 @ %.2f m/s', peak_velocity));
hold off;

%--- 子图 4: 距离维切片 ---
subplot(2, 2, 4);
plot(r_axis, mtd_log(peak_vel_idx, :));
grid on;
xlabel('距离 (m)');
ylabel('归一化幅度 (dB)');
title(sprintf('距离维切片 @ 速度 = %.2f m/s', peak_velocity));
hold on;
xline(peak_range, '--r', sprintf('峰值 @ %.2f m', peak_range));
hold off;

% 添加一个总标题，显示当前分析的切片信息
sgtitle(sprintf('帧 #%d, 波束 #%d, 切片 #%d', ...
        sys_params.frame_to_load, sys_params.beam_to_plot, sys_params.slice_to_plot));

end
