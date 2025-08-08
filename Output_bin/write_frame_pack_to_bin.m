function write_frame_pack_to_bin(fileID, frame_data_pack)
% write_frame_pack_to_bin.m - 将单帧的目标数据包写入二进制文件
%
% v2.0 更新:
% - 函数逻辑已完全更新，严格模仿 fun_output_mat2bin.m 的写入方式。
% - 输入参数现在是一个包含两层嵌套结构的单帧数据包。
%
% 输入参数:
%   fileID          - (double) 由 fopen 打开的有效文件句柄。
%   frame_data_pack - (struct) 包含单帧所有信息的两层结构体 (例如 point_inform_0(i))。
%
%  修改记录
%  date       by      version   modify
%  25/07/27   XZR       v1.0    创建
%  25/07/29   XZR       v2.0
%  现在本函数仅保留对两层结构体数组数据的读取和写入bin文件，其余预处理，修改与判断0目标选用1*1空数组均交由上层函数完成

% --- 1. 写入 _FrameData_Pack 的头部信息 ---
% 我们逐个字段写入，并明确指定数据类型，以确保与C++的内存布局完全一致。
fwrite(fileID, frame_data_pack.iWaveFormNo, 'uint8');
fwrite(fileID, frame_data_pack.iDistanceMode, 'uint8');
fwrite(fileID, frame_data_pack.iAntSpeedMode, 'uint8');
fwrite(fileID, frame_data_pack.iAntAngle, 'short');
fwrite(fileID, frame_data_pack.iCenterFreq, 'ushort');
fwrite(fileID, frame_data_pack.T_Wave, 'float');
fwrite(fileID, frame_data_pack.TimeScale, 'double');
fwrite(fileID, frame_data_pack.iGoalNum, 'ushort');

% --- 2. 写入该帧包含的所有目标点的参数信息 ---
% 注意目标数量为0时，也要写入 Goal_Spec 目标谱数据， 这部分工作交由上层函数完成实现
% if frame_data_pack.iGoalNum == 0
%     return; % 如果该帧无检测点，则不存入数据，只保留空字段，返回上层函数 
% else    
    for j = 1:frame_data_pack.iGoalNum
        % 获取当前目标
        current_goal = frame_data_pack.Goal_Para_Frame(j);

        % 逐个写入 _Goal_Para_Frame 的字段
        fwrite(fileID, current_goal.fAmp, 'float');
        fwrite(fileID, current_goal.fSnr, 'float');
        fwrite(fileID, current_goal.fAmuAngle, 'float');
        fwrite(fileID, current_goal.fEleAngle, 'float');
        fwrite(fileID, current_goal.fRange, 'float');
        fwrite(fileID, current_goal.fSpeed, 'float');
        fwrite(fileID, current_goal.fFdA, 'float');
        fwrite(fileID, current_goal.fSpecWidth, 'float');
        fwrite(fileID, current_goal.Goal_Spec, 'float');
    end

% end

end
