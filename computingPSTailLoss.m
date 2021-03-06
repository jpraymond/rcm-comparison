% Author: Jean-Philippe Raymond (raymonjp@iro.umontreal.ca)
% =========================================================


ESTIMATED_BETAS = [-2.7629, -0.9894, -0.5637, -4.3165, 1.5382];

N_DRAWS = 5;


% Seed used for the partitionning of the observations into three sets (training,
% validation and test).
RNG_SEED = 2015; % 2015, 4055, 1234, 1107

OBS_FILE = 'data/observationsForEstimBAI.txt';
TRAIN_SET_SIZE = 916; % ~50%
VALID_SET_SIZE = 458; % ~25%
% TEST_SET_SIZE = 1832 - TRAIN_SET_SIZE - VALID_SET_SIZE; % ~25%


addpath('code');
addpath('project_code');


rng(RNG_SEED);

% We partition the observations into three sets.
myObs = spconvert(load(OBS_FILE));
myObs = myObs(randperm(size(myObs, 1)), :); % We shuffle the observations.
idxEndTrain = TRAIN_SET_SIZE;
idxEndValid = TRAIN_SET_SIZE + VALID_SET_SIZE;
trainSet = myObs(1:idxEndTrain, :);
validSet = myObs(idxEndTrain+1:idxEndValid, :);
testSet = myObs(idxEndValid+1:end, :);


valid = pathGeneration(validSet, ...
                       sprintf('valid%d', RNG_SEED), ...
                       N_DRAWS, ...
                       ESTIMATED_BETAS, ...
                       false, ...
                       'rngSeed', 20155);
paths = getPaths(valid);

% TODO: Most of the following is way too involved to be in a user script. It
%       should be put in one or several functions (in /project_code).

predictions = psPrediction(paths, N_DRAWS, ESTIMATED_BETAS, false);

pathsWithObservations = addObservationsToPaths(validSet, paths);
predictionsWithObservations = psPrediction(pathsWithObservations, ...
                                           N_DRAWS + 1, ...
                                           ESTIMATED_BETAS, ...
                                           false);

% ======================================================================================
% We join the two predictions (we retrieve the probabilities from the 1st one
% (predictions) and the utilities from the 2nd one (predictionsWithObservations)).
% --------------------------------------------------------------------------------------
obsIDs1 = [predictions.obsID]';
paths1 = getPathsFromPredictions(predictions);
obsIDs2 = [predictionsWithObservations.obsID]';
paths2 = getPathsFromPredictions(predictionsWithObservations);
probabilities = [predictions.probability]';

nPaths1 = size(paths1, 1);
nPaths2 = size(paths2, 1);
pathWidth2 = size(paths2, 2);

% We pad paths1 with zeros so that it has the same width as paths2.
paths1(nPaths1, pathWidth2) = 0;

keys1 = [obsIDs1, paths1];
keys2 = [obsIDs2, paths2];

[~, pred1Indices] = ismember(keys2, keys1, 'rows');

newProbabilities = zeros(nPaths2, 1);
newProbabilities(pred1Indices ~= 0, 1) = probabilities(pred1Indices(pred1Indices ~= 0));

cellNewProbabilities = num2cell(newProbabilities, 2);
[predictionsWithObservations.probability] = cellNewProbabilities{:};
% ======================================================================================

% TODO: This is already computed in predictionsWithObservations.
M = nPathsPerLink(pathsWithObservations, N_DRAWS + 1);
utilities = psUtilitiesForObservations(validSet, ESTIMATED_BETAS, M);

predictionsWithObservations = hansenCorrection(predictionsWithObservations, ...
                                               utilities, ...
                                               N_DRAWS, ...
                                               ESTIMATED_BETAS);

L = losses(utilities, predictionsWithObservations);

disp(sprintf('Tail loss for the PS model: %f', mean(L)));
