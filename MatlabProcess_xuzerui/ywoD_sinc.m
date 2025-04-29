clear;clc
x=linspace(-10,10,200);
y=linspace(-10,10,200);
for i=1:length(x)
    for j=1:length(y)      
        x1=x(i)*pi;
        y1=y(j)*pi;
        x2=sin(x1)/x1;
         y2=sin(y1)/y1;
        z(i,j)=x2*y2;
    end
end
[x,y]=meshgrid(x,y);
surf(x,y,z)