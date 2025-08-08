function fun_output_mat2bin(bin_path_0, point_inform_0)

fid_bin_0 = fopen(bin_path_0, 'w');

point_inform_to_write_0 = point_inform_0;

% 写入帧（或通用）信息
for i = 1:size(point_inform_to_write_0, 2)
    fwrite(fid_bin_0, point_inform_to_write_0(i).iWaveFormNo, 'uint8');
    fwrite(fid_bin_0, point_inform_to_write_0(i).iDistanceMode, 'uint8');
    fwrite(fid_bin_0, point_inform_to_write_0(i).iAntSpeedMode, 'uint8');
    fwrite(fid_bin_0, point_inform_to_write_0(i).iAntAngle, 'short');
    fwrite(fid_bin_0, point_inform_to_write_0(i).iCenterFreq, 'ushort');
    fwrite(fid_bin_0, point_inform_to_write_0(i).T_Wave, 'float');
    fwrite(fid_bin_0, point_inform_to_write_0(i).TimeScale, 'double');
    fwrite(fid_bin_0, point_inform_to_write_0(i).iGoalNum, 'ushort');

    % 写入目标参数信息
    for j = 1:point_inform_to_write_0(i).iGoalNum
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fAmp, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fSnr, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fAmuAngle, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fEleAngle, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fRange, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fSpeed, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fFdA, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).fSpecWidth, 'float');
        fwrite(fid_bin_0, point_inform_to_write_0(i).Goal_Para_Frame(j).Goal_Spec, 'float'); 
    end
end

fclose(fid_bin_0);

end