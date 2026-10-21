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
            RRC  = Params.RRCFilter;

            obj.isTransparent       = Sig.isTransparent;
            obj.LogLanguage         = LogLanguage;
            obj.RollOff             = RRC.RolloffFactor;
            obj.FilterSpanInSymbols = RRC.FilterSpanInSymbols;
            obj.SamplesPerSymbol    = RRC.SamplesPerSymbol;
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end

            InData = InData(:);
            h = rcosdesign(obj.RollOff, obj.FilterSpanInSymbols, ...
                obj.SamplesPerSymbol, 'sqrt');

            % Передача: передискретизация и RRC-фильтрация.
            OutData = upfirdn(InData, h, obj.SamplesPerSymbol, 1);
        end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end

            InData = InData(:);
            h = rcosdesign(obj.RollOff, obj.FilterSpanInSymbols, ...
                obj.SamplesPerSymbol, 'sqrt');

            % Согласованный RRC-фильтр и децимация.
            Filtered = upfirdn(InData, h, 1, obj.SamplesPerSymbol);

            % Каждый из двух RRC-фильтров имеет групповую задержку
            % FilterSpanInSymbols/2 символов. После двух фильтров суммарно
            % получается FilterSpanInSymbols символов.
            Delay = obj.FilterSpanInSymbols;
            if numel(Filtered) <= 2*Delay
                error('Недостаточная длина сигнала после RRC-фильтрации.');
            end

            % Убираем задержку обоих фильтров и оставляем исходное число
            % символов PLFRAME.
            OutData = Filtered(Delay+1 : end-Delay);
        end
    end
end
