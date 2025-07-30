% fun_parameter_estimation.m - 对单个目标点进行精确参数估计
%
% 本函数是参数测量的"引擎"。它接收一个初步检测点的信息，
% 利用单脉冲比和K值解算出精确的俯仰角，并对距离和速度进行插值。
%
% 输入参数:
%   prelim_detection - (struct) 单个初步检测点，包含原始复数值和索引。
%   k_value          - (double) 与该检测点对应的测角K值。
%   config           - (struct) 全局配置结构体，用于获取雷达系统参数。
%
% 输出:
%   final_detection  - (struct) 包含最终精确参数的结构体。
%
%  修改记录
%  date       by      version    modify
%  25/07/12   XZR      v1.0      创建，借鉴了motionParaMeasure.m的思想

function final_detection = fun_parameter_estimation(prelim_detection, RDM_sum_amp, k_value, config)
%% 1. 从输入中提取所需信息
complex_val1 = prelim_detection.complex_val_beam1;
complex_val2 = prelim_detection.complex_val_beam2;
beam_pair_idx = prelim_detection.beam_pair_index;
r_idx = prelim_detection.range_index;
v_idx = prelim_detection.velocity_index;

% 从config中获取雷达和插值参数
beam_angles = config.Sig_Config.beam_angles_deg;           % 13个波束的标称俯仰角（向量）（单位为角度）
deltaR = config.Sig_Config.deltaR;
v_axis = linspace(-config.Sig_Config.prf/2, config.Sig_Config.prf/2, config.Sig_Config.prtNum) * config.Sig_Config.wavelength / 2;

% 插值参数 (建议在config中定义)
extraDots = config.interpolation.extra_dots;               % 插值时在峰值两侧各取几个点
rInterpTimes = config.interpolation.range_interp_times;    % 距离维插值倍数
vInterpTimes = config.interpolation.velocity_interp_times; % 速度维插值倍数

[vCellNum, rCellNum] = size(RDM_sum_amp);


%% 2. 距离精确测量 (通过插值)
% --- 准备插值窗口 ---
cellsExtend = -extraDots:extraDots;
rCellsFix = cellsExtend + r_idx;       % 构造距离维插值窗口的索引

% --- 边界检查，防止索引越界 ---
if min(rCellsFix) <= 0
    rCellsFix = 1:(2 * extraDots + 1);
elseif max(rCellsFix) > rCellNum
    rCellsFix = (rCellNum - 2 * extraDots):rCellNum;
end

% --- 执行样条插值 ---
mtdDataUsed_r = RDM_sum_amp(v_idx, rCellsFix); % 取出目标所在速度维，在峰值距离点周围的数据
rCellsFixQ = rCellsFix(1) : (1/rInterpTimes) : rCellsFix(end);            % 创建更精细的距离索引网格
mtdDataUsedQ_r = interp1(rCellsFix, mtdDataUsed_r, rCellsFixQ, 'spline'); % 'spline'三次样条插值
[~, I1] = max(mtdDataUsedQ_r);                 % 在插值后的曲线上寻找新峰值

% --- 计算最终距离 ---
if ~isempty(I1)
    rCellMax = rCellsFixQ(I1(1)); % 获取插值后峰值的精确索引
    % 最终距离 = 粗略距离 + 精细偏移
    final_range_m = (rCellMax - 1) * deltaR; % 从索引1开始计算
else
    final_range_m = (r_idx - 1) * deltaR;    % 插值失败则使用原始值
end

%% 3. 速度精确测量 (通过插值)
% --- 准备插值窗口 ---
vCellsFix = cellsExtend + v_idx; % 构造速度维插值窗口的索引

% --- 边界检查 ---
if min(vCellsFix) <= 0
    vCellsFix = 1:(2 * extraDots + 1);
elseif max(vCellsFix) > vCellNum
    vCellsFix = (vCellNum - 2 * extraDots):vCellNum;
end

% --- 执行样条插值 ---
mtdDataUsed_v = RDM_sum_amp(vCellsFix, r_idx); % 取出目标所在距离维，在峰值速度点周围的数据
vCellsFixQ = vCellsFix(1) : (1/vInterpTimes) : vCellsFix(end); % 创建更精细的速度索引网格
mtdDataUsedQ_v = interp1(vCellsFix, mtdDataUsed_v, vCellsFixQ, 'spline');
[~, I2] = max(mtdDataUsedQ_v);

% --- 计算最终速度 ---
if ~isempty(I2)
    vCellMax = vCellsFixQ(I2(1)); % 获取插值后峰值的精确索引
    % 使用线性插值在速度轴上找到精确的速度值
    final_velocity_ms = interp1(1:vCellNum, v_axis, vCellMax);
else
    final_velocity_ms = v_axis(v_idx); % 插值失败则使用原始值
end


%% 4. 俯仰角测量 (核心)
% --- 计算和差信号幅度 ---
% 注意：这里我们使用复数值的模（幅度）进行计算，与参考项目逻辑一致
amp_sum = abs(complex_val1) + abs(complex_val2);  % 计算相邻两波束和信号
amp_diff = abs(complex_val2) - abs(complex_val1); % 计算相邻两波数差信号，减法顺序需与K值标定时的定义保持一致，用来判断目标偏离方向

% --- 计算单脉冲比 ---
% 为避免除以零的错误，增加一个极小值epsilon
monopulse_ratio = amp_diff / (amp_sum + 1e-9);    % 相对误差指示量

% --- 计算角度误差 ---
% 这是单脉冲测角的核心公式
elevation_error_deg = monopulse_ratio / k_value;  % 计算目标相对于测量基准的精确角度误差，K值是测角鉴别器斜率

% --- 计算最终俯仰角 ---
% 基准角是当前波束对的中心指向
base_angle_deg = (beam_angles(beam_pair_idx) + beam_angles(beam_pair_idx + 1)) / 2; % 相邻两波束取中心值作为基准角度
eleAngleEst = base_angle_deg + elevation_error_deg; % 计算俯仰角的估计值


%% 5. 计算目标高度
% Height = R * sin(elevation)
final_height_m = final_range_m * sind(eleAngleEst); % 使用sind函数，它直接接受角度作为输入

%% 6. 打包最终结果
final_detection.range_m = final_range_m;            % 保存距离测量值
final_detection.velocity_ms = final_velocity_ms;    % 保存速度测量值
final_detection.elevation_deg = eleAngleEst;        % 保存俯仰角测量值
final_detection.height_m = final_height_m;          % 保存高度测量值
final_detection.snr = amp_sum;                      % 使用和信号幅度作为信噪比的近似

end
