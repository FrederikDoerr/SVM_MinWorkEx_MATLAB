%------------------------------------------------------------------------------------------------
% Code written by Frederik Doerr, Feb 2020 (MATLAB R2019b)
% Application: For 'Support Vector Machine - Introduction and Application'
% Contact: frederik.doerr@strath.ac.uk / CMAC (http://www.cmac.ac.uk/)

% % % Reference (open access):
% Doerr, F. J. S., Florence, A. J. (2020)
% A micro-XRT image analysis and machine learning methodology for the characterisation of multi-particulate capsule formulations. 
% International Journal of Pharmaceutics: X. 
% https://doi.org/10.1016/j.ijpx.2020.100041
% Data repository: https://doi.org/10.15129/e5d22969-77d4-46a8-83b8-818b50d8ff45
% Video Abstract: https://strathprints.strath.ac.uk/id/eprint/71463
%------------------------------------------------------------------------------------------------

clear all %#ok<CLALL>
close all
clc

set(0,'DefaultFigureVisible','on');

%% Setup
Opt.ExpShorthand = 'SVM_MinWorkEx';

% Main folder location
path = matlab.desktop.editor.getActiveFilename;
[Opt.mainFolder_path,name,ext] = fileparts(path);

Opt.ExportFolder_name = sprintf('%s_Export_%s',Opt.ExpShorthand,datestr(now,'yyyy-mm-dd'));
Opt.ExportFolder_path = fullfile(Opt.mainFolder_path,Opt.ExportFolder_name);
if ~exist(Opt.ExportFolder_path,'dir')
    mkdir(Opt.ExportFolder_path)
end
cd(Opt.ExportFolder_path)

% Import measured data (features)
Opt.InputFolder_path = fullfile(Opt.mainFolder_path,'_Data');
Opt.InputFile_name_list = {...
    'Desc_DataFile_C0.csv', ...
    'Desc_DataFile_C1.csv', ...
    'Desc_DataFile_C2.csv', ...
    'Desc_DataFile_C3.csv', ...
    'Desc_DataFile_C4.csv', ...
    'Desc_DataFile_C5.csv', ...
    };

Opt.D_Cat_name = 'Feature_Categories.csv';
Opt.D_SenAnlys_name = 'Feature_SenAnlys_Score.csv';

D_Cat = readtable(fullfile(Opt.InputFolder_path,Opt.D_Cat_name));
D_SenAnlys = readtable(fullfile(Opt.InputFolder_path,Opt.D_SenAnlys_name));

fprintf('%s - Setup complete\n',Opt.ExpShorthand)

%% Load DataSet

numDS = length(Opt.InputFile_name_list);

DS0 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{1}));
DS1 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{2}));
DS2 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{3}));
DS3 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{4}));
DS4 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{5}));
DS5 = readtable(fullfile(Opt.InputFolder_path,Opt.InputFile_name_list{6}));
numObs = sum([size(DS0,1),size(DS1,1),size(DS2,1),size(DS3,1),size(DS4,1),size(DS5,1)]);
numFeat = size(DS0,2)-2; %  Two columns related to ID and Class

fprintf('%s - Imported %.0f files with measured data from %.0f observations related to %.0f features\n',Opt.ExpShorthand,numDS,numObs,numFeat)


%% Split Data in training and testdata 
% here, assigned indvidual capsules with distribution of pellets to optimise validation for data collection effects, commonly requires randomoised selection
% Class: Non-broken = 1, broken = 2

% Training data
DTR_T = [DS0(:,3:end);DS1(:,3:end);DS2(:,3:end)];

% Test data
DTT_T = [DS3(:,3:end);DS4(:,3:end);DS5(:,3:end)];


fprintf('%s - Defined Training and Testdata\n',Opt.ExpShorthand)

%% Remove feature with high variability (sensitivity analysis)
D_SenAnlys_cutOff = 0.1;

idx_SA_DEL = find((abs(D_SenAnlys.Max) > D_SenAnlys_cutOff)|(abs(D_SenAnlys.Min) > D_SenAnlys_cutOff));
idx_DEL_matched = nan(length(idx_SA_DEL),1);
for k = 1:length(idx_SA_DEL)
    idx = find(strcmp(D_SenAnlys.Feature{idx_SA_DEL(k)},DTR_T.Properties.VariableNames));
    idx_DEL_matched(k) = idx;
end

DTR_T(:,idx_DEL_matched) = [];
DTT_T(:,idx_DEL_matched) = [];

fprintf('%s - Sensitivity analysis identified %.0f features with a variability > %.2f%%\n',Opt.ExpShorthand,length(idx_SA_DEL),D_SenAnlys_cutOff*100)

%% ReliefF Feature Selection
% https://uk.mathworks.com/help/stats/relieff.html

% Convert table to data matrix
DTR = table2array(DTR_T);
DTR_Class = table2array([DS0(:,2);DS1(:,2);DS2(:,2)]);

DTT = table2array(DTT_T);
DTT_Class = table2array([DS3(:,2);DS4(:,2);DS5(:,2)]);

% Run ReliefF Feature Selection
% Including all observations of the minority class ensures maximum robustness against noise, but limits the detection of feature dependencies in the context of nearest neighbor locality to the majority class 
k_relieff = size(DTR_Class(DTR_Class==2),1);
[idx_relieff,weights] = relieff(DTR,DTR_Class,k_relieff);


figure; bar(weights(idx_relieff))
xlabel('Predictor rank')
ylabel('Predictor importance weight')


fprintf('%s - ReliefF (Full Feature Ranking)\n',Opt.ExpShorthand)
h_ttest2 = nan(size(idx_relieff,2),1);
for k = 1:size(idx_relieff,2)  
    % Run ttest2 (h is 1 if the test rejects the null hypothesis of equal means at a 5% significance level)
    [h,p,ci,stat] = ttest2(DTR(DTR_Class==1,idx_relieff(k)),DTR(DTR_Class==2,idx_relieff(k)),'Vartype','unequal');
    h_ttest2(idx_relieff(k)) = h;
    
    fprintf('\t Rank %.0f - %s (weights %.2f, p = %.2f)\n',k,DTR_T.Properties.VariableNames{idx_relieff(k)},weights(idx_relieff(k)),p)
end

% Select best performing feature of each independent feature category
CatC = unique(D_Cat.Feature_Category);

numCatC = size(CatC,1);
idx_CatC = nan(size(CatC,1),1);
for k = 1:numCatC
    idxCat = find(strcmp(CatC{k},D_Cat{:,2}));
    idx_matched = nan(length(idxCat),1);
    for i = 1:length(idxCat)
        idx = find(strcmp(D_Cat.Feature{idxCat(i)},DTR_T.Properties.VariableNames));
        if ~isempty(idx)
            idx_matched(i) = idx;
        end
    end
    idx_matched = rmmissing(idx_matched);
    if ~isempty(idx_matched)
        % Acceptance criteria (best ranked in each structure-related categories and rejects the null hypothesis of equal means of ttest2) 
        idx = find((weights(idx_matched) == max(weights(idx_matched)))&(h_ttest2(idx_matched).'));
        if ~isempty(idx)
            idx_CatC(k) = idx_matched(idx);
            fprintf('Feature identified: %s (category: %s)\n',DTR_T.Properties.VariableNames{idx_CatC(k)},CatC{k})
        end
    end
end
idx_relieff_SEL = rmmissing(idx_CatC);

fprintf('%s - ReliefF (Selected Features)\n',Opt.ExpShorthand)
for k = 1:length(idx_relieff_SEL)
    fprintf('\t Rank %.0f - %s (weights %.2f)\n',k,DTR_T.Properties.VariableNames{idx_relieff_SEL(k)},weights(idx_relieff_SEL(k)))
end

%% Support Vector Machine - One Class
addpath(Opt.mainFolder_path)
run SVM_MinWorkEx_OC.m


%% Support Vector Machine - Two Class
addpath(Opt.mainFolder_path)
run SVM_MinWorkEx_TC.m







