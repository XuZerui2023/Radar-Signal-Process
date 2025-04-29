function dataFileFullPath = dataFullPathGen(DataFilePath,fileInd)

if fileInd<10
    dataFileName=strcat('00000',num2str(fileInd),'.bin');
elseif fileInd<100
    dataFileName=strcat('0000',num2str(fileInd),'.bin');
else
    dataFileName=strcat('000',num2str(fileInd),'.bin');
end

dataFileFullPath = fullfile(DataFilePath,dataFileName);