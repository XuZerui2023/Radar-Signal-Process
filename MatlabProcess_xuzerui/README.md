
## 函数处理流程
1. bin_to_mat.m 文件：把二进制bin文件转化成二进制mat文件 "BasebandRawData_mat"
2. main_produce_dataset_win.m 文件: 把二进制mat文件进行MTD处理后存入 "MTD_data_win" 文件夹
3. main_cfar.m 文件 对MTD处理后的文件

## 主函数文件
### bin_to_mat_xzr.m 文件
- 主要功能：此文件用于读取回波数据，将二进制 bin 文件格式转换为MATLAB的二进制 mat 文件格式。
- 引用了 `frameDataRead_A_xzr.m` 函数
- 依赖 `frameDataRead_A_xzr.m` 函数将每帧信号读取出来并计算
- mat文件由三部分组成：'echoData_Frame_0', 'echoData_Frame_1', 'angleCodeSeries'

## 子函数文件
### frameDataRead_A_xzr.m
从二进制bin文件中读取回波信号数据中一帧的数据

### fun_MTD_produce.m 
ISTC

## 2025/3/28需要改进的功能
1. 12波束（每脉冲3脉冲）波形：需要增加波束 
2. cfar图修改：把多帧信号画到一张图上
3. cfar图增加：画 距离-俯仰角 关系的图 
4. 可能涉及多波束成形 DBF



需要修改的文件：
1 main_produce_dataset_win_xzr.m


2

3

4