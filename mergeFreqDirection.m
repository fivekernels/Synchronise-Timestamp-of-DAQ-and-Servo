clear variables;

ExcelMode_ppi = 1; % 伺服工作模式 五波束=0 ppi=1 对应的csv字段格式不同
MatchSecond = [-0.35,0.35]; % 匹配时间阈值 闭区间 秒

servoFilePath = '.\ServoFile\';
daqFilePath = '.\daqFiles\';


MergeFreqDirectionData = struct('time', '', 'direction', '', 'Azimuth', NaN, 'pitch', NaN, 'dirGroup', NaN, 'data', NaN(1, 1500));
MergeFreqDirection = repmat(MergeFreqDirectionData, [ 1,  ceil(size(directionXlsData, 1)*2.5) ] ); % 预分配 按照原始csv行数的<2.5>倍分配
MergeStruct_Index = 1;

% 读采集卡txt
dacFileTree = dir([daqFilePath, '*.txt']);
dacFileNum = size(dacFileTree,1);
dacFile_Index = 1; % 文件夹内采集卡txt文件index
fprintf("loading initial dac txt: %s...\n", dacFileTree(dacFile_Index).name);
dacTxtData = importDACtxt([daqFilePath, dacFileTree(dacFile_Index).name]);

% 读方位信息
directionXlsData = importDirectionExcel('.\filename');
dirXls_index = 1; % excel 文件内下一个读取行数
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
            MergeFreqDirection(MergeStruct_Index).time = dacTimeStr;
            if ExcelMode_ppi == 1
                MergeFreqDirection(MergeStruct_Index).Azimuth = str2double(string(directionXlsData{dirXls_index,5}));
                MergeFreqDirection(MergeStruct_Index).pitch = directionXlsData{dirXls_index,6};
            else
                MergeFreqDirection(MergeStruct_Index).direction = string(directionXlsData{dirXls_index,5});
                MergeFreqDirection(MergeStruct_Index).pitch = directionXlsData{dirXls_index,7};
            end
            MergeFreqDirection(MergeStruct_Index).dirGroup = dirXls_index; % 标识当前数据对应伺服csv的数据行号 同一行csv匹配的所有txt具有相同的group
            MergeFreqDirection(MergeStruct_Index).data = hex2dec(dacTxtData{daqTxt_index,(1)*2+1:2:(1500)*2+1});
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
            dacTxtData = importDACtxt([daqFilePath, dacFileTree(dacFile_Index).name]);
            daqTxtIndexRecord = 1;
            continue;
        else
            disp("not enough DAQ txt to match last Servo csv rows");
            break;
        end
    end
    dirXls_index = dirXls_index + 1;
end

MergeFreqDirection(MergeStruct_Index:end) = []; % 清理多余预分配

% % debug
% directionTimeStr = "20220101 00:01:10.195";
% dacTimeStr = "20211231-235900245";
% timeDir = datevec(directionTimeStr, 'yyyymmdd HH:MM:SS.FFF');
% timeDac = datevec(dacTimeStr, 'yyyymmdd-HHMMSSFFF');
% dateNumDir = datenum(directionTimeStr, 'yyyymmdd HH:MM:SS.FFF');
% dateNumDac = datenum(dacTimeStr, 'yyyymmdd-HHMMSSFFF');
% 
% etime(timeDir, timeDac)
% etime(timeDac, timeDir)

% 取一组所有频率中最大的频率对应的下标
specificDirFreq = NaN(ceil(size(MergeFreqDirection, 2)/1), 1); %预分配 配合将来剔除信噪比等使用
specificDirFreq_index = 1;
ridFreqSratr = 1; % 去除第一个0频高值
for MergeFreqDirection_index = 1 : size(MergeFreqDirection, 2)
    [maxData, maxIndex] = max( MergeFreqDirection(MergeFreqDirection_index).data(1+ridFreqSratr:end) ); %删除零频率位置得到最大频移点
    specificDirFreq(specificDirFreq_index) = maxIndex + ridFreqSratr;
    specificDirFreq_index = specificDirFreq_index + 1;
end
specificDirFreq(specificDirFreq_index:end) = [];
plot(specificDirFreq*0.775*250/8192); % 频率转化速度


% 饼
% for angleArr_Index = 1 : size(MergeFreqDirection, 2)
for angleArr_Index = 1 : 28
    angleArr(angleArr_Index) = MergeFreqDirection(angleArr_Index).Azimuth;
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

% 结构体添加速度属性
specificSpeed = specificDirFreq*0.775*250/8192;
for struct_i = 1 : size(MergeFreqDirection, 2)
    MergeFreqDirection(struct_i).speed = specificSpeed(struct_i);
end

% 同一行csv匹配的数据只保留一个
% bug: 前两行重复无法剔除?
a = 1;
for i= 1:MergeFreqDirection_index-1
    MergeFreqDirection_del(1) = MergeFreqDirection(1);
   
    if isequal(MergeFreqDirection(i).dirGroup,MergeFreqDirection(i+1).dirGroup) == 0
        a = a+1;
        MergeFreqDirection_del(a) = MergeFreqDirection(i);
    end
end
%% 绘制每一次测量的频谱图像
data_num = size(MergeFreqDirection_del,2);
savepath = 'F:\不关我的事\';
for i = 2764:data_num
    
    plot(MergeFreqDirection_del(i).data);
    set(gca,'FontSize',10,'fontname','Arial');
    title('FFT','FontSize',20,'FontName','Arial');
    xlabel('Frequency(MHz)','FontSize',18,'FontName','Arial');
    ylabel('Signal Intensity','FontSize',18,'FontName','Arial');
    saveas (gcf,strcat(savepath,MergeFreqDirection_del(i).time),'jpg');
    %save(strcat(savepath,save_name(1:13),'CH1_D1_col_buff.mat'),'Ch1');
    close;
end
MergeFreqDirection_del(i).time