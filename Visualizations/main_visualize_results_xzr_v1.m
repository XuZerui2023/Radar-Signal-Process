% main_visualize_results_v1.m
%
% 本脚本是一个独立的可视化分析工具。它负责加载由
% 'main_produce_dataset_win_xzr_v2.m' 和 'main_cfar_xzr.m' 
% 生成的MTD和CFAR结果文件，并调用一个"仪表盘"函数将结果进行综合展示。
% 调用 fun_plot_cfar_dashboard_v2.m 函数
%
% 修改记录:
% date       by      version   modify
% 原始版本                     仅硬编码处理两个波束
% 25/06/18   XZR      v1.0    生成指定的某个波束某个切片下具体某帧信号的结果图（MTD和CFAR结果图）

% 未来改进：
clc; clear; close all;

%% 1. 定义需要分析的目标
% --- 用户在此处配置要查看的数据 ---
n_exp =  3;        % 实验编号 (必须与生成数据时使用的编号一致)
win_size = 4;      % 窗口大小 (必须与生成数据时使用的编号一致)
T_CFAR = 7;        % CFAR门限因子 (必须与生成数据时使用的编号一致)
params.frame_to_load = 50;  % 指定要加载和分析的帧编号

% --- 指定要可视化的数据切片 ---
params.beam_to_plot = 1;  % 指定要查看的波束 (例如, 第1个波束)
params.slice_to_plot = 1; % 指定要查看的窗口切片 (范围是 1 到 win_size)

frame_to_load = params.frame_to_load;
beam_to_plot = params.beam_to_plot;
slice_to_plot = params.slice_to_plot;

%% 2. 加载雷达系统参数
% !!! 关键步骤 !!!
% 绘图函数需要雷达的物理参数来计算坐标轴。
% 这些参数必须与数据处理时使用的参数完全一致。
params.c = 2.99792458e8;
params.prtNum = 332;
params.prt = 232.76e-6;
params.fs = 25e6;
params.fc = 9450e6;
params.point_prt_total = 3404; % MTD处理后的总距离点数
% 派生参数
params.prf = 1 / params.prt;
params.wavelength = params.c / params.fc;
params.deltaR = params.c / (2 * params.fs);


%% 3. 加载数据文件
% --- 构建文件路径 ---
filepath = uigetdir;                         % 以弹窗的方式进行文件基础路径读取，一般具体到雷达型号和采集日期作为根目录，例如"X8数据采集250522"
if isequal(filepath, 0)
    disp('用户取消了文件选择。');
    return;
else
    fullFile = fullfile(filepath);
    disp(['已选择文件路径: ', fullFile]);
end
base_path = filepath;
mtd_data_path = fullfile(base_path, num2str(n_exp), ['MTD_data_win', num2str(win_size)]);
cfar_data_path = fullfile(base_path, num2str(n_exp), ['cfarFlag4_T', num2str(T_CFAR)]);

mtd_filename = fullfile(mtd_data_path, ['frame_', num2str(frame_to_load), '.mat']);
cfar_filename = fullfile(cfar_data_path, ['frame_', num2str(frame_to_load), '.mat']);

% --- 加载MTD数据 ---
if exist(mtd_filename, 'file')
    fprintf('正在加载MTD文件: %s\n', mtd_filename);
    load_mtd = load(mtd_filename, 'MTD_win_all_beams');
    MTD_win_all_beams = load_mtd.MTD_win_all_beams;
else
    error('MTD结果文件不存在: %s', mtd_filename);
end

% --- 加载CFAR数据 ---
if exist(cfar_filename, 'file')
    fprintf('正在加载CFAR文件: %s\n', cfar_filename);
    load_cfar = load(cfar_filename, 'cfarFlag_win_all_beams');
    cfarFlag_win_all_beams = load_cfar.cfarFlag_win_all_beams;
else
    error('CFAR结果文件不存在: %s', cfar_filename);
end


%% 4. 从数据结构中提取要绘图的二维数据
% --- 检查索引有效性并提取MTD数据 ---
if beam_to_plot > numel(MTD_win_all_beams) || beam_to_plot < 1, error('波束索引无效'); end
MTD_data_one_beam = MTD_win_all_beams{beam_to_plot};
if slice_to_plot > size(MTD_data_one_beam, 1) || slice_to_plot < 1, error('切片索引无效'); end
mtd_to_plot = squeeze(MTD_data_one_beam(slice_to_plot, :, :));

% --- 提取对应的CFAR数据 ---
cfarFlag_one_beam = cfarFlag_win_all_beams{beam_to_plot};
cfar_to_plot = squeeze(cfarFlag_one_beam(slice_to_plot, :, :));


%% 5. 调用绘图函数进行可视化
fprintf('正在为第 %d 帧, 第 %d 波束, 第 %d 切片的数据绘图...\n', frame_to_load, beam_to_plot, slice_to_plot);

% 调用新的仪表盘绘图函数
fun_plot_cfar_dashboard_v1(mtd_to_plot, cfar_to_plot, params);
