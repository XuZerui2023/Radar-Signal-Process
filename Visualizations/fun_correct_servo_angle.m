% FUN_CORRECT_SERVO_ANGLE - 对原始伺服角度进行指北和固定角度修正
%
% 本函数接收原始的伺服角度整数值，并根据给定的指北角和固定修正角，
% 计算出最终的、在[-180, 180)度范围内的物理角度。
%
% 输入参数:
%   raw_servo_angle - (vector) 从数据帧头读取的原始伺服角度向量。
%   north_angle     - (scalar) 指北修正角（单位：度）。
%   fix_angle       - (scalar) 固定偏移修正角（单位：度）。
%
% 输出参数:
%   corrected_angle_deg - (vector) 经过修正和范围归一化后的角度向量（单位：度）。
%
function corrected_angle_deg = fun_correct_servo_angle(raw_servo_angle, north_angle, fix_angle)
%% 1. 将原始整数值转换为物理角度（单位：度）
% 根据数据格式定义，原始值的单位是0.01度，因此需要乘以0.01。
physical_angle_deg = double(raw_servo_angle) * 0.01;

%% 2. 应用指北角和固定角修正
% 修正公式：物理角度 - 指北角 + 固定角
corrected_angle_deg = physical_angle_deg - north_angle + fix_angle;

%% 3. 将角度归一化到 [-180, 180) 度范围
% 雷达扫描角度通常用-180度到+180度或0到360度表示。
% 下面的循环确保所有角度都落在这个区间内，避免因累加导致角度超出范围。
% 这是一个比单边判断更稳健的写法。
while any(corrected_angle_deg >= 180)
    corrected_angle_deg(corrected_angle_deg >= 180) = corrected_angle_deg(corrected_angle_deg >= 180) - 360;
end

while any(corrected_angle_deg < -180)
    corrected_angle_deg(corrected_angle_deg < -180) = corrected_angle_deg(corrected_angle_deg < -180) + 360;
end

end
