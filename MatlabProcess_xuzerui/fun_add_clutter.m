% 加入背景杂波

function Echo_simu_clutter= fun_add_clutter( Echo_simu_STC,echoData_Frame_0)

[prtNum,point_prt]=size(Echo_simu_STC);
for i=1:prtNum
    clutter=echoData_Frame_0(i,:);
    Echo_simu_STC(i,:)= Echo_simu_STC(i,:)+clutter(1,1:point_prt);
   
end
Echo_simu_clutter=Echo_simu_STC;
end