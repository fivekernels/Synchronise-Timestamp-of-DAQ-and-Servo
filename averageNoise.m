noiseFilePath = '..\data20211213\noise\';

NoiseData = zeros(1, 1500);
noiseRowCount = 0;

% 读采集卡txt
dacFileTree = dir([noiseFilePath, '*.txt']);
dacFileNum = size(dacFileTree,1);
for dacFile_Index = 1 : dacFileNum
    fprintf("loading noise dac txt: %s...\n", dacFileTree(dacFile_Index).name);
    dacTxtData = importDACtxt([noiseFilePath, dacFileTree(dacFile_Index).name]);
    noiseRowCount = noiseRowCount + size(dacTxtData, 1);
    for noiseColumnIndex = 1 : 1500
        NoiseData(noiseColumnIndex) = NoiseData(noiseColumnIndex) + sum( hex2dec(dacTxtData{:,(noiseColumnIndex)*2+1}) );
    end
end
NoiseData = NoiseData / noiseRowCount;