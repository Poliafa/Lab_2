% =====================================
% Results01 - DVB-S2, Команда 4
% BCH + LDPC + Interleaver + 8PSK
% RLDPC = 3/4, pilots = ON
% =====================================
Source.NumBitsPerFrame = 1496*32;

BBFrame.isTransparent = false;
BBFrame.RollOff = 0.35;
BBFrame.DFL = 1504*32;
BBFrame.K_bch = 48408;

% BCH + LDPC
Encoder.isTransparent = false;
Encoder.Rate = 3/4;
Encoder.N_ldpc = 64800;
Encoder.MaxNumIterations = 50;

% Interleaver
Interleaver.isTransparent = false;

% Mapper + PLHEADER + пилоты
Mapper.isTransparent = false;
Mapper.Type = 'PSK';
Mapper.ModulationOrder = 8;
Mapper.DecisionMethod = 'Approximate log-likelihood ratio';
Mapper.HasPilots = true;

% =====================================
% Человек 4
% =====================================
PLScrambler.isTransparent = false;
PLScrambler.ScramblingCodeIndex = 0;  % n = 0
PLScrambler.HeaderLength = 90;         % PLHEADER не скремблируется
PLScrambler.MaxSequenceLength = 66420;

RRCFilter.isTransparent = false;
RRCFilter.RolloffFactor = 0.35;
RRCFilter.FilterSpanInSymbols = 10;    % Ta = 10T
RRCFilter.SamplesPerSymbol = 4;

Sig.isTransparent = false;

% Channel
Channel.isTransparent = false;

% === Параметры расчёта кривой ===
BER.h2dBInit     = 4.0;
BER.h2dBMax      = 12.0;
BER.h2dBInitStep = 0.5;
BER.h2dBMaxStep  = 1.0;
BER.h2dBMinStep  = 0.1;

BER.MinBER         = 1e-6;
BER.MinFER         = 1e-3;
BER.MaxNumTrBits   = 1e9;
BER.MinNumTrFrames = 500;
BER.MinNumErFrames = 100;
BER.MinNumErBits   = 500;

% End of Params
