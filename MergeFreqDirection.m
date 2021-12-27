function MergedData = MergeFreqDirection(mergeConfigration)

% clear variables;
if nargin == 0
    MatchSecond = [-0.5,0.5]; % 匹配时间阈值 闭区间 秒
    servoType = 1; % 伺服工作模式 五波束=0 ppi=1 对应的csv字段格式不同
    servoFilePath = '..\data20211213\servo\';
    servoFileName = 'CDL_3D6000_lidar2_PPI_FromAzimuth240.00_ToAzimuth360.00_PitchAngle22.90_Resolution030_StartIndex003_LOSWind_20211213 232529.csv';
    dacFilePath = '..\data20211213\dac\';
    dacFile_Index = 1281; % 文件夹内采集卡txt文件index
else
    MatchSecond = mergeConfigration.errorSecondsLimit;
    servoType = mergeConfigration.servoFileType;
    servoFilePath = mergeConfigration.servoFilePath;
    servoFileName = mergeConfigration.servoFileName;
    dacFilePath = mergeConfigration.dacFilePath;
    dacFile_Index = mergeConfigration.dacFileBeginIndex;
end

if (servoType == 0) % dbs五波束
    ServoDBSColumn_direction = 5;
    ServoDBSColumn_pitch = 7;
else
if (servoType == 1) % ppi
    ServoPPIColumn_azimuth = 5;
    ServoPPIColumn_pitch = 6;
end
end

% 读采集卡txt
dacFileTree = dir([dacFilePath, '*.txt']);
dacFileNum = size(dacFileTree,1);
fprintf("loading initial dac txt: %s...\n", dacFileTree(dacFile_Index).name);
dacTxtData = importDACtxt([dacFilePath, dacFileTree(dacFile_Index).name]);

% 读方位信息
directionXlsData = importDirectionExcel([servoFilePath servoFileName]);

MergedData = struct('time', '', ...,
                    'errorSeconds', NaN, ...,
                    'direction', '', ...,
                    'Azimuth', NaN, ...,
                    'pitch', NaN, ...,
                    'servoGroup',NaN, ...,
                    'data', NaN(1, 1500) ...,
                   );
MergedData = repmat(MergedData, [ 1,  ceil(size(directionXlsData, 1)*2.5) ] ); % 预分配 按照原始csv行数的<2.5>倍分配

MergeStruct_Index = 1; % 合并后新结构体下标
dirXls_index = 1;      % excel 文件内下一个读取行数
daqTxtIndexRecord = 1; % 采集卡txt文件内行数
while dirXls_index <= size(directionXlsData, 1)
    directionTimeStr = directionXlsData{dirXls_index,1};
    timeDir = datevec(directionTimeStr, 'yyyymmdd HH:MM:SS.FFF');
    fprintf("try dir time = %s\n", directionTimeStr);
    
    daqTxt_index = daqTxtIndexRecord;
    while daqTxt_index <= size(dacTxtData, 1)
        dacTimeStr = dacTxtData{daqTxt_index,1};
        timeDac = datevec(dacTimeStr, 'yyyymmdd-HHMMSSFFF');
        deltaSeconds = etime(timeDac, timeDir); % dac-dir
        if (deltaSeconds < MatchSecond(1)) % txt时间小
            fprintf("not match, delta second = %d, direction time = %s, dqc time = %s\n", deltaSeconds, directionTimeStr, dacTimeStr);
            daqTxt_index = daqTxt_index + 1;
            continue;
        end
        if (deltaSeconds <= MatchSecond(2)) % 时间匹配
            fprintf("match, delta second = %d,  direction time = %s, dqc time = %s\n", deltaSeconds, directionTimeStr, dacTimeStr);
            MergedData(MergeStruct_Index).time = dacTimeStr;
            MergedData(MergeStruct_Index).errorSeconds = deltaSeconds;
            if servoType == 1
                MergedData(MergeStruct_Index).Azimuth = str2double(string(directionXlsData{dirXls_index, ServoPPIColumn_azimuth}));
                MergedData(MergeStruct_Index).pitch = directionXlsData{dirXls_index, ServoPPIColumn_pitch};
            else
                MergedData(MergeStruct_Index).direction = string(directionXlsData{dirXls_index, ServoDBSColumn_direction});
                MergedData(MergeStruct_Index).pitch = directionXlsData{dirXls_index, ServoDBSColumn_pitch};
            end
            MergedData(MergeStruct_Index).servoGroup = dirXls_index; % 标识当前数据对应伺服csv的数据行号 同一行csv匹配的所有txt具有相同的group
            MergedData(MergeStruct_Index).data = hex2dec(dacTxtData{daqTxt_index,(1)*2+1:2:(1500)*2+1});
            MergeStruct_Index = MergeStruct_Index + 1;
        else % 超时 全部结束 读取方位下一行
            fprintf("end match, delta second = %d, direction time = %s, dqc time = %s\n", deltaSeconds, directionTimeStr, dacTimeStr);
            daqTxtIndexRecord = daqTxt_index;
            break;
        end
        daqTxt_index = daqTxt_index + 1;
    end % while 当前采集卡文件

    if (daqTxt_index > size(dacTxtData, 1)) % txt文件尾
        dacFile_Index = dacFile_Index + 1;  % 更换下一个采集卡文件 采集卡最后一个文件时间仍然小于伺服 或 采集卡最后一个文件时间仍然匹配
        if dacFile_Index <= dacFileNum % 仍有txt未读取
            fprintf("loading next dac txt: %s...\n", dacFileTree(dacFile_Index).name);
            dacTxtData = importDACtxt([dacFilePath, dacFileTree(dacFile_Index).name]);
            daqTxtIndexRecord = 1;
            continue;
        else
            disp("not enough DAQ txt to match last Servo csv rows");
            break;
        end
    end
    dirXls_index = dirXls_index + 1;
end

MergedData(MergeStruct_Index:end) = []; % 清理多余预分配

% 剔除同一行excel中匹配的多个txt 保留时间误差最小的
MergeStruct_Index = 1; % 合并后新结构体下标
while MergeStruct_Index <= size(MergedData, 2)
    while (MergeStruct_Index + 1 <=size(MergedData, 2)) && ...,
       (MergedData(MergeStruct_Index).servoGroup == MergedData(MergeStruct_Index + 1).servoGroup)
        if( abs(MergedData(MergeStruct_Index).errorSeconds) > abs(MergedData(MergeStruct_Index + 1).errorSeconds) )
            MergedData(MergeStruct_Index) = [];
            MergeStruct_Index = MergeStruct_Index + 1;
        else
            MergedData(MergeStruct_Index + 1) = [];
        end
    end
    MergeStruct_Index = MergeStruct_Index + 1;
end

end


% 饼
% for angleArr_Index = 1 : size(MergeFreqDirection, 2)
for angleArr_Index = 1 : 28
    angleArr(angleArr_Index) = MergedData(angleArr_Index).Azimuth;
end
[r,theta] = meshgrid(8:9,deg2rad(angleArr));
x = r.*cos(theta);
y = r.*sin(theta);
z(:, 1) = specificDirFreq(1:28)*0.775*250/8192;
z(:, 2) = specificDirFreq(1:28)*0.775*250/8192;
surf(x,y,z,'LineStyle','none')
colormap('jet')
caxis([-5 5])
colorbar
view(2)
% 绘制每一次测量的频谱图像
data_num = size(MergedData,2);
savepath = 'F:\不关我的事\';
for i = 2764:data_num
    
    plot(MergedData(i).data);
    set(gca,'FontSize',10,'fontname','Arial');
    title('FFT','FontSize',20,'FontName','Arial');
    xlabel('Frequency(MHz)','FontSize',18,'FontName','Arial');
    ylabel('Signal Intensity','FontSize',18,'FontName','Arial');
    saveas (gcf,strcat(savepath,MergedData(i).time),'jpg');
    %save(strcat(savepath,save_name(1:13),'CH1_D1_col_buff.mat'),'Ch1');
    close;
end
MergedData(i).time
