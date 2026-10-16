classdef ClassSig < handle
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        RollOff;
        FilterSpanInSymbols;
        SamplesPerSymbol;
    end
    methods
        function obj = ClassSig(Params, LogLanguage)
            Sig = Params.Sig;
            BBFrame = Params.BBFrame;
            obj.isTransparent = Sig.isTransparent;
            obj.LogLanguage = LogLanguage;
            obj.RollOff = BBFrame.RollOff;
            obj.FilterSpanInSymbols = 10;
            obj.SamplesPerSymbol = 4;
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent, OutData = InData; return; end
            InData = InData(:);
            h = rcosdesign(obj.RollOff, obj.FilterSpanInSymbols, obj.SamplesPerSymbol, 'sqrt');
            OutData = upfirdn(InData, h, obj.SamplesPerSymbol, 1);
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent, OutData = InData; return; end
            InData = InData(:);
            h = rcosdesign(obj.RollOff, obj.FilterSpanInSymbols, obj.SamplesPerSymbol, 'sqrt');
            Filtered = upfirdn(InData, h, 1, obj.SamplesPerSymbol);
            Delay = obj.FilterSpanInSymbols;
            Start = Delay + 1;
            if Start > numel(Filtered), error('Недостаточная длина сигнала после RRC-фильтрации.'); end
            OutData = Filtered(Start:end);
        end
    end
end
