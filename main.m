%% main
clear variables;

MergeConfigration = struct('errorSecondsLimit', [-0.5, 0.5], ...,
                           'servoFileType', 1, ...,
                           'servoFilePath', '..\data20211213\servo\', ...,
                           'servoFileName',  'CDL_3D6000_lidar2_PPI_FromAzimuth240.00_ToAzimuth360.00_PitchAngle22.90_Resolution030_StartIndex003_LOSWind_20211213 232529.csv', ...,
                           'dacFilePath', '..\data20211213\dac\', ...,
                           'dacFileBeginIndex', 1000 ...,
                          );
                      
MergedData = MergeFreqDirection(MergeConfigration);

%% 读取文件 数据和噪声
NoiseData = load('..\results20211213\noise.mat');
NoiseData = NoiseData.NoiseData;
MatchData = load('..\results20211213\match1.mat');
MatchData = MatchData.MergeFreqDirection;

% 计算去噪数据
for matchData_index = 1 : size(MatchData, 2)
    disp(matchData_index);
    MatchData(matchData_index).ridNoiseData = MatchData(matchData_index).data - NoiseData;
end

% plot(MatchData(12).data);
% hold on;
% plot(MatchData(12).data - NoiseData);

%% 计算速度
MatchData = CalculateFreqSpeed(MatchData);
validVelocityIndex = find( [MatchData.SNR] > 4.4854 );
plot([ MatchData(validVelocityIndex).radialVelocity ]);

%% 筛选角度249.15
matchAngle = 249.15;
matchLimit = [-2,2]; % 冗余角度
matchAngleIndex = find( ([MatchData.Azimuth] - matchAngle >= matchLimit(1)) ...,
                         & ([MatchData.Azimuth] - matchAngle <= matchLimit(2)) );
clear matchAngle matchLimit;
plot([ MatchData(matchAngleIndex).radialVelocity ]);


%% 局部函数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 局部函数 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function MatchDataAddSpeed = CalculateFreqSpeed(matchData)
% CalculateFreqSpeed Local function that calculate speed and snr by freq data    

    % 取一组所有频率中最大的频率对应的下标
    ignoreFreqStart = 1; % 去除第一个0频高值
    for matchData_index = 1 : size(matchData, 2)
        [~, maxIndex] = max( matchData(matchData_index).ridNoiseData(1+ignoreFreqStart:end) ); %删除零频率位置得到最大频移点
        windFreq = maxIndex + ignoreFreqStart;
        matchData(matchData_index).radialVelocity = windFreq*0.775*250/8192;
        
        % 计算信噪比
        if ( maxIndex < 190 )
            snrPos_l = maxIndex + 61;
            snrPos_r = maxIndex + 110;    
        else
            snrPos_l = maxIndex - 110;
            snrPos_r = maxIndex - 61;   
        end
        snrNoise = matchData(matchData_index).ridNoiseData(snrPos_l : snrPos_r);
        snrNoiseRms = sqrt( sum(snrNoise.^2) / length(snrNoise) ); %SNR的噪声均方根数据，作为分母
        dataSNR_arr = matchData(matchData_index).ridNoiseData(1+ignoreFreqStart:end) / snrNoiseRms;   %SNR分子为(原始数据-本底噪声)
        matchData(matchData_index).SNR = max(dataSNR_arr);
%         if ( (max(dataSNR_arr) <= 4.4854) ) %&(max(y_CW_SNR_1000_1)<30)%信噪比阈值
%         end
    end
    
    MatchDataAddSpeed = matchData;
end
