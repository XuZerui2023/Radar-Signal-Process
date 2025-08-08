# Visualizations 文件夹下使用的主脚本：

1. MTD结果和cfar目标检测信息初步显示
    * `main_visualize_results_v2.m`

2. 目标检测及目标参数主绘图程序
    * `main_visualize_final_results_v1.m`
        * 单独绘制距离-方位图 (PPI)。
        * 单独绘制距离-高度图 (RHI)。
        * 单独绘制距离-方位图（az_range）
        * 单独绘制距离-速度图（rd_plot）
        * 单独绘制三维空间分布图（3d_scatter）
        * 绘制以上多个核心视图的综合分析仪表盘（summary）

3. 溢出点检测
    * `main_plot_overflow_ppi_v5.m`
        * 针对原始iq数据，从bin文件中直接读取
    * `main_plot_pc_overflow.m`
        * 针对脉压后iq数据，从bin文件中直接读取

4. 画原始iq信号幅度图（直接从bin文件读取）
    * `main_plot_amplitude_and_framehead_information.m`

5. 画修正前伺服角和修正后伺服角随帧数变化关系（直接从bin文件读取）
    * `main_plot_amplitude_and_framehead_information.m`