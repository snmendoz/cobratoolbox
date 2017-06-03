function [mustUL, pos_mustUL, mustUL_linear, pos_mustUL_linear] = findMustUL(model, ...
    minFluxesW, maxFluxesW, constrOpt, excludedRxns, runID, outputFolder,...
    outputFileName, printExcel, printText, printReport, keepInputs, verbose)
%% DESCRIPTION
% This function runs the second step of optForce, that is to solve a
% bilevel mixed integer linear programming  problem to find a second order
% MustUL set. This script is based in the GAMS files written by Sridhar
% Ranganathan which were provided by the research group of Costas D.
% Maranas.
%
% Ranganathan S, Suthers PF, Maranas CD (2010) OptForce: An Optimization
% Procedure for Identifying All Genetic Manipulations Leading to Targeted
% Overproductions. PLOS Computational Biology 6(4): e1000744.
% https://doi.org/10.1371/journal.pcbi.1000744

% Usage1: findMustUL(model, minFluxesW, maxFluxesW)
%         basic configuration for running the optimization problem in GAMS
%         to find the MustU set.

% Usage2: findMustUL(model, minFluxesW, maxFluxesW, option 1, ..., option N)
%         specify additional options such as fixed reactions, solver or if
%         results shoulds be saved in files or not.

% Created by Sebastián Mendoza. 30/05/2017. snmendoz@uc.cl

%% INPUTS
% model (obligatory):       Type: struct (COBRA model)
%                           Description: a metabolic model with at least
%                           the following fields:
%                           rxns            Reaction IDs in the model
%                           mets            Metabolite IDs in the model
%                           S               Stoichiometric matrix (sparse)
%                           b               RHS of Sv = b (usually zeros)
%                           c               Objective coefficients
%                           lb              Lower bounds for fluxes
%                           ub              Upper bounds for fluxes
%                           rev             Reversibility flag
%
% minFluxesW (obligatory) Type: double array of size n_rxns x1
%                           Description: Minimum fluxes for each reaction
%                           in the model for wild-type strain. This can be
%                           obtained by running the function FVA_optForce
%                           Example: minFluxesW=[-90; -56];
%
% maxFluxesW (obligatory) Type: double array of size n_rxns x1
%                           Description: Maximum fluxes for each reaction
%                           in the model for wild-type strain. This can be
%                           obtained by running the function FVA_optForce
%                           Example: maxFluxesW=[-90; -56];
%% OPTIONAL INPUTS
%
% constrOpt (optional):     Type: Structure
%                           Description: structure containing additional
%                           contraints. The structure has the following
%                           fields:
%                           rxnList: (Type: cell array)      Reaction list
%                           values:  (Type: double array)    Values for constrained reactions
%                           sense:   (Type: char array)      Constraint senses for constrained reactions (G/E/L)
%                                                            (G: Greater than; E: Equal to; L: Lower than)
%                           Example: struct('rxnList',{{'EX_gluc','R75','EX_suc'}},'values',[-100,0,155.5]','sense','EEE');
%
% excludedRxns(optional):   Type: cell array
%                           Description: Reactions to be excluded to the
%                           MustUL set. This could be used to avoid finding
%                           transporters or exchange reactions in the set
%                           Default: empty.
%
% runID (optional):         Type: string
%                           Description: ID for identifying this run
%
% outputFolder (optional):  Type: string
%                           Description: name for folder in which results
%                           will be stored
%
% outputFileName (optional):Type: string
%                           Description: name for files in which results
%                           will be stored
%
% printExcel (optional) :   Type: double
%                           Description: boolean to describe wheter data
%                           must be printed in an excel file or not
%
% printText (optional):    Type: double
%                           Description: boolean to describe wheter data
%                           must be printed in an plaint text file or not
%
% printReport (optional):   Type: double
%                           Description: 1 to generate a report in a plain
%                           text file. 0 otherwise.
%
% keepInputs (optional):    Type: double
%                           Description: 1 to mantain folder with inputs to
%                           run findMustUL.gms. 0 otherwise.

% verbose (optional):       Type: double
%                           Description: 1 to print results in console.
%                           0 otherwise.

%% OUTPUTS
% mustUSet:                 Type: cell array
%                           Size: number of reactions found X 1
%                           Description: Cell array containing the
%                           reactions ID which belong to the Must_U Set
% pos_MustU:                Type: double array
%                           Size: number of reactions found X 1
%                           Description: double array containing the
%                           positions of reactions in the model.
%% OUTPUT FILES
% outputFileName.xls        Type: file.
%                           Description: File containing one column array
%                           with identifiers for reactions in MustUL. This
%                           file will only be generated if the user entered
%                           printExcel = 1. Note that the user can choose
%                           the name of this file entering the input
%                           outputFileName = 'PutYourOwnFileNameHere';
%
% outputFileName.txt        Type: file.
%                           Description: File containing one column array
%                           with identifiers for reactions in MustUL. This
%                           file will only be generated if the user entered
%                           printText = 1. Note that the user can choose
%                           the name of this file entering the input
%                           outputFileName = 'PutYourOwnFileNameHere';
%
% outputFileName_Info.xls   Type: file.
%                           Description: File containing one column array.
%                           In each row the user will find a couple of
%                           reactions. Each couple of reaction was found in
%                           one iteration of FindMustUL.gms. This file will
%                           only be generated if the user entered
%                           printExcel = 1. Note that the user can choose
%                           the name of this file entering the input
%                           outputFileName = 'PutYourOwnFileNameHere';
%
% outputFileName_Info.txt   Type: file.
%                           Description: File containing one column array.
%                           In each row the user will find a couple of
%                           reactions. Each couple of reaction was found in
%                           one iteration of FindMustUL.gms. This file will
%                           only be generated if the user entered
%                           printText = 1. Note that the user can choose
%                           the name of this file entering the input
%                           outputFileName = 'PutYourOwnFileNameHere';
%
%% CODE
% inputs handling
if nargin < 1 || isempty(model)
    error('OptForce: No model specified');
else
    if ~isfield(model,'S'), error('OptForce: Missing field S in model');  end
    if ~isfield(model,'rxns'), error('OptForce: Missing field rxns in model');  end
    if ~isfield(model,'mets'), error('OptForce: Missing field mets in model');  end
    if ~isfield(model,'lb'), error('OptForce: Missing field lb in model');  end
    if ~isfield(model,'ub'), error('OptForce: Missing field ub in model');  end
    if ~isfield(model,'c'), error('OptForce: Missing field c in model'); end
    if ~isfield(model,'b'), error('OptForce: Missing field b in model'); end
end

if nargin < 2 || isempty(maxFluxesW)
    error('OptForce: Minimum values for reactions in wild-type strain not specified');
end
if nargin < 3 || isempty(maxFluxesW)
    error('OptForce: Maximum values for reactions in wild-type strain not specified');
end
if nargin < 4
    constrOpt = {};
else
    %check correct fields and correct size.
    if ~isfield(constrOpt,'rxnList'), error('OptForce: Missing field rxnList in constrOpt');  end
    if ~isfield(constrOpt,'values'), error('OptForce: Missing field values in constrOpt');  end
    if ~isfield(constrOpt,'sense'), error('OptForce: Missing field sense in constrOpt');  end
    
    if length(constrOpt.rxnList) == length(constrOpt.values) && length(constrOpt.rxnList) == length(constrOpt.sense)
        if size(constrOpt.rxnList,1) > size(constrOpt.rxnList,2); constrOpt.rxnList = constrOpt.rxnList'; end;
        if size(constrOpt.values,1) > size(constrOpt.values,2); constrOpt.values = constrOpt.values'; end;
        if size(constrOpt.sense,1) > size(constrOpt.sense,2); constrOpt.sense = constrOpt.sense'; end;
    else
        error('OptForce: Incorrect size of fields in constrOpt');
    end
    if length(intersect(constrOpt.rxnList, model.rxns)) ~= length(constrOpt.rxnList);
        error('OptForce: identifiers for reactions in constrOpt.rxnList must be in model.rxns');
    end
end
if nargin < 5
    excludedRxns = {};
else
    if length(intersect(excludedRxns, model.rxns)) ~= length(excludedRxns);
        error('OptForce: identifiers for excluded reactions must be in model.rxns');
    end
end
if nargin < 6 || isempty(runID)
    hour = clock; runID = ['run-' date '-' num2str(hour(4)) 'h' '-' num2str(hour(5)) 'm'];
else
    if ~ischar(runID); error('OptForce: runID must be an string');  end
end
if nargin < 7 || isempty(outputFolder)
    outputFolder = 'OutputsFindMustUL';
else
    if ~ischar(outputFolder); error('OptForce: outputFolder must be an string');  end
end
if nargin < 8 || isempty(outputFileName)
    outputFileName = 'MustULSet';
else
    if ~ischar(outputFileName); error('OptForce: outputFileName must be an string');  end
end
if nargin < 9
    printExcel = 1;
else
    if ~isnumeric(printExcel); error('OptForce: printExcel must be a number');  end
    if printExcel ~= 0 && printExcel ~= 1; error('OptForce: printExcel must be 0 or 1');  end
end
if nargin < 10
    printText = 1;
else
    if ~isnumeric(printText); error('OptForce: printText must be a number');  end
    if printText ~= 0 && printText ~= 1; error('OptForce: printText must be 0 or 1');  end
end
if nargin < 11
    printReport = 1;
else
    if ~isnumeric(printReport); error('OptForce: printReport must be a number');  end
    if printReport ~= 0 && printReport ~= 1; error('OptForce: printReportl must be 0 or 1');  end
end
if nargin < 12
    keepInputs = 1;
else
    if ~isnumeric(keepInputs); error('OptForce: keepInputs must be a number');  end
    if keepInputs ~= 0 && keepInputs ~= 1; error('OptForce: keepInputs must be 0 or 1');  end
end
if nargin < 13
    verbose = 0;
else
    if ~isnumeric(verbose); error('OptForce: verbose must be a number');  end
    if verbose ~= 0 && verbose  ~=  1; error('OptForce: verbose must be 0 or 1');  end
end

%current path
workingPath = pwd;
%go to the path associate to the ID for this run.
if ~isdir(runID); mkdir(runID); end; cd(runID);

% if the user wants to generate a report.
if printReport
    %create name for file.
    hour = clock;
    reportFileName = ['report-' date '-' num2str(hour(4)) 'h' '-' num2str(hour(5)) 'm.txt'];
    freport = fopen(reportFileName, 'w');
    % print date of running.
    fprintf(freport, ['findMustUL.m executed on ' date ' at ' num2str(hour(4)) ':' num2str(hour(5)) '\n\n']);
    % print matlab version.
    fprintf(freport, ['MATLAB: Release R' version('-release') '\n']);
    
    %print each of the inputs used in this running.
    fprintf(freport, '\nThe following inputs were used to run OptForce: \n');
    fprintf(freport, '\n------INPUTS------\n');
    %print model.
    fprintf(freport, '\nModel:\n');
    for i = 1:length(model.rxns)
        rxn = printRxnFormula(model, model.rxns{i}, false);
        fprintf(freport, [model.rxns{i} ': ' rxn{1} '\n']);
    end
    %print lower and upper bounds, minimum and maximum values for each of
    %the reactions in wild-type and mutant strain
    fprintf(freport, '\nLB\tUB\tMin_WT\tMax_WT\n');
    for i = 1:length(model.rxns)
        fprintf(freport, '%6.4f\t%6.4f\t%6.4f\t%6.4f\n', model.lb(i), model.ub(i), minFluxesW(i), maxFluxesW(i));
    end
    
    %print constraints
    fprintf(freport,'\nConstrained reactions:\n');
    for i = 1:length(constrOpt.rxnList)
        fprintf(freport,'%s: fixed in %6.4f\n', constrOpt.rxnList{i}, constrOpt.values(i));
    end
    
    fprintf(freport, '\nExcluded Reactions:\n');
    for i = 1:length(excludedRxns)
        rxn = printRxnFormula(model, excludedRxns{i}, false);
        fprintf(freport, [excludedRxns{i} ': ' rxn{1} '\n']);
    end
    
    fprintf(freport,'\nrunID(Main Folder): %s \n\noutputFolder: %s \n\noutputFileName: %s \n',...
        runID, outputFolder, outputFileName);
    
    
    fprintf(freport,'\nprintExcel: %1.0f \n\nprintText: %1.0f \n\nprintReport: %1.0f \n\nkeepInputs: %1.0f  \n\nverbose: %1.0f \n',...
        printExcel, printText, printReport, keepInputs, verbose);
    
end

% export inputs for running the optimization problem in GAMS to find the
% MustUL Set
if keepInputs
    inputFolder = 'InputsMustUL';
    saveInputsMustSetsSecondOrder(model, minFluxesW, maxFluxesW, constrOpt, excludedRxns, inputFolder)
end

% create a directory to save results if this don't exist
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

n_rxns = length(model.rxns);

can = zeros(n_rxns,1);
can(minFluxesW ~= 0) = 1;
can(maxFluxesW ~= 0) = 1;
mustUL = cell(n_rxns^2, 2);
pos_mustUL = zeros(n_rxns^2, 2);
solutions = cell(n_rxns^2, 1);

cont=0;
while 1
    bilevelMILPproblem = buildBilevelMILPproblemForFindMustUL(model, can, minFluxesW, maxFluxesW, constrOpt, excludedRxns, solutions);
    % Solve problem
    MustULSol = solveCobraMILP(bilevelMILPproblem, 'printLevel', 1);
    if MustULSol.stat ~= 1
        break;
    else
        cont = cont + 1;
        pos_actives = find(MustULSol.int > 0.99);
        pos_y1 = pos_actives(1);
        pos_y2 = pos_actives(2) - n_rxns;
        mustUL{cont, 1} = model.rxns{pos_y1};
        mustUL{cont, 2} = model.rxns{pos_y2};
        pos_mustUL(cont, 1) = pos_y1;
        pos_mustUL(cont, 1) = pos_y1;
        solution.reactions = [model.rxns(pos_y1); model.rxns(pos_y2)];
        solution.posbl = [pos_actives(1); pos_actives(2)];
        solution.pos = [pos_y1; pos_y2];
        solutions{cont} = solution;
    end
end

if printReport; fprintf(freport, '\n------RESULTS------\n'); end;

if cont>0
    
    if printReport; fprintf(freport, '\na MustUL set was found\n'); end;
    if verbose; fprintf('a MustUL set was found\n'); end;
    mustUL = mustUL(1:cont, :);
    pos_mustUL = pos_mustUL(1:cont, :);
    
    mustUL_linear = {};
    for i = 1:size(mustUL,1)
        mustUL_linear = union(mustUL_linear, mustUL(i,:));
    end
    [~, pos_mustUL_linear] = intersect(model.rxns, mustUL_linear);
else
    if printReport; fprintf(freport, '\na MustUL set was not found\n'); end;
    if verbose; fprintf('a MustUL set was not found\n'); end;
    
    mustUL = {};
    pos_mustUL = [];
    mustUL_linear = {};
    pos_mustUL_linear = [];
end

% print info into an excel file if required by the user
if printExcel
    if cont > 0
        currentFolder = pwd;
        cd(outputFolder);
        must = cell(size(mustUL, 1), 1);
        for i = 1:size(mustUL, 1)
            must{i} = strjoin(mustUL(i, :), ' or ');
        end
        xlswrite([outputFileName '_Info'], [{'Reactions'}; must]);
        xlswrite(outputFileName, mustUL_linear);
        cd(currentFolder);
        if verbose
            fprintf(['MustUL set was printed in ' outputFileName '.xls  \n']);
            fprintf(['MustUL set was also printed in ' outputFileName '_Info.xls  \n']);
        end
        if printReport
            fprintf(freport, ['\nMustUL set was printed in ' outputFileName '.xls  \n']);
            fprintf(freport, ['\nMustUL set was printed in ' outputFileName '_Info.xls  \n']);
        end       
    else
        if verbose; fprintf('No mustUL set was found. Therefore, no excel file was generated\n'); end;
        if printReport; fprintf(freport, '\nNo mustUL set was found. Therefore, no excel file was generated\n'); end;
    end
end

% print info into a plain text file if required by the user
if printText
    if cont > 0
        currentFolder = pwd;
        cd(outputFolder);
        f = fopen([outputFileName '_Info.txt'], 'w');
        fprintf(f, 'Reactions\n');
        for i = 1:size(mustUL, 1)
            fprintf(f, '%s or %s\n', mustUL{i,1}, mustUL{i,2});
        end
        fclose(f);
        
        f = fopen([outputFileName '.txt'], 'w');
        for i = 1:length(mustUL_linear)
            fprintf(f, '%s\n', mustUL_linear{i});
        end
        fclose(f);
        cd(currentFolder);
        
        if verbose
            fprintf(['MustUL set was printed in ' outputFileName '.txt  \n']);
            fprintf(['MustUL set was also printed in ' outputFileName '_Info.txt  \n']);
        end
        if printReport
            fprintf(freport, ['\nMustUL set was printed in ' outputFileName '.txt  \n']);
            fprintf(freport, ['\nMustUL set was printed in ' outputFileName '_Info.txt  \n']);
        end
        
    else
        if verbose; fprintf('No mustUL set was found. Therefore, no plain text file was generated\n'); end;
        if printReport; fprintf(freport, '\nNo mustUL set was found. Therefore, no plain text file was generated\n'); end;
    end
end

%close file for saving report
if printReport; fclose(freport);end;
if printReport; movefile(reportFileName, outputFolder); end;

%go back to the original path
cd(workingPath);

end

function bilevelMILPproblem = buildBilevelMILPproblemForFindMustUL(model, can,minFluxesW, maxFluxesW, constrOpt, excludedRxns, solutions)

if  isempty(constrOpt)
    ind_ic = [];
    b_ic = [];
    csense_ic = [];
    sel_ic = zeros(length(model.rxns), 1);
    sel_ic_b = zeros(length(model.rxns), 1);
else
    %get indices of rxns
    [~, ind_a, ind_b] = intersect(model.rxns, constrOpt.rxnList);
    aux=constrOpt.values(ind_b);
    aux2=constrOpt.sense(ind_b);
    %sort for rxn index
    [sorted, ind_sorted]=sort(ind_a);
    ind_ic = sorted;
    b_ic = aux(ind_sorted);
    csense_ic = aux2(ind_sorted);
    sel_ic = zeros(length(model.rxns), 1);
    sel_ic(ind_ic) = 1;
    sel_ic_b = zeros(length(model.rxns), 1);
    sel_ic_b(ind_ic) = b_ic;
end

if isempty(excludedRxns)
    sel_excludedRxns = zeros(length(model.rxns), 1);
else
    %get indices of rxns
    [~, ind_a, ~] = intersect(model.rxns, excludedRxns);
    %sort for rxn index
    sorted=sort(ind_a);
    ind_excludedRxns = sorted;
    sel_excludedRxns = zeros(length(model.rxns), 1);
    sel_excludedRxns(ind_excludedRxns) = 1;
end

%convert inputs
S = model.S;
ub = model.ub;
lb = model.lb;
% Dimensions
[n_mets, n_rxns] = size(S);

% indices of not contrained variables
ind_nic = setdiff(1:n_rxns, ind_ic);

% boolean vector for not constrained variables
sel_nic = zeros(n_rxns, 1);
sel_nic(ind_nic) = 1;
% boolean vector for integer variables
selRxns = ones(size(model.rxns));
sel_int = selRxns;
% bolean vector for reactions not in can
sel_nc =~ can;
ind_nc = find(sel_nc);
% bolean vector for reactions in can & not contrained
sel_c_nic = can & ~sel_ic;
ind_cnic = find(sel_c_nic);

% Number of integer variables
n_int = sum(sel_int);
% Number of inner  constraints
n_ic = length(ind_ic);
% Number of not inner constraints
n_nic = length(ind_nic);
% Number of inner variables not in can
n_nc = sum(sel_nc);
% Number of inner variables in can & not contrained
n_c_nic = sum(sel_c_nic);
% can
nCan = sum(can);

Iic = selMatrix(sel_ic);
Inic = selMatrix(sel_nic);
Icnic = selMatrix(sel_c_nic);
Inc = selMatrix(sel_nc);
Ic = selMatrix(can);

% Set variable types
vartype_bl(1:8 * n_rxns + 2 * n_int + n_mets + 3) = 'C';
vartype_bl(n_rxns + 1:n_rxns + 2 * n_int) = 'B';

L = -1000;
H = 1000;
M = 2000;

%   v(j)      y1(j)      y2(j)     mu(j)     w1(j)     w2(j)  deltam(j)  deltap(j)  theta(j) thetap(j) labmda(i)  zprimal    zdual      z
%|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|
%   n         n_int     n_int       n         n         n        n         n          n         n         m        1           1        1

% Set upper/lower bounds
lb_bl = [lb; zeros(7 * n_rxns + 2 * n_int + n_mets + 3, 1)]; %v(j)
ub_bl = [ub; H*ones(7 * n_rxns + 2 * n_int + n_mets + 3, 1)]; %v(j)
lb_bl(n_rxns + 2 * n_int + 1:n_rxns + 2 * n_int + n_rxns) = L; %mu(j)
lb_bl(2 * n_rxns + 2 * n_int + 1:2 * n_rxns + 2 * n_int + 2 * n_rxns) = L; %w1(j) & w2(j)
lb_bl(8 * n_rxns + 2 * n_int + 1:8 * n_rxns + 2 * n_int + n_mets) = L; %lambda(i)
lb_bl(8 * n_rxns + 2 * n_int + n_mets + 1:8 * n_rxns + 2 * n_int + n_mets + 3) = L; %z, zprimal, zdual

%PRIMAL PROBLEM
% 0) primal_obj (1 equation)
% zprimal = sum(w1(j) + w2(j)) - > zprimal - sum(w1(j) + w2(j)) = 0
% A_p=[];
A_p = [zeros(1, 2 * n_rxns + 2 * n_int) -sel_c_nic' sel_c_nic' zeros(1, 4 * n_rxns + n_mets) 1 0 0];
b_p = 0;
csense_p = 'E';

%1) primal1 (n_mets equations)
%   S*v=0
A_p = [A_p; S zeros(n_mets, n_rxns * 7 + 2 * n_int + n_mets + 3)];
b_p = [b_p; zeros(n_mets, 1)];
csense_p(end + 1:end + n_mets) = 'E';

%2) primal 2, 3 and 7 (n_ic equations)
%   v_ic = b_ic
A_p = [A_p; Iic zeros(n_ic, n_rxns * 7 + 2 * n_int + n_mets + 3)];
b_p = [b_p; b_ic'];
csense_p(end + 1:end + n_ic) = csense_ic;
%
%3) primal 5 (n_nic equations)
%   -v(j) >= -ub(j)
A_p = [A_p; -Inic zeros(n_nic, n_rxns * 7 + 2 * n_int + n_mets + 3)];
b_p = [b_p; -ub(ind_nic)];
csense_p(end + 1:end + n_nic) = 'G';
%
%4) primal 6 (n_nic equations)
%   v(j) >= lb(j)
A_p = [A_p; Inic zeros(n_nic, n_rxns * 7 + 2 * n_int + n_mets + 3)];
b_p = [b_p; lb(ind_nic)];
csense_p(end + 1:end + n_nic) = 'G';

%DUAL PROBLEM
% 0) dual_obj (1 equation)
% zdual  -b_ic(j)*mu(j) + sum(-deltam(j)*lb(j) +deltap(j)*ub(j)) = 0
% A_d=[];
% b_d =[];
% csense_d='';
A_d = [zeros(1, n_rxns + 2 * n_int)  -sel_ic_b' zeros(1, 2 * n_rxns) -lb' ub' zeros(1, 2 * n_rxns + n_mets) 0 1 0];
b_d = 0;
csense_d = 'E';

% %1) dual1 (n_ic equations)
% %   sum_i(lambda(i)*S(i,j)) + mu(j) =0
A_d = [A_d; zeros(n_ic, 3 * n_rxns) Iic zeros(n_ic, 6 * n_rxns) S(:, ind_ic)' zeros(n_ic, 3)];
b_d = [b_d; zeros(n_ic, 1)];
csense_d(end + 1:end + n_ic) = 'E';

% %2) dual2 (n_nic equations)
% %   sum_i(lambda(i)*S(i,j)) + deltam(j) -deltap(j)- y1(j) - y2(j)=0
A_d = [A_d; zeros(n_c_nic, n_rxns) -Icnic Icnic zeros(n_c_nic, 3 * n_rxns) Icnic -Icnic zeros(n_c_nic, 2 * n_rxns) S(:, ind_cnic)' zeros(n_c_nic, 3)];
b_d = [b_d; zeros(n_c_nic, 1)];
csense_d(end + 1:end + n_c_nic) = 'E';
%
% %3) dua13 (n_nic equations)
%   sum_i(lambda(i) * S(i,j)) + deltam(j) -deltap(j)=0
A_d = [A_d; zeros(n_nc, 4 * n_rxns + 2 * n_int) Inc -Inc zeros(n_nc, 2 * n_rxns) S(:, ind_nc)' zeros(n_nc, 3)];
b_d = [b_d; zeros(n_nc, 1)];
csense_d(end + 1:end + n_nc) = 'E';

%OUTER PROBLEM
% outer obj (1 equation)
%z=sum(w1(j)+w2(j)-(basemax(j) * y1(j) + basemax(j) * y2(j)) ) -> z -sum(w1(j)) - sum(w2(j)) + sum(basemax(j) * y2(j)) + sum(basemax(j) * y2(j)) = 0 for all j in can y not in must and not in
%contraint_flux
A_bl = [zeros(1, n_rxns) (maxFluxesW.*sel_c_nic)'  -(minFluxesW.*sel_c_nic)' zeros(1, n_rxns) -sel_c_nic' sel_c_nic' zeros(1, 4 * n_rxns + n_mets) 0 0 1];
b_bl = 0;
csense_bl = 'E';

%primal_dual (1 equation)
A_bl = [A_bl; zeros(1, 10 * n_rxns + n_mets) 1 -1 0];
b_bl = [b_bl; 0];
csense_bl = [csense_bl, 'E'];

%con1 (1 equation)
%sum(y1(j)) = 0
A_bl = [A_bl; zeros(1, n_rxns) sel_ic' zeros(1, n_int + 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 0];
csense_bl = [csense_bl, 'E'];

%con2 (1 equation)
%sum(y2(j)) = 0
A_bl = [A_bl; zeros(1, n_rxns + n_int) sel_ic' zeros(1, 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 0];
csense_bl = [csense_bl, 'E'];

% must_set1 (1 equation)
% sum(y1(j)) = 0
A_bl = [A_bl; zeros(1, n_rxns) sel_excludedRxns' zeros(1, n_int + 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 0];
csense_bl = [csense_bl, 'E'];

%must_set2 (1 equation)
%sum(y2(j)) = 0
A_bl = [A_bl; zeros(1, n_rxns + n_int) sel_excludedRxns' zeros(1, 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 0];
csense_bl = [csense_bl, 'E'];

% outer1 (1 equation)
% sum(y1(j)) = 1
A_bl = [A_bl; zeros(1, n_rxns) sel_c_nic' zeros(1, n_int + 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 1];
csense_bl = [csense_bl, 'E'];

%outer2 (1 equation)
%sum(y2(j)) = 1
A_bl = [A_bl; zeros(1, n_rxns + n_int) sel_c_nic' zeros(1, 7 * n_rxns + n_mets + 3) ];
b_bl = [b_bl; 1];
csense_bl = [csense_bl, 'E'];

%prevent previous solutions to be found
for i = 1:length(solutions)
    if isempty(solutions{i});  break; end;
    pos = solutions{i}.pos;
    sel_prev = zeros(1, 2 * n_int);
    sel_prev(pos(1)) = 1;
    sel_prev(pos(2) + n_rxns) = 1;
    A_bl = [A_bl; zeros(1, n_rxns) sel_prev zeros(1, 7 * n_rxns + n_mets + 3)];
    b_bl =[b_bl; 1];
    csense_bl(end + 1) = 'L';
    
    sel_prev = zeros(1, 2 * n_int);
    sel_prev(pos(2)) = 1;
    sel_prev(pos(1) + n_rxns) = 1;
    A_bl = [A_bl; zeros(1, n_rxns) sel_prev zeros(1, 7 * n_rxns + n_mets + 3)];
    b_bl = [b_bl; 1];
    csense_bl(end + 1) = 'L';
end

% outer4 (1 equation)
% z >= 0.1
A_bl = [A_bl; zeros(1, 8 * n_rxns + 2 * n_int + n_mets + 2) 1];
b_bl = [b_bl; 0.1];
csense_bl(end + 1) = 'G';

%outer5 (length(find(can)) equations)
% w1(j) -v(j) + M * y1(j) <= M
A_bl = [A_bl; -Ic M * Ic zeros(nCan, n_int + n_rxns) Ic  zeros(nCan, 5 * n_rxns + n_mets + 3)];
b_bl = [b_bl;M * ones(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'L';

%outer6 (length(find(can)) equations)
% w1(j) -v(j) - M * y1(j) >= -M
A_bl = [A_bl; -Ic -M * Ic zeros(nCan, n_int + n_rxns) Ic  zeros(nCan, 5 * n_rxns + n_mets + 3)];
b_bl = [b_bl; -M * ones(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'G';

%outer7 (length(find(can)) equations)
% w1(j) - M * y1(j) <= 0
A_bl = [A_bl; zeros(nCan, n_rxns) -M * Ic zeros(nCan, n_int + n_rxns) Ic  zeros(nCan, 5 * n_rxns + n_mets + 3)];
b_bl = [b_bl;zeros(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'L';

%outer8 (length(find(can)) equations)
% w1(j) + M * y1(j) >= 0
A_bl = [A_bl; zeros(nCan, n_rxns) M * Ic zeros(nCan, n_int + n_rxns) Ic  zeros(nCan, 5 * n_rxns + n_mets + 3)];
b_bl = [b_bl;zeros(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'G';

%outer9 (length(find(can)) equations)
% w2(j) -v(j) + M * y2(j) <= M
A_bl = [A_bl; -Ic zeros(nCan, n_int) M * Ic zeros(nCan, 2 * n_rxns) Ic  zeros(nCan, 4 * n_rxns + n_mets + 3)];
b_bl = [b_bl;M * ones(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'L';

%outer10 (length(find(can)) equations)
% w2(j) -v(j) - M * y2(j) >= -M
A_bl = [A_bl; -Ic zeros(nCan, n_int) -M * Ic zeros(nCan, 2 * n_rxns) Ic  zeros(nCan, 4 * n_rxns + n_mets + 3)];
b_bl = [b_bl; -M * ones(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'G';

%outer11 (length(find(can)) equations)
% w2(j) - M * y2(j) <= 0
A_bl = [A_bl; zeros(nCan, n_int + n_rxns) -M * Ic zeros(nCan, 2 * n_rxns) Ic  zeros(nCan, 4 * n_rxns + n_mets + 3)];
b_bl = [b_bl; zeros(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'L';

%outer12 (length(find(can)) equations)
% w2(j) + M * y2(j) >= 0
A_bl = [A_bl; zeros(nCan, n_int + n_rxns) M * Ic zeros(nCan, 2 * n_rxns) Ic  zeros(nCan, 4 * n_rxns + n_mets + 3)];
b_bl = [b_bl; zeros(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'G';

%outer13 (length(find(can)) equations)
% y1(j) + y2(j) <= 1
A_bl = [A_bl; zeros(nCan, n_rxns) Ic Ic zeros(nCan, 7 * n_rxns + n_mets + 3)];
b_bl = [b_bl; ones(nCan, 1)];
csense_bl(end + 1:end + nCan) = 'L';

%Build bilevel matrices and vectors
A_bl_up = [A_bl;A_d;A_p];
b_bl_up = [b_bl;b_d;b_p];
csense_bl_up = [csense_bl,csense_d,csense_p];
c_bl_up = zeros(8 * n_rxns + 2 * n_int + n_mets + 3, 1); c_bl_up(end) = 1;

% Helper arrays for extracting solutions
sel_cont_sol = 1:n_rxns;
sel_int_sol = n_rxns + 1:n_rxns + n_int;

% Construct problem structure
bilevelMILPproblem.A = A_bl_up;
bilevelMILPproblem.b = b_bl_up;
bilevelMILPproblem.c = c_bl_up;
bilevelMILPproblem.csense = csense_bl_up;
bilevelMILPproblem.lb = lb_bl;
bilevelMILPproblem.ub = ub_bl;
bilevelMILPproblem.vartype = vartype_bl;
bilevelMILPproblem.contSolInd = sel_cont_sol;
bilevelMILPproblem.intSolInd = sel_int_sol;
% Initialize initial solution x0
bilevelMILPproblem.x0 = [];

% Maximize
bilevelMILPproblem.osense = -1;

% Set model for MILP problem
bilevelMILPproblem.model = model;

end