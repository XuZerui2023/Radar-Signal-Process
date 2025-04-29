function concate_range=fun_lss_range_concate(prtNum,s)
% 删除重复的区间,使距离周三脉冲区间刚好拼起来

concate_range=zeros(prtNum,868);
concate_range(:,1:82)=s(:,1:82);%82点
concate_range(:,83:318)=s(:,83+(82-75):325);%
concate_range(:,319:868)=s(:,325+(82+235-160):1031);


end