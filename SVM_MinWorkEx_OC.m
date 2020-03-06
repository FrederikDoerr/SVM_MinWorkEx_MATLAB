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
% 
% MATLAB Links:
% https://uk.mathworks.com/help/stats/fitcsvm.html
% https://uk.mathworks.com/help/stats/support-vector-machines-for-binary-classification.html

fprintf('%s - Start One Class-SVM\n',Opt.ExpShorthand)

% Convert table to data matrix
DTR = table2array(DTR_T(:,idx_relieff_SEL));
DTR_Class = table2array([DS0(:,2);DS1(:,2);DS2(:,2)]);

DTT = table2array(DTT_T(:,idx_relieff_SEL));
DTT_Class = table2array([DS3(:,2);DS4(:,2);DS5(:,2)]);

Var1_label = 'V_{maxFeretSph,F,V\_ROI} [?m]';
Var2_label = 'SF_{Elps,SA,r3,V\_ROI}';

% Parameter
KernelFunction_mdl = 'rbf';
Nu = 1;
ClassNames = [1,2];

KernelScale = 'auto';
KernelOffset = 0;

%% Train nDim OC-SVM Model
rng(1);    
SVMModel_OneC_nDim = fitcsvm(DTR(DTR_Class == 1,:),DTR_Class(DTR_Class == 1), ...
    'KernelFunction',KernelFunction_mdl, ... 
    'KernelScale',KernelScale, ...
    'KernelOffset',KernelOffset, ...
    'Standardize',true, ...
    'OutlierFraction',0, ...
    'Nu',Nu, ...
    'ClassNames',ClassNames);


%% Train SVM Model - 2D for visualisation
rng(1);
SVMModel_OneC = fitcsvm(DTR(DTR_Class == 1,[1,2]),DTR_Class(DTR_Class == 1), ...
    'KernelFunction',KernelFunction_mdl, ...
    'KernelScale',KernelScale, ...
    'KernelOffset',KernelOffset, ...
    'Standardize',true, ...
    'OutlierFraction',0, ...
    'Nu',Nu, ...
    'ClassNames',ClassNames);

sv = SVMModel_OneC.IsSupportVector;


h_n = 1000;
[x1Grid,x2Grid] = meshgrid( ...
    linspace(min([DTT(:,1);DTR(:,1)]), ...
    max([DTT(:,1);DTR(:,1)]),h_n),...
    linspace(min([DTT(:,2);DTR(:,2)]), ...
    max([DTT(:,2);DTR(:,2)]),h_n));

[~,score] = predict(SVMModel_OneC,[x1Grid(:),x2Grid(:)]);
scoreGrid = reshape(score(:,1),size(x1Grid,1),size(x2Grid,2));




%% Find Datapoints that are re-assigned to other class
[label,score] = predict(SVMModel_OneC,DTT(:,[1,2]));
[label_nDim,score_nDim] = predict(SVMModel_OneC_nDim,DTT);

Error_Class_1 = sum(((label==1) ~= (DTT_Class==1)).*(DTT_Class==1));
Error_Class_2 = sum(((label==2) ~= (DTT_Class==2)).*(DTT_Class==2));
Error_nDim_Class_1 = sum(((label_nDim==1) ~= (DTT_Class==1)).*(DTT_Class==1));
Error_nDim_Class_2 = sum(((label_nDim==2) ~= (DTT_Class==2)).*(DTT_Class==2));
Error_nDim_Class_1_max = sum(DTT_Class(DTT_Class==1));
Error_nDim_Class_2_max = length(DTT_Class(DTT_Class==2));

idx_ReLabeled = find(label~=label_nDim);
idx_ReLabeled_pos = find((label==2)&(label_nDim==1));
idx_ReLabeled_neg = find((label==1)&(label_nDim==2));


%% SVM-OC Graph

c1_RGB = round([43,131,186]./255,2); % blue
c1_RGB_s = round([189,201,225]./255,2); % light blue
c2_RGB = round([215,25,28]./255,2); % red
c2_RGB_s = round([253,174,97]./255,2); % light red

inch_width = 1750/300;
inch_height = 1313/300;
inch_height= inch_height +0.5;

fig = figure('units','inch','position',[1 1 inch_width inch_height]);
axes1 = axes('Parent',fig,...
    'Position',[0.13 0.125 0.78 0.75]);
hold(axes1,'on');
box(axes1,'on');


% Plot Training Data (foreground)
plot(DTR(DTR_Class==1,1),DTR(DTR_Class==1,2),'DisplayName','Class Non-broken (Training)', ...
    'MarkerFaceColor',c1_RGB,...
    'Marker','o',...
    'LineWidth',1,...
    'LineStyle','none',...
    'Color',[0 0 0]);
hold on
% Create plot
plot(DTR(DTR_Class==2,1),DTR(DTR_Class==2,2),'DisplayName','Class Broken (Training)', ...
    'MarkerFaceColor',c2_RGB,...
    'Marker','square',...
    'LineWidth',1,...
    'LineStyle','none',...
    'Color',[0 0 0]);

% Plot Test Data
plot(DTT(DTT_Class==1,1),DTT(DTT_Class==1,2),'DisplayName','Class Non-broken (Test)', ...
    'MarkerFaceColor',c1_RGB_s,...
    'Marker','o',...
    'LineWidth',1,...
    'LineStyle','none',...
    'Color',[0 0 0]);
plot(DTT(DTT_Class==2,1),DTT(DTT_Class==2,2),'DisplayName','Class Broken (Test)', ...
    'MarkerFaceColor',c2_RGB_s,...
    'Marker','square',...
    'LineWidth',1,...
    'LineStyle','none',...
    'Color',[0 0 0]);


% Mark Support Vectors
DTR_OC_sv = DTR(DTR_Class==1,:);
plot(DTR_OC_sv(sv,1),DTR_OC_sv(sv,2),'ko','MarkerSize',10,'DisplayName','Support Vector')

% Mark ReLabeled observations (nDim)
if ~isempty(idx_ReLabeled)
    p_ReLabeled = plot(DTT(idx_ReLabeled,1),DTT(idx_ReLabeled,2), ...
        'kx','MarkerSize',10,'DisplayName','Re-Labeled n-Dim');
    p_ReLabeled.LineWidth = 2;
else
    p_ReLabeled = plot(0,0,'kx','MarkerSize',10);
    p_ReLabeled.LineWidth = 2;
end

lgd = legend('Location','SouthEast','AutoUpdate','off');

% Plot the decision boundary
[C,h] = contour(x1Grid,x2Grid,scoreGrid,[0 0],'k','LineWidth',1.5);
clabel(C,h,'EdgeColor','k')
[C,h] = contour(x1Grid,x2Grid,scoreGrid,[1 1],'k--','LineWidth',1.5);
clabel(C,h,'EdgeColor','k')
[C,h] = contour(x1Grid,x2Grid,scoreGrid,[-1 -1],'k--','LineWidth',1.5);
clabel(C,h,'EdgeColor','k')

hold off
xlabel(Var1_label)
ylabel(Var2_label)
axis([min([DTT(:,1);DTR(:,1)]), ...
    max([DTT(:,1);DTR(:,1)]), ...
    min([DTT(:,2);DTR(:,2)]), ...
    max([DTT(:,2);DTR(:,2)])])

a = annotation(fig,'textbox',...
    [0.13 0.92 0.765071428571429 0.0571428571428568],...
    'String',{sprintf('One-Class SVM: Kernel = %s, Nu = %.2f\nTest Data: Error Class Non-Broken %.0f/%.0f, Error Class Broken %.0f/%.0f', ...
    KernelFunction_mdl,Nu,Error_nDim_Class_1,Error_nDim_Class_1_max,Error_nDim_Class_2,Error_nDim_Class_2_max)},...
    'FitBoxToText','on');
print(fullfile(Opt.ExportFolder_path,sprintf('%s_SVM_OneClass',Opt.ExpShorthand)),'-djpeg','-r300')


