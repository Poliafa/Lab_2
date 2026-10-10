Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 4;

BER.BERNumRateDigits = 8;
BER.FERNumRateDigits = 5;
BER.BERPrecision = 5;

% BER.h2Precision = 0;
% BER.h2dBInitStep = 1;
% BER.h2dBMaxStep = 1;
% BER.h2dBMinStep = 1;

% End of Params


Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 16;

% End of Params


Source.NumBitsPerFrame = 2*3*4*5*8;

Mapper.Type = 'PSK';
Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 8;

% End of Params


Source.NumBitsPerFrame = 2*3*4*5*8;

% Mapper.Type = 'PSK';
Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 64;

% End of Params


% =====================================
% Results05 - DVB-S2
% BCH + LDPC + Interleaver
% 8PSK, Rate = 3/4
% =====================================

Source.NumBitsPerFrame = 1504 * 32;

% BBFRAME
BBFrame.isTransparent = false;
BBFrame.RollOff = 0.35;
BBFrame.DFL = 1504 * 32;
BBFrame.K_bch = 48408;

% BCH + LDPC
Encoder.isTransparent = false;
Encoder.Rate = 3/4;
Encoder.N_ldpc = 64800;
Encoder.MaxNumIterations = 50;

% Interleaver
Interleaver.isTransparent = false;

% Mapper
Mapper.isTransparent = false;
Mapper.Type = 'PSK';
Mapper.ModulationOrder = 8;
Mapper.DecisionMethod = 'Approximate log-likelihood ratio';

% Channel
Channel.isTransparent = false;

% End of Params
