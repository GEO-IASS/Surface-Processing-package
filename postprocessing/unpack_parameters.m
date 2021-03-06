function [] = unpack_parameters(desiredPlot, varargin)
% unpacks the output from the surface processing code package.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% INPUT:

% desiredPlot:
%   'FFT'           : power spectrum as determined by the fast fourier analysis
%   'PLOMB'         : periodogram as determined by the plomb analysis
%   'avgAsyms'      : scale dependent average asymetry
%   'topostd'       : RMS plot
%   'topoSkew'      : scale dependent skewness of height fields
%   'topoKurt'      : scale dependent kurtoisis of height fields
%   'PowerVsDisp'   : power at a given scale as a function of displacement
%   'RMSVsDisp'     : model RMS at a given scale as a function of
%                     displacement
%   'Grids'         : shows both the original and pre-processed grid for
%                     the specified file 'fileName'
%   'Best Fits'     : best logarythmic fits to power spectra obtained from
%                     FFT
%   'hurstVsPrefactor': correlation between best fit hurst exponent and
%                     prefactor

% varargin:
%   orientation:
%       'parallel'      : slip parallel analysis
%       'perpendicular  : slip perpendicular analysis
%   scale           : required for 'powerVsDisp'. Also requires displcament
%                     array to be included. Specifies the scales at which
%                     scale the 'powerVsDisp is going to be plotted.
%                     Interpolation is done accoding to the linear
%                     regression model for the entire PLOMB spectrum
%   displacement    :(optional) array with desplacements in the corresponding
%                     order to the input files.
%   Constraint      : Cell array specifying constraint on displacement 
%                     ('Upper Bound' or 'Direct')
%   parameter (with 'PowerVsDisp',orientation, displacement, scale, constraint, ...):
%       'Hurst'         : see the evolution of the Husrt exponent with
%                         displacement
%       'prefactor'     : evolution of the prefactor with displacement
%   fileName        : string with the desired file name for the 'Grids' plot

%   pair-wise inputs:
%       'magnification',mag: specifier magnification followed by the
%                            desired magnification
%       'occular', occular:  "                                                     
%                                                 "
%       'subset',{specifier,subsets}: choose only a subset of all scans
%                                     based on a field characteristic or
%                                     value (e.g. ...,'subset',{magnification,
%                                     [10,20]},...)


% User will be prompted to navigate to the directory in which the surface
% processing output files are stored. The folder must not have anyother
% files inside it.

% OUTPUT:
%   plot of the specified parameters as a function of scale (or displacement)
%   for all input files in directory

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% roughness at a given scale as a function of displacement

if      strcmp(desiredPlot,'PowerVsDisp'        )... 
     || strcmp(desiredPlot,'RMSVsDisp'          ); roughnessVsDisp(varargin); 
elseif  strcmp(desiredPlot,'Grids'              ); plotgrid(varargin);
elseif  strcmp(desiredPlot,'hurstVsPrefactor'   ); hurstVsPrefactor(varargin);
else                                             ; plotspectra(desiredPlot, varargin)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% save plot %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% location = 'C:\Users\kelian_dc\Documents\school\Masters thesis\Thesis\Data_processing\Figures\New PLots'; % desired save location
% saveFileName = [location,'\','LiDar',' - ',desiredPlot,'-',inputs{1},'-',date];
% savefig(saveFileName)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end

%% plot a metric of roughness vs displacement
    function [] = roughnessVsDisp(inputs)

% create a working structure with user info and default settings
[files, numFiles,fileIndex] = getfiles();
[S,subsetLoc,numFiles]= parseInput(inputs,files,numFiles,fileIndex); 

% extract all the info from the strucutre now that it is set
orientation         = S.orientation;   
parameter           = S.parameter;     
scale               = S.scale;   
displacement        = S.displacement;
constraint          = S.constraint;
wellProcessed       = S.wellProcessed;
displacementError   = S.displacementError.*displacement;

% create plots:

% create the displacement "domain" - for line plotting

minD        = min(displacement(displacement~=0));
maxD        = max(displacement);
minmaxD     = [minD,maxD];

Power       = zeros(1,numFiles);
powerError  = zeros(numFiles,2);
fileNameArray = cell(1,numFiles);

for iFile = 1:numFiles
    % run over the subset of files (default is all of them)
    
    % get the file and load it
    fileName            = files(fileIndex(subsetLoc(iFile))).name;
    load(fileName,'parameters')
    fileNameArray{1,iFile} = parameters.fileName;
    
    % get the roughness data
    spectrumType        = 'FFT';
    desiredData         = parameters.(orientation).(spectrumType);
    
    fx                  = desiredData{1,1};
    Px                  = desiredData{1,2};
    
    numFx               = length(fx);
    Px                  = Px(1:numFx);
    
    PxNanInd            = isnan(Px);
    fx                  = fx(~PxNanInd);
    Px                  = Px(~PxNanInd);
    
    % create error bounds or continue with default
    if     strcmp(S.errorBound,'on')
        
        errUp               = desiredData{1,3};
        errDown             = desiredData{1,4};
        
        errorBounds         = [errUp, errDown];
        errorBounds         = errorBounds(1:numFx,:);
        errorBounds         = errorBounds(~PxNanInd,:);
        
    elseif strcmp(S.errorBound,'off')
        errorBounds         = 'off';
    else
        error('error bound must indicate "off" or "on"')
    end
    
    % fit the data
    fitObj                  = makebestfit(fx,Px,'FitMethod',    'section'       , ...
                                                'SectionVal',   S.fractalSection, ...
                                                'error',        errorBounds);
    coefConfInt             = confint(fitObj,0.68);
    coefConfInt(:,2)        = 10.^coefConfInt(:,2);
    
    % this is a bit awkward but fuckit im tired (we basically continue
    % with the same code but instead of using the power we just use the
    % parameter specified by the input exponent (the slope of the best
    % fit line through the data).
        
    if      strcmp(parameter,   'Hurst')      
        Power(iFile)            = -(fitObj.p1+1)/2;
        powerError(iFile,:)     = -(coefConfInt(:,2)+1)/2;
        
    elseif  strcmp(parameter,   'prefactor')      
        Power(iFile)            = 10^fitObj.p2;
        powerError(iFile,:)     = coefConfInt(:,1);
        
    elseif  strcmp(parameter,   'Power')          
        Power(iFile)            = 10.^fitObj(log10(1/scale));
        powerError(iFile,:)     = 10.^predint(fitObj,log10(1/scale),0.68);
        
    elseif  strcmp(parameter,   'RMS')
        % Handle the conversion to RMS as done in Brodsky et al., 2011
        % P(lambda) = C*lambda^BETA
        BETA = fitObj.p1;
        RMS                     = (10^fitObj.p2/(BETA - 1))^0.5*scale*(BETA-1)/2;
        Power(iFile)            = RMS; %... for the purpose of plotting...
        
        BETAconfInt             = coefConfInt(:,1);
        powerError              = (coefConfInt(:,2)./(BETAconfInt-1)).^0.5 ...
                                  .*scale .*(BETAconfInt-1)/2;
                              
    end
    
   
end

% clean out data
nanInd    = isnan(displacement);
zeroInd   = displacement == 0;

% make data same dimension
if size(displacement) ~= size(Power); Power = Power'; end

% classify data

allConstraint   = constraint        (~zeroInd & ~nanInd)';
allDisp         = displacement      (~zeroInd & ~nanInd);
allDispError    = displacementError (~zeroInd & ~nanInd);
allPower        = Power             (~zeroInd & ~nanInd);
allPowerError   = powerError        (~zeroInd & ~nanInd, :);

zeroDispPower       = Power(zeroInd);

upperBoundInd       = strcmp(allConstraint,'Upper Bound');
upperBoundPower     = allPower         (upperBoundInd);
upperBoundPowerErr  = allPowerError    (upperBoundInd, : );
upperBoundDisp      = allDisp          (upperBoundInd);
upperBoundDispError = allDispError     (upperBoundInd);

directInd           = strcmp(allConstraint,'Direct');
directPower         = allPower         (directInd);
directPowerErr      = allPowerError    (directInd, : );
directDisp          = allDisp          (directInd); 
directDispError     = allDispError     (directInd); 

doMonteCarlo = 'on';
if strcmp(doMonteCarlo,'on')
    
    %% fit through all data
    % make DATA, ERROR and errorModel arrays
    
    DATA            = [allDisp',allPower'];
    DATA(upperBoundInd) = DATA(upperBoundInd)/2;
    
    numData         = length(DATA);
    
    %%%%%%%%% temporary: making error arrays %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    dErr                 = allDispError';
    dErr(upperBoundInd)  = allDisp(upperBoundInd)/2;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    pErr      = log(allPowerError(:,2)) - log(allPower');

    ERROR           = [dErr, pErr];
    
    dispErrorModel  = repmat({'gaussian'},numData,1);
    upperBoundInd   = strcmp(allConstraint,'Upper Bound');
    dispErrorModel(upperBoundInd) ...
                    ={'equal'};
    
    powerErrorModel = repmat({'lognormal'},numData,1);

    errorModel      = [dispErrorModel,powerErrorModel];
    [allDataFit,allDataFitError] = runmontecalrofit(1000,DATA,ERROR , ...
                                    'errorModel',      errorModel   , ...
                                    'histogram',       'off'        );
    
    %%  fit through direct data
    % make DATA, ERROR and errorModel arrays
    
    DATA            = [directDisp',directPower'];
    
    numData         = length(DATA);
    
    %%%%%%%%% temporary: making error arrays %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    dErr                 = directDispError';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    pErr      = log(directPowerErr(:,2)) - log(directPower');

    ERROR           = [dErr, pErr];
    
    dispErrorModel  = repmat({'gaussian'},numData,1);    
    powerErrorModel = repmat({'lognormal'},numData,1);

    errorModel      = [dispErrorModel,powerErrorModel];
    [directDataFit,directDataFitError] = runmontecalrofit(1000,DATA,ERROR   , ...
                                    'errorModel',      errorModel           , ...
                                    'histogram',       'off'                );
                                      
end

figure

if strcmp(S.histogram, 'on')
    subplot(1,2,1)
end

hold on

monteCarloAllDataFit    = plot(minmaxD, ...
                               10.^(allDataFit(1)*log10(minmaxD)+allDataFit(2))); 

                           
monteCarloDirectDataFit = plot(minmaxD, ...
                               10.^(directDataFit(1)*log10(minmaxD)+directDataFit(2)));

upperBoundData          = errorbar(upperBoundDisp,  upperBoundPower     , ...
                                  -upperBoundPowerErr(:,1) + upperBoundPower' , ...
                                   upperBoundPowerErr(:,2) - upperBoundPower' , ...
                                   upperBoundDispError                  , ...
                                   upperBoundDispError                  );
                               
directData              = errorbar(directDisp,      directPower         , ...
                                  -directPowerErr(:,1) + directPower'   , ...
                                   directPowerErr(:,2) - directPower'   , ...
                                   directDispError                      , ...
                                   directDispError                      );   

set(upperBoundData, 'LineStyle',        'none'      , ...
                    'Color',            [.7 .7 .7]  , ...
                    'Marker',           's'         , ...
                    'MarkerSize',       5           , ...
                    'MarkerEdgeColor',  [.4 .4 .4]  , ...
                    'MarkerFaceColor',  [1 1 1]     );

set(directData,     'LineStyle',        'none'      , ...
                    'Color',            [.5 .5 .5]  , ...
                    'Marker',           'o'         , ...
                    'MarkerSize',       5           , ...
                    'MarkerEdgeColor',  [0 0 0]     , ...
                    'MarkerFaceColor',  [0 0 0]     );
                
% Zero displacement Data ploted as lines
for iLine = 1:length(zeroDispPower)
    zeroDisplacement = plot(minmaxD, zeroDispPower(iLine)*[1,1], 'r','Linewidth',2);
end
   
    % pass a best fit line through the entire dataset
    % d = fit(goodData,goodPower,'power1');
    % plot(minmaxD,(d.a*minmaxD.^d.b));
    d = polyfit(log10(allDisp),log10(allPower),1);
    
disp(['slope through entire data set: ',num2str(d(1))])

allDataFitLine  = plot(minmaxD,10.^(d(1)*log10(minmaxD)+d(2)));

set(allDataFitLine, 'Color',            [0.5 0.5 0.5], ...
                    'LineWidth',        2            , ...
                    'LineStyle',        '--'         );         
         
% pass a best fit through well constrained data


% pass a best fit line through the entire dataset
%  d = fit(directDisp ,directPower,'power1','Weigths',(2./diff(directPowerErr)).^2);
%  directDataFit = plot(minmaxD,d(minmaxD), 'Linewidth',2);
 

d = polyfit(log10(directDisp),log10(directPower),1);
directDataFitLine = plot(minmaxD,10.^(d(1)*log10(minmaxD)+d(2)));

disp(['slope through direct data set: ',num2str(d(1))])

set(directDataFitLine,  'Color',            'black'     , ...
                        'Linewidth',        3           );

% graphical considerations

hXLabel = xlabel('Displacement (m)');
hYLabel = ylabel(parameter);
hTitle  = title([parameter, ' as a function of displacement at ',num2str(scale),'m using ', spectrumType,' - ' date]);

hLegend = legend([upperBoundData   , directData, zeroDisplacement   , ...
                   allDataFitLine, directDataFitLine]               , ...
                   'Upper bound displacement constraint'            , ...
                   'Direct displacement constraint'                 , ...
                   'Zero displacement bound'                        , ...
                   sprintf('Fit through all data: \\it{P(d) = %0.2g d^{%0.2g \\pm %0.1g}}', ...
                            10^allDataFit(2), allDataFit(1), allDataFitError(2)),  ...
                   sprintf('Fit through data with direct displacement constraint: \\it{P(d) = %0.2g d^{%0.2g \\pm %0.1g}}', ...
                             10^directDataFit(2), directDataFit(1), directDataFitError(2)),  ...
                   'location','SouthWest'                           );
               


               
set( gca                       , ...
    'FontName'   , 'Helvetica' );
set([hTitle, hXLabel, hYLabel], ...
    'FontName'   , 'AvantGarde');
set([hLegend, gca]             , ...
    'FontSize'   , 8           );
set([hXLabel, hYLabel]  , ...
    'FontSize'   , 10          );
set( hTitle                    , ...
    'FontSize'   , 12          , ...
    'FontWeight' , 'bold'      );       

set(gca,            'XScale',           'log'       , ...
                    'YScale',           'log'       );

set(gca, ...
  'XColor'      , [.3 .3 .3], ...
  'YColor'      , [.3 .3 .3], ...
  'LineWidth'   , 1         );
               
% tags to the points for analysis
if strcmp(S.text,'on')
    noLoc       = strcmp(wellProcessed, 'no');
    colorSpec   = zeros(numFiles,3);
    
    for iFile = 1:numFiles
        if noLoc(iFile) == 1
            colorSpec(iFile,:) = [1 0 0];
        end
    end
    offset  = 1.1;
    t       = text(displacement*offset,Power,fileNameArray,...
                  'interpreter', 'none');
    for iFile = 1:numFiles
        t(iFile).Color = colorSpec(iFile,:);
    end
end

hold off

if strcmp(S.histogram, 'on') 
    subplot(1,2,2)
    [counts, bins] = hist(log10(Power));
    barh(bins,counts)
end
end

%% plot Hurst Exponent as a function of Prefactor
    function [] = hurstVsPrefactor(inputs)
    % plots the hurst exponent as a function of theprefacto with the
    % specific intention to extract correlation between these two...
    
% create a working structure with user info and default settings
[files, numFiles,fileIndex] = getfiles();    
[S,subsetLoc,numFiles]   = parseInput(inputs,files,numFiles,fileIndex);

orientation = S.orientation;

% added functonality commented out for the moemen (not completed)
% parameter   = S.parameter;     
% scale       = S.scale;   
% displacement= S.displacement;
% constraint  = S.constraint;
% wellProcessed=S.wellProcessed;

hurst       = zeros(1,numFiles);
prefactor   = zeros(1,numFiles);

fileNameArray           = cell(1,numFiles);

for iFile = 1:numFiles
    % get the file and load it
    fileName            = files(fileIndex(subsetLoc(iFile))).name;
    load(fileName,'parameters')
    
     fileNameArray{1,iFile} = parameters.fileName;
    
    % get the roughness data
    spectrumType        = 'FFT';
    desiredData         = parameters.(orientation).(spectrumType);
    fx                  = desiredData{1};
    Px                  = desiredData{1,2};
    Px                  = Px(1:length(fx));
    PxNanInd            = isnan(Px);
    fx                  = fx(~PxNanInd);
    Px                  = Px(~PxNanInd);
    
    % get the fit
    fitObj              = makebestfit(fx,Px,'FitMethod','section','SectionVal',S.fractalSection);
    
    hurst(iFile)        = (fitObj.b+1)/-2;
    prefactor(iFile)    = fitObj.a;
    
    plot(fitObj,fx,Px)
    
    
end

% a lot more functionality could be added here...

% make the plot

figure
scatter(prefactor,hurst)
title('Correlation between Hurst exponent and Pre-factor')
xlabel('Prefactor')
ylabel('Hurst Exponent')
hold on

% tags to the points for analysis
offset = 1.5;
text(prefactor * offset, hurst,fileNameArray,...
     'interpreter', 'none');
     
hold off
ax = gca;
set(ax,'XScale', 'log', 'YScale', 'log')

end

%% plot a specific, or many, grids (surfaces)
    function [] = plotgrid(inputs)
        
        desiredFileNameArray = inputs{1};
        numGrid  = length(desiredFileNameArray);
        subplotCount = 0;
        
        for iGrid = 1:numGrid
            
            load(desiredFileNameArray{iGrid})
            originalGrid = getfield(parameters,'zGrid');
            cleanGrid    = getfield(parameters,'newZGrid');
            
            subplotCount = subplotCount + 1;
            
            subplot(iGrid,2,subplotCount)
            imagesc(originalGrid)
            axis equal
            xlabel('x')
            ylabel('y')
            title('Original Grid')
            
            subplotCount = subplotCount + 1;
            
            subplot(numGrid,2,subplotCount)
            imagesc(cleanGrid)
            axis equal
            xlabel('Slip Perpendicular')
            ylabel('Slip Parallel')
            titel('Pre-processed Grid')
        end
    end

%% plot all the frequency spectra in a given directory
    function [] = plotspectra(desiredPlot,inputs)
        
    [files, numFiles,fileIndex] = getfiles();
    [S,subsetLoc,numFiles]= parseInput(inputs,files,numFiles,fileIndex); 

    % extract all the info from the strucutre now that it is set
    orientation         = S.orientation;          
    displacement        = S.displacement;
    constraint          = S.constraint;

    % create plots:
    
    % create the displacement "domain" - for line plotting
    if any(displacement ~= 0)
        minD        = min(displacement(displacement~=0));
        maxD        = max(displacement);
        logMinD = log10(minD);
        logMaxD = log10(maxD);
        logDelD = logMaxD-logMinD;
    end
    
    legendArray = cell(1,numFiles);
    hold on
    
    % loop over files
    for iFile = subsetLoc
        fileName            = files(fileIndex(iFile)).name;
        load(fileName,'parameters')
        
        if strcmp(desiredPlot,'best fits')
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            spectrumType        = 'FFT';
            desiredData         = parameters.(orientation).(spectrumType);
            fx                  = desiredData{1,1};
            Px                  = desiredData{1,2};
            
            numFxIn             = length(fx);
            
            Px                  = Px(1:numFxIn);
            
            PxNanInd            = isnan(Px);
            fx                  = fx(~PxNanInd);
            Px                  = Px(~PxNanInd);
            
            try
                errUp               = desiredData{1,3}';
                errDown             = desiredData{1,4}';
                errorArray          = [errUp,errDown];
                errorArray          = errorArray(1:numFxIn,:);
                errorArray          = errorArray(~PxNanInd,:);
            catch
                errorArray          = 'off';
            end

            fitObj              = makebestfit(fx,Px,'FitMethod',     'section'   , ...
                'SectionVal',    0.03        , ...
                'error',         errorArray  );
            plot(fitObj,fx,Px);       
            if ~strcmp(errorArray,'off')
                shadedErrorBar(fx,Px,errorArray','k',1);
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
%             desiredStruct   = getfield(getfield(parameters, orientation),'FFT');
%             desiredCell     = desiredStruct;
%             
%             wavelength      = 1./desiredCell{1};
%             power           = desiredCell{2};
%             
%             power           = power(1:length(wavelength));
%             nanInd          = isnan(power);
%             power           = power(~nanInd);
%             wavelength      = wavelength(~nanInd);
%             
%             d               = polyfit(log10(wavelength'),log10(power),1);
%             x               = [min(wavelength),max(wavelength)];
%             y               = 10.^(d(1)*log10(x)+d(2));
            
        else
            desiredStruct   = getfield(getfield(parameters, orientation),desiredPlot);
            
            % decide what plot to do (enable plot-specific attributes)
            if strcmp(desiredPlot,'FFT') || strcmp(desiredPlot,'PLOMB')
                desiredCell     = desiredStruct;
                x               = desiredCell{1};
                x               = 1./x;
                y               = desiredCell{2};
                y               = y(1:length(x));
                
            else
                x               = getfield(getfield(parameters, orientation),'Scales');
                if strcmp(desiredPlot, 'avgAsyms')
                    badInd          = isnan(desiredStruct)|desiredStruct == 0;
                    y               = abs(desiredStruct(~badInd));
                    x               = x(~badInd);
                else
                    y               = desiredStruct;
                    y               = y(y~=0);
                    x               = x(y~=0);
                end
                
            end
            
            plot(x,y,'.-')
            

        end
        
        scanName = getfield(parameters,'fileName');
        legendArray{1,iFile} = fileName; 
            
        % set color as a function of displacement
        if displacement(iFile) == 0
            colorForDisp = [0 1 0];
        else
            colorInd = (log10(D(iFile))-logMinD)/(2*(logDelD));
            colorForDisp = [0.5-colorInd, 0.5-colorInd, 0.5-colorInd];
        end
        
        % set unknow displacements to grey
        if sum(isnan(colorForDisp)) ~= 0
            colorForDisp = [0.5, 0.5, 0.5];
        end
        
        p = plot(x,y,'-');
        p.Color = colorForDisp;
        formatSpec = 'D = %d - file: %s';
        legendArray{1,iFile} = sprintf(formatSpec, D(iFile), ...
            scanName);
        xlabel('Scale (m)')

        
        % to help distinguish points whith various constraints on displacement
        if strcmp(constraint{iFile}, 'Direct')
            p.LineWidth = 3;
        elseif strcmp(constraint{iFile},'Upper Bound')
            p.LineWidth = 0.2;
        end
        
        
        
        ylabel(desiredPlot)
        title([desiredPlot,' as a function of scale - ', orientation, date])
        
        if strcmp(desiredPlot,'topostd') || strcmp(desiredPlot,'FFT')|| ...
                strcmp(desiredPlot,'PLOMB')
            set(gca,'XScale','log','YScale','log')
            xlabel('Scale (log(m))')
        end
    end
    
    
    
    legend(legendArray,'interpreter', 'none')
    
    end

%% small function to query the files in the desired directory
    function [files, numFiles, fileIndex] = getfiles()
    
        directory_name = uigetdir;
        files = dir(directory_name);
        addpath(directory_name)
        
        save('files', 'files')
        fileIndex = find(~[files.isdir]                         & ...
                         ~ strcmp({files.name},'._.DS_Store')   & ...
                         ~ strcmp({files.name},'.DS_Store'));
        numFiles  = length(fileIndex);
    end

    
%% input parsing functions (if you want to add input options here is the place)
    function [S, SUBSETLOC, NUMFILES] = parseInput(inputs, files, numFiles, fileIndex)

% identify data

% possible inputs (not recomended, use addscaninfo instead beforehand)
scanInputInfo = {'displacement'         , ...
                 'constraint'           , ...
                 'displacementError'    , ...
                 'wellProcessed'        , ...
                 'magnification'        , ...
                 'occular'              };
numScanInfo   = length(scanInputInfo);
             
userInput     = {'orientation'          ,...    % slip parallel or perprendicular
                 'parameter'            ,...    % what parameter to plot as a function of displacement
                 'scale'                ,...    % length scale of interpolation
                 'fractalSection'       ,...    % select a section of the spectra to measure slope
                 'subset'               ,...    % select a subset of scans 
                 'text'                 ,...    % make tags next to points
                 'histogram'            ,...    % place histogram of roughness measurements next to plot
                 'errorBound'           ,...    % make erro bounds on plot
                 'bootstrap'            };      % run boostrp of the fit   
numUserInput  = length(userInput);

numInputs = length(inputs);

if numInputs ~=0
    for iInput = 1:2:length(inputs)
        if ~any([strcmp(inputs(1,iInput),scanInputInfo), ...
                strcmp(inputs(1,iInput),userInput)])
            message = ['input number ',(inputs(1,iInput)),' not allowed'];
            error(message)
        end
    end
end

% default input values:
defaultInput                = [];
defaultInput.orientation    = 'parallel';
defaultInput.parameter      = 'Power';
defaultInput.wellProcssed   = repmat({'yes'},1,numFiles);
defaultInput.constraint     = repmat({'Direct'},1,numFiles);
defaultInput.scale          = 0.01;
defaultInput.fractalSection = 0.03;
defaultInput.text           = 'off';
defaultInput.histogram      = 'off';
defaultInput.errorBound     = 'off';
defaultInput.boostrap       = 'off';

defaultInput.displacementError = ones(1,numFiles)*0.2;

% query info in the parameter structure of the files

% init arrays
S = defaultInput;
S.constraint                = cell(1,numFiles);
S.displacement              = zeros(1,numFiles);
S.wellProcessed             = cell(1,numFiles);
S.magnification             = zeros(1,numFiles);
S.occular                   = zeros(1,numFiles);

for iFile = 1:numFiles  
    
    fileName            = files(fileIndex(iFile)).name;
    load(fileName,'parameters')
    
    % query fields if they exist
    for iInput = 1:numScanInfo
        f = char(scanInputInfo(1,iInput));
        if isfield(parameters,f)
            if isa(parameters.(f), 'char')
                S.(f){1,iFile}   = ...
                parameters.(f);   
            elseif isa(parameters.(f), 'double')
                S.(f)(1,iFile)   = ...
                parameters.(f); 
            else
                error('unrecognized variable type, must be cell or double')
            end
        end
    end
end

% user specified analysis data (if done so by user)
for iInput = 1:numUserInput
    S       = setVal(S,userInput(1,iInput),inputs);
end

% user specified scan info (if done so by user)
for iInput = 1:numScanInfo
    S       = setVal(S,scanInputInfo(1,iInput),inputs);
end

% select a subset of the files based on a parameter:
if isfield(S,'subset')
    subsetInd   = S.(S.subset{1,1}) == S.subset{1,2};
else 
    subsetInd   = ones(1,numFiles); 
end
SUBSETLOC   = find(subsetInd);
NUMFILES    = sum(subsetInd);

for iScanInfo = 1:numScanInfo          
    S.(scanInputInfo{1,iScanInfo}) = S.(scanInputInfo{1,iScanInfo})(1,SUBSETLOC);
end
   
    end


    
