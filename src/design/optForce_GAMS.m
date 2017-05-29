function [optForceSets,pos_optForceSets,typeReg_optForceSets]=optForce_GAMS(model,targetRxn, mustU, mustL, minFluxes_WT, maxFluxes_WT, minFluxes_MT, maxFluxes_MT,k,n_sets,constrOpt,excludedRxns,solverName,printExcel,printPlainText,showInputs,printReport,outputFolder,runID,keepGAMSOutputs)

% DESCRIPTION
% This function runs optForce, a procedure published in the article:
% Ranganathan S, Suthers PF, Maranas CD (2010) OptForce: An Optimization Procedure for Identifying All Genetic Manipulations Leading to Targeted Overproductions. PLOS Computational Biology 6(4): e1000744. https://doi.org/10.1371/journal.pcbi.1000744
% This script is based in the GAMS files written by Sridhar Ranganathan
% which were provided by the research group of Costas D. Maranas.

% The optForce problem is described as follows: Given a metabolic model,
% the problem is to find sets of reactions of size "k" which their
% upregulation/downregulation/deletion leads to an overproducing strain for
% the target of interest.

%% ADDTIONAL INFO
% Created by Sebastian Mendoza on 29/May/2017. snmendoz@uc.cl

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
% targetRxn (obligatory):   Type: string
%                           Description: string containing the ID for the
%                           reaction whose flux is intented to be increased.
%                           For example, if the production of succionate is
%                           desired to be increased, 'EX_suc' should be
%                           chosen as the target reaction
%                           Example: targetRxn='EX_suc';
% mustU (obligatory):       Type: cell array.
%                           Description: List of reactions in the MustU set
%                           This input can be obtained by running the
%                           script findMustU.m
%                           Alternatively, there is a second usage of this
%                           input:
%                           Type: string.
%                           Description: name of the .xls file containing
%                           the list of the reactions in the MustU set
%                           Example first usage: mustU={'R21_f';'R22_f'};
%                           Example second usage: mustU='MustU';
% mustL (obligatory):       Type: cell array.
%                           Description: List of reactions in the MustL set
%                           This input can be obtained by running the
%                           script findMustL.m
%                           Alternatively, there is a second usage of this
%                           input:
%                           Type: string.
%                           Description: name of the .xls file containing
%                           the list of the reactions in the MustU set
%                           Example first usage: mustL={'R11_f';'R26_f'};
%                           Example second usage: mustL='MustL';
% minFluxes_WT (obligatory): Type: double array of size n_rxns x1
%                            Description: Minimum fluxes for each reaction
%                            in the model for wild-type strain
%                            Example: minFluxes_WT=[-90; -56];
% maxFluxes_WT (obligatory): Type: double array of size n_rxnsx1
%                            Description: Maximum fluxes for each reaction
%                            in the model for wild-type strain
%                            Example: maxFluxes_WT=[92; -86];
% minFluxes_MT (obligatory): Type: double array of size n_rxnsx1
%                            Description: Minimum fluxes for each reaction
%                            in the model for mutant strain
%                            Example: minFluxes_WT=[-90; -56];
% maxFluxes_MT (obligatory): Type: double array of size n_rxnsx1
%                            Description: Maxmum fluxes for each reaction
%                            in the model for mutant strain
%                            Example: maxFluxes_WT=[92; -86];
% k(optional):              Type: double
%                           Description: number of intervations to be
%                           found
%                           Default k=1;
% n_sets(optional):         Type: double
%                           Description: maximum number of force sets
%                           returned by optForce.
%                           Default n_sets=1;
% constrOpt (optional):     Type: structure
%                           Description: structure containing constrained
%                           reactions with fixed values. The structure has
%                           the following fields:
%                           rxnList: (Type: cell array)      Reaction list
%                           values:  (Type: double array)    Values for constrained reactions
%                           Example: constrOpt=struct('rxnList',{{'EX_for_e','EX_etoh_e'}},'values',[1,5]);
%                           Default: empty.
% excludedRxns(optional):   Type: structure
%                           Description: Reactions to be excluded. This
%                           structure has the following fields
%                           rxnList: (Type: cell array)      Reaction list
%                           typeReg: (Type: char array)      set from which reaction is excluded
%                                                            (U: Set of upregulared reactions; D: set of downregulared reations; K: set of knockout reactions)
%                           Example: excludedRxns=struct('rxnList',{{'SUCt','R68_b'}},'typeReg','UD')
%                           In this example SUCt is prevented to appear in
%                           the set of upregulated reactions and R68_b is
%                           prevented to appear in the downregulated set of
%                           reactions.
%                           Default: empty.
% solverName(optional):     Type: string
%                           Description: Name of the solver used in GAMS
%                           Default: 'cplex'
% printExcel(optional):     Type: double
%                           Description: Boolean for printing results into
%                           an excel file. 1 for printing. 0 otherwise.
%                           Default: 1
% printPlainText(optional): Type: double
%                           Description: Boolean for printing results into
%                           a plaint text file. 1 for printing. 0 otherwise.
%                           Default: 1
% showInputs(optional):     Type: double
%                           Description: Boolean for showing files used as
%                           input for running OptForce in GAMS. 1 for
%                           showing. 0 otherwise
%                           Default: 0
% printReport(optional):    Type: double
%                           Description: Boolean for creating a file with a
%                           report of the running, including inputs for
%                           running optForce and results.
%                           Default: 1
% outputFolder(optional):   Type: string
%                           Description: string wiht folder name in which
%                           results will be saved
%                           Default: 'OptForceResults'

%% OUTPUTS
% optForceSets:             Type: cell array
%                           Description: cell array of size  n x m, where
%                           n = number of sets found and m = size of sets
%                           found (k). Element in position i,j is reaction
%                           j in set i.
%                           Example:
%                                    rxn1  rxn2    
%                                     __    __
%                           set 1   | R4    R2
%                           set 2   | R3    R1
% pos_optForceSets          Type: double array
%                           Description: double array of size  n x m, where
%                           n = number of sets found and m = size of sets
%                           found (k). Element in position i,j is the 
%                           position of reaction in optForceSets(i,j) in 
%                           model.rxns
%                           Example:
%                                    rxn1  rxn2    
%                                     __   __
%                           set 1   | 4    2
%                           set 2   | 3    1
% typeReg_optForceSets      Type: cell array
%                           Description: cell array of size  n x m, where
%                           n = number of sets found and m = size of sets
%                           found (k). Element in position i,j is the kind
%                           of intervention for reaction in 
%                           optForceSets(i,j)
%                           Example:
%                                        rxn1            rxn2    
%                                     ____________    ______________
%                           set 1   | upregulation    downregulation
%                           set 2   | upregulation    knockout
% optForce.lst               Type: file
%                           Description: file generated automatically by 
%                           GAMS when running optForce. Contains
%                           information about the running.
% GtoM                      Type: file
%                           Description: file generated by GAMS containing
%                           variables, parameters and equations of the
%                           optForce problem. 

%% CODE

% inputs handling
if (nargin<1 || isempty(model))
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

if (nargin<2 || isempty(targetRxn))
    error('OptForce: No target specified');
else
    if ~ischar(targetRxn)
    end
end

if (nargin<3 || isempty(mustU));
    error('OptForce: No MustU set specified');
else
    if iscell(mustU)
    elseif ischar(mustU)
        [~,mustU]=xlsread(mustU);
    else
        error('OptForce: Incorrect format for input MustU') ;
    end
end

if (nargin<4 || isempty(mustL));
    error('OptForce: No MustU set specified')
else
    if iscell(mustL)
    elseif ischar(mustL)
        [~,mustL]=xlsread(mustL);
    else
        error('OptForce: Incorrect format for input MustU');
    end
end

if (nargin<5 || isempty(minFluxes_WT));
    error('OptForce: input minFluxes_WT not specified');
else
    if length(minFluxes_WT)~=length(model.rxns)
        error('OptForce: wrong length of minFluxes_WT');
    end
end

if (nargin<6 || isempty(maxFluxes_WT));
    error('OptForce: input maxFluxes_WT not specified');
else
    if length(maxFluxes_WT)~=length(model.rxns)
        error('OptForce: wrong length of maxFluxes_WT');
    end
end

if (nargin<7 || isempty(minFluxes_MT));
    error('OptForce: input minFluxes_MT not specified');
else
    if length(minFluxes_MT)~=length(model.rxns)
        error('OptForce: wrong length of minFluxes_MT');
    end
end

if (nargin<8 || isempty(maxFluxes_MT));
    error('OptForce: input maxFluxes_MT not specified');
else
    if length(maxFluxes_MT)~=length(model.rxns)
        error('OptForce: wrong length of maxFluxes_MT');
    end
end
if (nargin<9 || isempty(k))
    k=1;
else
    if ~isnumeric(k)
        error('OptForce: wrong class for k');
    end
end
if (nargin<10 || isempty(n_sets))
    n_sets=1;
else
    if ~isnumeric(n_sets)
        error('OptForce: wrong class for n_sets');
    end
end
if (nargin<11)
    constrOpt={};
else
    if ~isstruct(constrOpt); error('OptForce: Incorrect format for input constrOpt'); end;
    %check correct fields and correct size.
    if ~isfield(constrOpt,'rxnList'), error('OptForce: Missing field rxnList in constrOpt');  end
    if ~isfield(constrOpt,'values'), error('OptForce: Missing field values in constrOpt');  end
    if ~isfield(constrOpt,'sense'), error('OptForce: Missing field sense in constrOpt');  end
    
    if length(constrOpt.rxnList)==length(constrOpt.values) && length(constrOpt.rxnList)==length(constrOpt.sense)
        if size(constrOpt.rxnList,1)>size(constrOpt.rxnList,2); constrOpt.rxnList=constrOpt.rxnList'; end;
        if size(constrOpt.values,1)>size(constrOpt.values,2); constrOpt.values=constrOpt.values'; end;
        if size(constrOpt.sense,1)>size(constrOpt.sense,2); constrOpt.sense=constrOpt.sense'; end;
    else
        error('OptForce: Incorrect size of fields in constrOpt');
    end
end
if (nargin<12)
    excludedRxns={};
else
    if ~isstruct(excludedRxns); error('OptForce: Incorrect format for input excludedRxns'); end;
    %check correct fields and correct size.
    if ~isfield(excludedRxns,'rxnList'), error('OptForce: Missing field rxnList in excludedRxns');  end
    if ~isfield(excludedRxns,'typeReg'), error('OptForce: Missing field typeReg in excludedRxns');  end
    
    if length(excludedRxns.rxnList)==length(excludedRxns.typeReg)
        if size(excludedRxns.rxnList,1)>size(excludedRxns.rxnList,2); excludedRxns.rxnList=excludedRxns.rxnList'; end;
        if size(excludedRxns.typeReg,1)>size(excludedRxns.typeReg,2); excludedRxns.typeReg=excludedRxns.typeReg'; end;
    else
        error('OptForce: Incorrect size of fields in excludedRxns');
    end
end
if nargin<13; solverName='cplex'; end;
if nargin<14; printExcel=1; end;
if nargin<15; printPlainText=1; end;
if nargin<16; showInputs=0; end;
if nargin<17; printReport=1; end;
if nargin<18; outputFolder='OptForceResults'; end; 
if nargin<19; hour=clock; runID=['run-' date '-' num2str(hour(4)) 'h' '-' num2str(hour(5)) 'm']; end; 
if nargin<20; keepGAMSOutputs=1; end;

%name of the function to solve optForce in GAMS
optForceFunction='optForce_general4.gms';
%path of that function 
pathOFG=which(optForceFunction);
%current path
workingPath=pwd;
%go to the path associate to the ID for this run.
if ~isdir(runID); mkdir(runID); end; cd(runID); 

% if the user wants to generate a report. 
if printReport
    %create name for file. 
    hour=clock;
    reportFileName=['report-' date '-' num2str(hour(4)) 'h' '-' num2str(hour(5)) 'm.txt'];
    freport=fopen(reportFileName,'w');
    % print date of running. 
    fprintf(freport,['optForce_GAMS executed on ' date ' at ' num2str(hour(4)) ':' num2str(hour(5)) '\n\n']);
    % print matlab version. 
    fprintf(freport,['MATLAB: Release R' version('-release') '\n']);
    % print gams version.
    gams=which('gams');
    fprintf(freport,['GAMS: ' regexprep(gams,'\\','\\\') '\n']);
    % print solver used in GAMS to solve optForce.
    fprintf(freport,['GAMS solver: ' solverName '\n']);
    
    %print each of the inputs used in this running.
    fprintf(freport,'The following inputs were used to run OptForce: \n\n');
    %print model.
    fprintf(freport,'Model:\n');
    for i=1:length(model.rxns)
        rxn=printRxnFormula(model,model.rxns{i});
        fprintf(freport,[model.rxns{i} ': ' rxn{1} '\n']);
    end
    %print lower and upper bounds, minimum and maximum values for each of
    %the reactions in wild-type and mutant strain
    fprintf(freport,'\nLB\tUB\tMin_WT\tMax_WT\tMin_MT\tMax_MT\n');
    for i=1:length(model.rxns)
        fprintf(freport,'%6.4f\t%6.4f\t%6.4f\t%6.4f\t%6.4f\t%6.4f\n',model.lb(i),model.ub(i),minFluxes_WT(i),maxFluxes_WT(i),minFluxes_MT(i),maxFluxes_MT(i));
    end
    %print target reaction.
    fprintf(freport,['Target reaction:\n' targetRxn '\n\n'] );
    %print must U set
    fprintf(freport,'Must U Set:\n');
    for i=1:length(mustU)
        fprintf(freport,[mustU{i} '\n']);
    end
    %print must L set
    fprintf(freport,'\nMust L Set:\n');
    for i=1:length(mustL)
        fprintf(freport,[mustL{i} '\n']);
    end
    %print constraints
    fprintf(freport,'\nConstrained reactions:\n');
    for i=1:length(constrOpt.rxnList)
        fprintf(freport,'%s: fixed in %6.4f\n',constrOpt.rxnList{i},constrOpt.values(i));
    end
    %print excludad reactions
    fprintf(freport,'\nExcluded reactions:\n');
    for i=1:length(excludedRxns.rxnList)
        fprintf(freport,'%s: Excluded from %s\n',excludedRxns.rxnList{i},regexprep(excludedRxns.typeReg(i),{'U','L','K'},{'Upregulations','Downregulations','Knockouts'}));
    end
    fprintf(freport,'\nprintExcel: %1.0f \n\nprintPlainText: %1.0f \n\nshowInputs: %1.0f \n\nprintReport: %1.0f\n',printExcel,printPlainText,showInputs,printReport);
end

%initialize arrays for excluding reactions.
excludedURxns={};
excludedLRxns={};
excludedKRxns={};
for i=1:length(excludedRxns.rxnList)
    if strcmp(excludedRxns.typeReg(i),'U')
        excludedURxns=union(excludedURxns,excludedRxns.rxnList(i));
    elseif strcmp(excludedRxns.typeReg(i),'L')
        excludedLRxns=union(excludedLRxns,excludedRxns.rxnList(i));
    elseif strcmp(excludedRxns.typeReg(i),'K')
        excludedKRxns=union(excludedKRxns,excludedRxns.rxnList(i));
    end
end

copyfile(pathOFG);

%export inputs to GAMS
exportInputsOptForceToGAMS(model,minFluxes_WT,maxFluxes_WT,minFluxes_MT,maxFluxes_MT,constrOpt,excludedURxns,excludedLRxns,excludedKRxns,mustL,mustU,{targetRxn},k,n_sets)

% if the user wants to generate a report, print results.
if printReport; fprintf(freport,'\nResults:\n'); end;

%run optForce in GAMS.
run=system(['gams ' optForceFunction ' lo=3 --myroot=InputsOptForce/ --solverName=' solverName ' gdx=GtoM --gdxin=MtoG']);

%if user don't decide to show inputs files for optForce
if ~showInputs;    rmdir('InputsOptForce','s'); end; 

%if the GAMS file for optForce was executed correctly "run" should be 0
if run==0
    if printReport; fprintf(freport,'\nGAMS was executed correctly\n'); end;
    %show report in console
    gdxWhos GtoM
    
    %if the problem was solved correctly, a variable named optForce should be
    %inside of GtoM. Otherwise, the wrong file is being read.
    try
        optForce.name='optForce';
        rgdx('GtoM',optForce);
        if printReport; fprintf(freport,'\noptForce was executed correctly in GAMS\n'); end;
        
        %Using GDXMRW to read number of solutions found by optForce
        counter.name='counter';
        counter.compress='true';
        counter=rgdx('GtoM',counter);
        n_sols=counter.val;
        
        if n_sols>0
            % if the user wants to generate a report, print number of sets
            % found.
            if printReport; fprintf(freport,['\noptForce found ' num2str(n_sols) ' sets \n']); end;
            
            %Using GDXMRW to read variables generated by GAMS
            m1.name='matrix1';
            m1.compress='true';
            m1=rgdx('GtoM',m1);
            uels1_m1=m1.uels{1};
            uels2_m1=m1.uels{2};
            
            m2.name='matrix2';
            m2.compress='true';
            m2=rgdx('GtoM',m2);
            uels1_m2=m2.uels{1};
            uels2_m2=m2.uels{2};
            
            m3.name='matrix3';
            m3.compress='true';
            m3=rgdx('GtoM',m3);
            uels1_m3=m3.uels{1};
            uels2_m3=m3.uels{2};
            
            m1_f.name='matrix1_flux';
            m1_f.compress='true';
            m1_f=rgdx('GtoM',m1_f);
            uels1_m1_f=m1_f.uels{1};
            uels2_m1_f=m1_f.uels{2};
            
            m2_f.name='matrix2_flux';
            m2_f.compress='true';
            m2_f=rgdx('GtoM',m2_f);
            uels1_m2_f=m2_f.uels{1};
            uels2_m2_f=m2_f.uels{2};
            
            m3_f.name='matrix3_flux';
            m3_f.compress='true';
            m3_f=rgdx('GtoM',m3_f);
            uels1_m3_f=m3_f.uels{1};
            uels2_m3_f=m3_f.uels{2};
            
            obj.name='objective';
            obj.compress='true';
            obj=rgdx('GtoM',obj);
            uels_obj=obj.uels{1};
            
            %find values for matrices and vectors extracted from GAMS
            if ~isempty(uels2_m1)
                val_m1=m1.val;
                m1_full=full(sparse(val_m1(:,1),val_m1(:,2:end-1),val_m1(:,3)));
            end
            if ~isempty(uels2_m2)
                val_m2=m2.val;
                m2_full=full(sparse(val_m2(:,1),val_m2(:,2:end-1),val_m2(:,3)));
            end
            if ~isempty(uels2_m3)
                val_m3=m3.val;
                m3_full=full(sparse(val_m3(:,1),val_m3(:,2:end-1),val_m3(:,3)));
            end
            if ~isempty(uels2_m1_f)
                val_m1_f=m1_f.val;
                m1_f_full=full(sparse(val_m1_f(:,1),val_m1_f(:,2:end-1),val_m1_f(:,3)));
            end
            if ~isempty(uels2_m2_f)
                val_m2_f=m2_f.val;
                m2_f_full=full(sparse(val_m2_f(:,1),val_m2_f(:,2:end-1),val_m2_f(:,3)));
            end
            if ~isempty(uels2_m3_f)
                val_m3_f=m3_f.val;
                m3_f_full=full(sparse(val_m3_f(:,1),val_m3_f(:,2:end-1),val_m3_f(:,3)));
            end
            if ~isempty(uels_obj);
                val_obj=obj.val(:,2);
            end
            
            %initialize empty array for saving info related to optForce
            %sets
            optForceSets=cell(n_sols,k);
            pos_optForceSets=zeros(size(optForceSets));
            flux_optForceSets=zeros(size(optForceSets));
            typeReg_optForceSets=cell(n_sols,k);
            Solutions=cell(n_sols,1);
            
            %for each set found by optForce
            for i=1:n_sols
                %find objective value achieved in the optimization problem 
                %solved by GAMS 
                if ~isempty(uels_obj) && ismember(num2str(i),uels_obj)
                    objective_value=val_obj(strcmp(num2str(i),uels_obj)==1);
                else
                    objective_value=0;
                end
                
                % initialize empty array for saving info related to set i.
                optForceSet_i=cell(k,1);
                pos_optForceSet_i=zeros(k,1);
                flux_optForceSet_i=zeros(k,1);
                type=cell(k,1);
                cont=0;
                
                % for upregulations
                if ismember(num2str(i),uels1_m1)
                    %extract reactions in set i.
                    rxns=uels2_m1(m1_full(strcmp(num2str(i),uels1_m1)==1,:)>0.99)';
                    optForceSet_i(cont+1:cont+length(rxns))=rxns;
                    %extract positions for reactions in model.rxn.
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,model.rxns)),rxns,'UniformOutput', false))';
                    pos_optForceSet_i(cont+1:cont+length(rxns))=pos;
                    %extract type of regulations for reactions.
                    type(cont+1:cont+length(rxns))={'upregulation'};
                    cont=cont+length(rxns);
                    
                end
                % for downregulations
                if ismember(num2str(i),uels1_m2)
                    rxns=uels2_m2(m2_full(strcmp(num2str(i),uels1_m2)==1,:)>0.99)';
                    optForceSet_i(cont+1:cont+length(rxns))=rxns;
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,model.rxns)),rxns,'UniformOutput', false))';
                    pos_optForceSet_i(cont+1:cont+length(rxns))=pos;
                    type(cont+1:cont+length(rxns))={'downregulation'};
                    cont=cont+length(rxns);
                end
                % for knockouts
                if ismember(num2str(i),uels1_m3)
                    rxns=uels2_m3(m3_full(strcmp(num2str(i),uels1_m3)==1,:)>0.99)';
                    optForceSet_i(cont+1:cont+length(rxns))=rxns;
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,model.rxns)),rxns,'UniformOutput', false))';
                    pos_optForceSet_i(cont+1:cont+length(rxns))=pos;
                    type(cont+1:cont+length(rxns))={'knockout'};
                end
                
                %extracting fluxes achieved by upregulated reactions
                if ismember(num2str(i),uels1_m1_f)
                    rxns=uels2_m1_f((m1_f_full(strcmp(num2str(i),uels1_m1_f)==1,:)>10^-6)==1);
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,optForceSet_i)),rxns,'UniformOutput', false))';
                    flux_optForceSet_i(pos)=m1_f_full(strcmp(num2str(i),uels1_m1_f)==1,(m1_f_full(strcmp(num2str(i),uels1_m1_f)==1,:)>10^-6)==1);
                end
                %extracting fluxes achieved by downregulated reactions
                if ismember(num2str(i),uels1_m2_f)
                    rxns=uels2_m2_f((m2_f_full(strcmp(num2str(i),uels1_m2_f)==1,:)>10^-6)==1);
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,optForceSet_i)),rxns,'UniformOutput', false))';
                    flux_optForceSet_i(pos)=m2_f_full(strcmp(num2str(i),uels1_m2_f)==1,(m2_f_full(strcmp(num2str(i),uels1_m2_f)==1,:)>10^-6)==1);
                end
                %extracting fluxes achieved by deleted reactions
                if ismember(num2str(i),uels1_m3_f)
                    rxns=uels2_m3_f((m3_f_full(strcmp(num2str(i),uels1_m3_f)==1,:)>10^-6)==1);
                    pos=cell2mat(arrayfun(@(x)find(strcmp(x,optForceSet_i)),rxns,'UniformOutput', false))';
                    flux_optForceSet_i(pos)=m3_f_full(strcmp(num2str(i),uels1_m3_f)==1,(m3_f_full(strcmp(num2str(i),uels1_m3_f)==1,:)>10^-6)==1);
                end
                
                %incorporte info of set i into general matrices.
                optForceSets(i,:)=optForceSet_i';
                pos_optForceSets(i,:)=pos_optForceSet_i';
                typeReg_optForceSets(i,:)=type';
                flux_optForceSets(i,:)=flux_optForceSet_i';
                
                %export info to structures in order to print information later 
                Solution.reactions=optForceSet_i;
                Solution.type=type;
                Solution.pos=pos_optForceSet_i;
                Solution.flux=flux_optForceSet_i;
                Solution.obj=objective_value;
                [maxGrowthRate,minTarget,maxTarget] = testOptForceSol(model,targetRxn,Solution);
                Solution.growth=maxGrowthRate;
                Solution.minTarget=minTarget;
                Solution.maxTarget=maxTarget;
                Solutions{i}=Solution;
            end
        else
            %in case that none set was found, initialize empty arrays
            if printReport; fprintf(freport,'\n optForce did not find any set \n'); end;
            optForceSets={};
            pos_optForceSets=[];
            typeReg_optForceSets={};
        end
        
        %initialize name for files in which information will be printed
        hour=clock;
        fileName=['optForceSolution-' date '-' num2str(hour(4)) 'h' '-' num2str(hour(5)) 'm'];
        
        % print info into an excel file if required by the user
        if printExcel
            if n_sols>0
                if ~isdir(outputFolder); mkdir(outputFolder); end; 
                cd(outputFolder);
                Info=cell(2*n_sols+1,11);
                Info(1,:)=[{'Number of interventions'}, {'Set number'},{'Force Set'}, {'Type of regulation'},{'Min flux in Wild Type (mmol/gDW hr)'},{'Max flux in Wild Type (mmol/gDW hr)'},{'Achieved flux (mmol/gDW hr)'},{'Objective function (mmol/gDW hr)'},{'Minimum guaranteed for target (mmol/gDW hr)'},{'Maximum guaranteed for target (mmol/gDW hr)'},{'Maximum growth rate (1/hr)'}];
                for i=1:n_sols
                    Info(k*(i-1)+2:k*(i)+1,:)=[[{k};cell(k-1,1)], [{i};cell(k-1,1)], Solutions{i}.reactions Solutions{i}.type num2cell(minFluxes_MT(Solutions{i}.pos)) num2cell(maxFluxes_MT(Solutions{i}.pos)) num2cell(Solutions{i}.flux), [{Solutions{i}.obj};cell(k-1,1)] [{Solutions{i}.minTarget};cell(k-1,1)] [{Solutions{i}.maxTarget};cell(k-1,1)] [{Solutions{i}.growth};cell(k-1,1)]];
                end
                xlswrite(fileName,Info)
                cd([workingPath '/' runID]);
                if printReport; fprintf(freport,['\nSets found by optForce were printed in ' fileName '.xls  \n']); end;
            else
                fprintf('No solution to optForce was found. Therefore, no excel file was generated\n');
            end
        end
        
        % print info into a plain text file if required by the user
        if printPlainText
            if n_sols>0
                if ~isdir(outputFolder); mkdir(outputFolder); end; 
                cd(outputFolder);                
                f=fopen([fileName '.txt'],'w');
                fprintf(f,'Reactions\tMin Flux in Wild-type strain\tMax Flux in Wild-type strain\tMin Flux in Mutant strain\tMax Flux in Mutant strain\n');
                for i=1:n_sols
                    sols=strjoin(Solutions{i}.reactions',', ');
                    type=strjoin(Solutions{i}.type',', ');
                    min_str=cell(1,k);
                    max_str=cell(1,k);
                    flux_str=cell(1,k);
                    min=minFluxes_MT(Solutions{i}.pos);
                    max=maxFluxes_MT(Solutions{i}.pos);
                    flux=Solutions{i}.flux;
                    for j=1:k
                        min_str{j}=num2str(min(j));
                        max_str{j}=num2str(max(j));
                        flux_str{j}=num2str(flux(j));
                    end
                    MinFlux=strjoin(min_str,', ');
                    MaxFlux=strjoin(max_str,', ');
                    achieved=strjoin(flux_str,', ');
                    fprintf(f,'%1.0f\t%1.0f\t{%s}\t{%s}\t{%s}\t{%s}\t{%s}\t%4.4f\t%4.4f\t%4.4f\t%4.4f\n',k,i,sols,type,MinFlux,MaxFlux,achieved,Solutions{i}.obj,Solutions{i}.minTarget,Solutions{i}.maxTarget,Solutions{i}.growth);
                end
                fclose(f);
                cd([workingPath '/' runID]);
                if printReport; fprintf(freport,['\nSets found by optForce were printed in ' fileName '.txt  \n']); end;
            else
                fprintf('No solution to optForce was found. Therefore, no plain text file was generated\n');
            end
        else
            fprintf('An error occurred during execution of GAMS\n');
        end
    catch
        %if optfode was not solved correcttly
        fprintf('wrong GtoM read\n');
    end
else
    %if GAMS was not executed correcttly
    if printReport; fprintf(freport,'\nGAMS was not executed correctly\n'); end;
end
%close file for saving report
if printReport; fclose(freport); end;
%remove or move additional files that were generated during running
if keepGAMSOutputs
    movefile('GtoM.gdx',outputFolder);
    movefile(regexprep(optForceFunction,'gms','lst'),outputFolder);
else
    delete('GtoM.gdx');
    delete(regexprep(optForceFunction,'gms','lst'));
end 
if printReport; movefile(reportFileName,outputFolder); end;
delete(optForceFunction);
cd(workingPath);
end