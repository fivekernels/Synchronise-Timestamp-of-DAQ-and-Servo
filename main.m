clear variables;

MergeConfigration = struct('errorSecondsLimit', [-0.5, 0.5], ...,
                           'servoFileType', 1, ...,
                           'servoFilePath', '..\data20211213\servo\', ...,
                           'servoFileName',  'CDL_3D6000_lidar2_PPI_FromAzimuth240.00_ToAzimuth360.00_PitchAngle22.90_Resolution030_StartIndex003_LOSWind_20211213 232529.csv', ...,
                           'dacFilePath', '..\data20211213\dac\', ...,
                           'dacFileBeginIndex', 1 ...,
                          );
                      
MergedData = MergeFreqDirection(MergeConfigration);

NoiseData = load('..\results20211213\noise.mat');
NoiseData = NoiseData.NoiseData;
MatchData = load('..\results20211213\match1.mat');
MatchData = MatchData.MergeFreqDirection;

for matchData_index = 1 : size(MatchData, 2)
    disp(matchData_index);
    MatchData(matchData_index).ridNoiseData = MatchData(matchData_index).data - NoiseData;
end

plot(MatchData(12).data);
hold on;
plot(MatchData(12).data - NoiseData);


% 取一组所有频率中最大的频率对应的下标
specificDirFreq = NaN(ceil(size(MatchData, 2)/1), 1); %预分配 配合将来剔除信噪比等使用
specificDirFreq_index = 1;
ignoreFreqStart = 1; % 去除第一个0频高值
for matchData_index = 1 : size(MatchData, 2)
    [maxData, maxIndex] = max( MatchData(matchData_index).ridNoiseData(1+ignoreFreqStart:end) ); %删除零频率位置得到最大频移点
    %
        if(maxIndex<190)
            CW_SNR_pos_1=maxIndex+61;
            CW_SNR_pos_2=maxIndex+110;    
        else
            CW_SNR_pos_1=maxIndex-110;
            CW_SNR_pos_2=maxIndex-61;   
        end
        CW_SNR_noise=MatchData(matchData_index).ridNoiseData(CW_SNR_pos_1:CW_SNR_pos_2);
        CW_SNR_noise_rms=sqrt(sum(CW_SNR_noise.^2)/length(CW_SNR_noise)); %SNR的噪声均方根数据，作为分母
        y_CW_SNR_1000_1=((MatchData(matchData_index).ridNoiseData(1+ignoreFreqStart:end)/CW_SNR_noise_rms));   %SNR分子为原始数据-本底噪声
        if ( (max(y_CW_SNR_1000_1) <= 4.4854) ) %&(max(y_CW_SNR_1000_1)<30)%信噪比阈值
            specificDirFreq(specificDirFreq_index) = NaN;
            specificDirFreq_index = specificDirFreq_index + 1;
            continue;
        end
    %
    specificDirFreq(specificDirFreq_index) = maxIndex + ignoreFreqStart;
    specificDirFreq_index = specificDirFreq_index + 1;
end
specificDirFreq(specificDirFreq_index:end) = [];
plot(specificDirFreq*0.775*250/8192); % 频率转化速度

% 结构体添加速度属性
specificSpeed = specificDirFreq*0.775*250/8192;
for matchData_index = 1 : size(MatchData, 2)
    MatchData(matchData_index).speed = specificSpeed(matchData_index);
end

% 筛选249.15
matchAngle = 249.15;
matchLimit = [-2,2];
MatchAngleData = repmat(MatchData, [1,  1000]);
matchAngleData_index = 1;
for matchData_index = 1 : size(MatchData, 2)
    if ( MatchData(matchData_index).Azimuth - matchAngle>=matchLimit(1) && MatchData(matchData_index).Azimuth - matchAngle<=matchLimit(2) )
        MatchAngleData(matchAngleData_index) = MatchData(matchData_index);
        matchAngleSpeed(matchAngleData_index) = MatchData(matchData_index).speed; % 画图用
        matchAngleData_index = matchAngleData_index + 1;
    end
end
MatchAngleData(matchAngleData_index:end) = []; % 清理多余预分配

plot(matchAngleSpeed);
