function MTI_Out = fun_Process_MTI( ProSiganl )
%fun_Process_MTI MTI处理函数
% 基于二脉冲对消器实现MTI处理   

%  输出参数：ProSiganl                      待处理信号 矩阵形式：Num_PRTperFrame*Len_PRT
%  输出参数：MTI_Out                        MTI处理后信号 矩阵形式：Num_PRTperFrame*Len_PRT
%% MTI处理
[Num_PRTperFrame,Len_PRT] = size( ProSiganl );
MTI_Out = zeros(Num_PRTperFrame, Len_PRT);
sum=0;
for Inex_PRT=1:Num_PRTperFrame   %%最后1行固定为0
    sum = sum+ ProSiganl(Inex_PRT, :); %%二脉冲对消
end
average=sum/Num_PRTperFrame;

% for Inex_PRT=1:Num_PRTperFrame   
%     MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT, :) - average; %%二脉冲对消,减去平均值
% end

for Inex_PRT=1:Num_PRTperFrame-30   
    MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT+30, :) - ProSiganl(Inex_PRT, :); %%二脉冲对消
end

% MTI_Out(Num_PRTperFrame,:) = ProSiganl(Num_PRTperFrame,:);
% for Index_PRT=1:Num_PRTperFrame-2  %%最后2行固定为0
%     MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT+2, :) - 2 * ProSiganl(Inex_PRT+1, :) +  ProSiganl(Inex_PRT, :); % 三脉冲对消
% end
end

