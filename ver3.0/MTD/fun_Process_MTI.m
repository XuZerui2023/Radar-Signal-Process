function MTI_Out = fun_Process_MTI( ProSiganl )
%fun_Process_MTI MTI������
% ���ڶ����������ʵ��MTI����   

%  ���������ProSiganl                      �������ź� ������ʽ��Num_PRTperFrame*Len_PRT
%  ���������MTI_Out                        MTI������ź� ������ʽ��Num_PRTperFrame*Len_PRT
%% MTI����
[Num_PRTperFrame,Len_PRT] = size( ProSiganl );
MTI_Out = zeros(Num_PRTperFrame, Len_PRT);
sum=0;
for Inex_PRT=1:Num_PRTperFrame   %%���1�й̶�Ϊ0
    sum = sum+ ProSiganl(Inex_PRT, :); %%���������
end
average=sum/Num_PRTperFrame;

% for Inex_PRT=1:Num_PRTperFrame   
%     MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT, :) - average; %%���������,��ȥƽ��ֵ
% end

for Inex_PRT=1:Num_PRTperFrame-30   
    MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT+30, :) - ProSiganl(Inex_PRT, :); %%���������
end

% MTI_Out(Num_PRTperFrame,:) = ProSiganl(Num_PRTperFrame,:);
% for Index_PRT=1:Num_PRTperFrame-2  %%���2�й̶�Ϊ0
%     MTI_Out(Inex_PRT, :) = ProSiganl(Inex_PRT+2, :) - 2 * ProSiganl(Inex_PRT+1, :) +  ProSiganl(Inex_PRT, :); % ���������
% end
end

