function saveInputsMustSetsFirstOrder(model, minFluxesW, maxFluxesW, constrOpt,inputFolder)
%% DESCRIPTION
% This function saves all the inputs needed to run functions to find first
% order Must Sets (MustU, Must L). The inputs will be stored in
% inputFolder.
%
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
% minFluxesW (obligatory)   Type: double array of size n_rxns x1
%                           Description: Minimum fluxes for each reaction
%                           in the model for wild-type strain. This can be
%                           obtained by running the function FVAOptForce
%                           Example: minFluxesW=[-90; -56];
%
% maxFluxesW (obligatory)   Type: double array of size n_rxns x1
%                           Description: Maximum fluxes for each reaction
%                           in the model for wild-type strain. This can be
%                           obtained by running the function FVAOptForce
%                           Example: maxFluxesW=[-90; -56];
%
% constrOpt (obligatory):   Type: Structure
%                           Description: structure containing additional
%                           contraints. The structure has the following
%                           fields:
%                           rxnList: (Type: cell array)      Reaction list
%                           values:  (Type: double array)    Values for constrained reactions
%                           sense:   (Type: char array)      Constraint senses for constrained reactions (G/E/L)
%                                                            (G: Greater than; E: Equal to; L: Lower than)
%                           Example: struct('rxnList',{{'EX_gluc','R75','EX_suc'}},'values',[-100,0,155.5]','sense','EEE');
%
% inputFolder(obligatory):      Type: string. 
%                               Description: Folder where inputs for GAMS
%                               function will be stored

%% OUTPUTS
% model.mat                     Type: file
%                               Description: File containing the
%                               model
%
% minFluxesW.mat                Type: file
%                               Description: File containing the
%                               minimum fluxes for the wild-type
%
% maxFluxes.mat                 Type: file
%                               Description: File containing the
%                               maximum fluxes for the wild-type

%% CODE
%input handling
if nargin < 5  
    error('OptForce: All inputs must be specified when running saveInputsMustFirstOrder')
end
if isempty(model)
    error('OptForce: model must be specified when running saveInputsMustFirstOrder')
end
if isempty(minFluxesW)
    error('OptForce: minFluxesW must be specified when running saveInputsMustFirstOrder')
end
if isempty(maxFluxesW)
    error('OptForce: maxFluxesW must be specified when running saveInputsMustFirstOrder')
end
if isempty(inputFolder)
    error('OptForce: inputFolder must be specified when running saveInputsMustFirstOrder')
end


%Create a temporaty folder for inputs
if ~exist(inputFolder, 'dir')
   mkdir(inputFolder); 
end
current = pwd;
cd(inputFolder);

%save variables
save('model','model');
save('minFluxesW','minFluxesW');
save('maxFluxesW','maxFluxesW');
save('constrOpt','constrOpt');

cd(current);

end