clear;close all;
%对MTD数据速度维与距离维剪切
% v=[-20,20],V_point=[691-845]
tic;

for frameRInd=0:5345

data=load(['./UAVdataset/20220326/2/20220326_164800/MTD_data/frame_',num2str(frameRInd),'.mat']);
MTD_0=data.MTD_0;
MTD_1=data.MTD_1;

MTD_0=MTD_0(691:845,:);
MTD_1=MTD_1(691:845,:);


save(['./UAVdataset/20220326/2/20220326_164800/MTD_data_clip/frame_',num2str(frameRInd),'.mat'],'MTD_0','MTD_1');
frameRInd
toc
end