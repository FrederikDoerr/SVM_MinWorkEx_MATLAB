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

fprintf('%s - Start Two Class-SVM\n',Opt.ExpShorthand)


DTR = table2array(DTR_T(:,idx_relieff_SEL));
DTR_Class = table2array([DS0(:,2);DS1(:,2);DS2(:,2)]);

DTT = table2array(DTT_T(:,idx_relieff_SEL));
DTT_Class = table2array([DS3(:,2);DS4(:,2);DS5(:,2)]);

Var1_label = 'V_{maxFeretSph,F,V\_ROI}';
Var2_label = 'SF_{Elps,SA,r3,V\_ROI} [um]';

% Parameter
KernelFunction_mdl = 'rbf';
Cost_Fct = ceil(length(DTR(DTR_Class==1,2))/length(DTR(DTR_Class==2,2)));



%% Train nDim TC-SVM Model
rng(1);

% Bayesian Optimisation Settings
c = cvpartition(DTR_Class,'KFold',4);
opts = struct('Optimizer','bayesopt',...
    'CVPartition',c, ...
    'MaxObjectiveEvaluations',30,...
    'AcquisitionFunctionName','expected-improvement-plus');

SVMModel_nDim = fitcsvm(DTR,DTR_Class, ...
'Standardize',true, ...
'Prior','uniform',...
'Cost',[0,1;Cost_Fct,0],...
'KernelFunction',KernelFunction_mdl, ...
'OptimizeHyperparameters','auto',...
'HyperparameterOptimizationOptions',opts);   

BoxConstraint = mean(SVMModel_nDim.BoxConstraints);
BoxConstraint_min = min(SVMModel_nDim.BoxConstraints);
BoxConstraint_max = max(SVMModel_nDim.BoxConstraints);

%% Train SVM Model - 2D for visualisation
rng(1);
SVMModel = fitcsvm(DTR(:,[1,2]),DTR_Class, ...
    'KernelScale','auto', ...
    'BoxConstraint', BoxConstraint, ...
    'Standardize',true, ...
    'Prior','uniform',...
    'Cost',[0,1;Cost_Fct,0],...
    'KernelFunction',KernelFunction_mdl);
  
   
sv = DTR(SVMModel.IsSupportVector,:);


%% Grid for 2D visualisation

h_n = 1000;
[x1Grid,x2Grid] = meshgrid( ...
    linspace(min([DTT(:,1);DTR(:,1)]), ...
    max([DTT(:,1);DTR(:,1)]),h_n),...
    linspace(min([DTT(:,2);DTR(:,2)]), ...
    max([DTT(:,2);DTR(:,2)]),h_n));

[~,score] = predict(SVMModel,[x1Grid(:),x2Grid(:)]);
scoreGrid = reshape(score(:,1),size(x1Grid,1),size(x2Grid,2));


%% Find Datapoints that are re-assigned to other class
[label,score] = predict(SVMModel,DTT(:,[1,2]));
[label_nDim,score_nDim] = predict(SVMModel_nDim,DTT);
Error_Class_1 = sum(((label_nDim==1) ~= (DTT_Class==1)).*(DTT_Class==1));
Error_Class_2 = sum(((label_nDim==2) ~= (DTT_Class==2)).*(DTT_Class==2));
Error_Class_1_max = sum(DTT_Class(DTT_Class==1));
Error_Class_2_max = length(DTT_Class(DTT_Class==2));

[~,score_Train] = predict(SVMModel,DTR(:,[1,2]));
[~,score_Train_nDim] = predict(SVMModel_nDim,DTR);

idx_ReLabeled = find(label~=label_nDim);

%% SVM-TC Graph

    
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


% Plot Training Data
plot(DTR(DTR_Class==1,1),DTR(DTR_Class==1,2),'DisplayName','Class Non-broken (Training)', ...
    'MarkerFaceColor',c1_RGB,...
    'Marker','o',...
    'LineWidth',1,...
    'LineStyle','none',...
    'Color',[0 0 0]);
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
plot(sv(:,1),sv(:,2),'ko','MarkerSize',10,'DisplayName','Support Vector')

  
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

xlabel(Var1_label)
ylabel(Var2_label)
axis([min([DTT(:,1);DTR(:,1)]), ...
    max([DTT(:,1);DTR(:,1)]), ...
    min([DTT(:,2);DTR(:,2)]), ...
    max([DTT(:,2);DTR(:,2)])])
 
a = annotation(fig,'textbox',...
    [0.13 0.92 0.765071428571429 0.0571428571428568],...
    'String',{sprintf('Two-Class SVM: Kernel = %s, Prior = 1:%.0f, BoxC = %.2f (%.2f - %.2f) \nTest Data: Error Class Non-Broken %.0f/%.0f, Error Class Broken %.0f/%.0f', ...
    KernelFunction_mdl,Cost_Fct,BoxConstraint,min(SVMModel_nDim.BoxConstraints),max(SVMModel_nDim.BoxConstraints),Error_Class_1,Error_Class_1_max,Error_Class_2,Error_Class_2_max)},...
    'FitBoxToText','on');

print(fullfile(Opt.ExportFolder_path,sprintf('%s_SVMTwoClass',Opt.ExpShorthand)),'-djpeg','-r300')
    
