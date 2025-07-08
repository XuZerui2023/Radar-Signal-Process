function fun_plot_mtd_dashboard(mtd_signal, sys_params)
% FUN_PLOT_DASHBOARD - 创建一个MTD结果的综合分析仪表盘
%
% 本函数接收最终的速度-距离矩阵，并在一个窗口中通过四个子图
% 从不同角度对其进行可视化，包括3D视图、2D俯视图以及距离和速度维的切片。
%
% 输入参数:
%   mtd_signal - (double matrix) 最终的速度-距离矩阵。
%   sys_params - (struct) 包含雷达系统参数的结构体。
%                需要包含: prf, wavelength, deltaR。

%% 1. 数据准备和参数获取
% --- 从参数结构体中获取所需参数 ---
prf = sys_params.prf;
wavelength = sys_params.wavelength;
deltaR = sys_params.deltaR;
[num_vel_bins, num_range_bins] = size(mtd_signal);

% --- 数据归一化和对数化 ---
max_val = max(mtd_signal(:));
if max_val == 0, max_val = 1; end % 避免除以0
mtd_log = 20 * log10(mtd_signal / max_val + 1e-9); % 加一个极小值防止log(0)

% --- 计算物理坐标轴 ---
r_axis = (0:num_range_bins-1) * deltaR;
v_axis = linspace(-prf/2, prf/2, num_vel_bins) * wavelength / 2;

% --- 自动寻找峰值点作为目标 ---
[~, peak_idx] = max(mtd_signal(:)); % 找到线性索引
[peak_vel_idx, peak_range_idx] = ind2sub(size(mtd_signal), peak_idx); % 转换为二维索引

peak_range = r_axis(peak_range_idx);
peak_velocity = v_axis(peak_vel_idx);

%% 2. 创建并绘制四个子图
figure('Name', 'MTD处理结果分析仪表盘', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 800]);

% --- 子图 1: 3D视图 (左上) ---
subplot(2, 2, 1);
mesh(r_axis, v_axis, mtd_log);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
zlabel('归一化幅度 (dB)');
title('3D 速度-距离图');
grid on;
view(3);

% --- 子图 2: 2D俯视图 (右上) ---
subplot(2, 2, 2);
imagesc(r_axis, v_axis, mtd_log);
xlabel('距离 (m)');
ylabel('速度 (m/s)');
title('2D 距离-多普勒图 (RDM)');
colorbar;
axis xy; % 将y轴原点置于左下角
hold on;
% 在峰值位置标记一个红色的"+"
plot(peak_range, peak_velocity, 'r+', 'MarkerSize', 10, 'LineWidth', 2);
hold off;

% --- 子图 3: 速度维切片 (左下) ---
subplot(2, 2, 3);
plot(v_axis, mtd_log(:, peak_range_idx));
grid on;
xlabel('速度 (m/s)');
ylabel('归一化幅度 (dB)');
title(['距离维切片 @ 距离 = ', num2str(peak_range, '%.2f'), ' m']);
hold on;
xline(peak_velocity, '--r', ['峰值 @ ', num2str(peak_velocity, '%.2f'), ' m/s']);
hold off;

% --- 子图 4: 距离维切片 (右下) ---
subplot(2, 2, 4);
plot(r_axis, mtd_log(peak_vel_idx, :));
grid on;
xlabel('距离 (m)');
ylabel('归一化幅度 (dB)');
title(['速度维切片 @ 速度 = ', num2str(peak_velocity, '%.2f'), ' m/s']);
hold on;
xline(peak_range, '--r', ['峰值 @ ', num2str(peak_range, '%.2f'), ' m']);
hold off;

end
