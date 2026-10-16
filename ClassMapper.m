classdef ClassMapper < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять модуляцию и демодуляцию
        isTransparent;
        % Тип сигнального созвездия
        Type;
        % Размер сигнального созвездия
        ModulationOrder;
        % Ротация сигнального созвездия
        PhaseOffset;
        % Тип отображения бит на точки сигнального созвездия: Binary | Gray
        SymbolMapping;
        % Вариант принятия решений о модуляционных символах: Hard decision
        % | Log-likelihood ratio | Approximate log-likelihood ratio
        DecisionMethod;
        % Переменная управления языком вывода информации для пользователя
        LogLanguage;
        % --- ДЛЯ PLHEADER И ПИЛОТОВ --- ДОБАВИЛА
        Rate;% скорость LDPC (для MODCOD)
        N_ldpc;% длина LDPC-кодового слова
        HasPilots;% флаг наличия пилотов
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Массив точек сигнального созвездия и соответствующий ему массив
        % бит
        Constellation;
        Bits;
        % Часто используемое значение
        log2M;
        % Объекты для модуляции/демодуляции
        Mapper;
        DeMapper;
        % --- ДЛЯ PLHEADER И ПИЛОТОВ --- ДОБАВИЛА
        PLHeader;% 90 комплексных символов PLHEADER
        PilotSymbol;% 1 символ пилота: (1+1j)/sqrt(2)
    end
    methods
        function obj = ClassMapper(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
            Mapper  = Params.Mapper;
            Encoder = Params.Encoder; %добавила
            % Инициализация значений переменных из параметров
            obj.isTransparent = Mapper.isTransparent;
            obj.Type            = Mapper.Type;
            obj.ModulationOrder = Mapper.ModulationOrder;
            obj.PhaseOffset     = Mapper.PhaseOffset;
            obj.SymbolMapping   = Mapper.SymbolMapping;
            obj.DecisionMethod  = Mapper.DecisionMethod;
            % Переменная LogLanguage
            obj.LogLanguage = LogLanguage;


            %ДОБАВИЛА
            obj.Rate      = Encoder.Rate;
            obj.N_ldpc    = Encoder.N_ldpc;
            obj.HasPilots = Mapper.HasPilots;
            obj.PilotSymbol = (1 + 1j)/sqrt(2);




            % Расчёт часто используемого значения
            obj.log2M = log2(Mapper.ModulationOrder);

            % Инициализация объектов-модуляторов
            if strcmp(Mapper.Type, 'QAM')
                obj.Mapper = comm.RectangularQAMModulator( ...
                    'ModulationOrder', Mapper.ModulationOrder, ...
                    'PhaseOffset', Mapper.PhaseOffset, ...
                    'BitInput', true, ...
                    'SymbolMapping', Mapper.SymbolMapping ...
                    );
                obj.DeMapper = comm.RectangularQAMDemodulator( ...
                    'ModulationOrder', Mapper.ModulationOrder, ...
                    'PhaseOffset', Mapper.PhaseOffset, ...
                    'BitOutput', true, ...
                    'SymbolMapping', Mapper.SymbolMapping, ...
                    'DecisionMethod', Mapper.DecisionMethod ...
                    );
            elseif strcmp(Mapper.Type, 'PSK')
                obj.Mapper = comm.PSKModulator( ...
                    'ModulationOrder', Mapper.ModulationOrder, ...
                    'PhaseOffset', Mapper.PhaseOffset, ...
                    'BitInput', true, ...
                    'SymbolMapping', Mapper.SymbolMapping ...
                    );
                obj.DeMapper = comm.PSKDemodulator( ...
                    'ModulationOrder', Mapper.ModulationOrder, ...
                    'PhaseOffset', Mapper.PhaseOffset, ...
                    'BitOutput', true, ...
                    'SymbolMapping', Mapper.SymbolMapping, ...
                    'DecisionMethod', Mapper.DecisionMethod ...
                    );
            end

            % Определим массив возможных бит на входе модулятора и
            % соответствующих модуляционных символов
            if obj.isTransparent
                obj.Bits = 1;
                obj.Constellation = 1;
                obj.PLHeader = [];%ДОБАВИЛА
            else
                obj.Bits = de2bi(0:obj.ModulationOrder-1, ...
                    obj.log2M, 'left-msb').';
                obj.Constellation = obj.Mapper.step(obj.Bits(:));
                obj.PLHeader = obj.FormPLHeader();%ДОБАВИЛА
            end
        end

        %*******************************
        % ФОРМИРОВАНИЕ PLHEADER
        function MODCOD = GetMODCOD(obj)
            % Номер MODCOD (1..28) по таблице 12 стандарта
            M = obj.ModulationOrder;
            R = obj.Rate;

            codeRateValues = [1/4 1/3 2/5 1/2 3/5 2/3 3/4 4/5 5/6 8/9 9/10 ...
                3/5 2/3 3/4 5/6 8/9 9/10 ...
                2/3 3/4 4/5 5/6 8/9 9/10 ...
                3/4 4/5 5/6 8/9 9/10];

            switch M
                case 4,  idxRange = 1:11;
                case 8,  idxRange = 12:17;
                case 16, idxRange = 18:23;
                case 32, idxRange = 24:28;
                otherwise, error('Неподдерживаемая модуляция M=%d', M);
            end
            idx = idxRange(abs(codeRateValues(idxRange) - R) < 1e-6);
            if isempty(idx)
                error('Нет MODCOD для M=%d, R=%g', M, R);
            end
            MODCOD = idx;
        end

        function PLS = FormPLSCode(obj, b07)
            % b07 - 7 бит: [b0, MODCOD(5), shortFlag, pilotsFlag]
            % Порождающая матрица (32,7) из стандарта (см. plHeader.m)
            genMat = [1 0 0 1 0 0 0 0 1 0 1 0 1 1 0 0 0 0 1 0 1 1 0 1 1 1 0 1 1 1 0 1;
                0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1;
                0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1;
                0 0 0 0 1 1 1 1 0 0 0 0 1 1 1 1 0 0 0 0 1 1 1 1 0 0 0 0 1 1 1 1;
                0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1;
                0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
                1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1];

            n = mod(b07(1:7) * genMat, 2);       % берём только первые 7 бит

            b64 = zeros(64, 1);
            b64(1:2:end) = n;                    % чётные позиции = n
            if b07(end)                          % pilots on
                b64(2:2:end) = 1 - n;            % нечётные = инверсия
            else
                b64(2:2:end) = n;                % нечётные = n
            end

            % Скремблирование (64-битная последовательность из стандарта)
            scramSeq = [0 1 1 1 0 0 0 1 1 0 0 1 1 1 0 1 1 0 0 0 0 0 1 1 1 1 0 0 1 0 0 1 ...
                0 1 0 1 0 0 1 1 0 1 0 0 0 0 1 0 0 0 1 0 1 1 0 1 1 1 1 1 1 0 1 0]';
            PLS = xor(b64, scramSeq);
        end

        function PLHeader = FormPLHeader(obj)
            % SOF (26 бит) - фиксированная последовательность 18D2E82 HEX
            SOF = [0 1 1 0 0 0 1 1 0 1 0 0 1 0 1 1 1 0 1 0 0 0 0 0 1 0]';

            % Формирование 7 бит b07
            b0         = 0;                              % DVB-S2 (не S2X)
            MODCOD     = obj.GetMODCOD();
            modCodBits = int2bit(MODCOD, 5);
            modCodBits = modCodBits(:)';                 % гарантированно 1*5 (строка)
            shortFlag  = 0;                              % normal FECFRAME
            pilotsFlag = double(obj.HasPilots);
            b07        = [b0, modCodBits, shortFlag, pilotsFlag];   % 1*7

            % PLS-код (64 бита)
            PLS = obj.FormPLSCode(b07);

            % PLHEADER = 90 бит
            sigBits = [SOF; PLS];

            % pi/2-BPSK модуляция: 90 символов
            modSymb = (1 - 2*sigBits) / sqrt(2);
            PLHeader = complex(zeros(90, 1));
            PLHeader(1:2:end) =  modSymb(1:2:end) + 1j*modSymb(1:2:end);
            PLHeader(2:2:end) = -modSymb(2:2:end) + 1j*modSymb(2:2:end);
        end

        % РАЗБИЕНИЕ НА СЛОТЫ И ВСТАВКА ПИЛОТОВ
        function PLFrame = InsertPilotsAndSlots(obj, XFECFrame)
            XFECFrame = XFECFrame(:);
           % fprintf('DEBUG: length(XFECFrame) = %d, mod 90 = %d\n', ...
              %  length(XFECFrame), mod(length(XFECFrame), 90));
            S = length(XFECFrame) / 90;
            if mod(S, 1) ~= 0
                error('Длина XFECFRAME должна быть кратна 90 (получено %d)', ...
                    length(XFECFrame));
            end


            % Верхняя оценка длины: XFECFrame + 36 символов на каждый пилотный блок
            XFECWithPilots = complex(zeros(length(XFECFrame) + 36*floor(S/16), 1));
            outIdx = 0;
            for s = 1:S
                % Текущий слот (90 символов)
                XFECWithPilots(outIdx+1 : outIdx+90) = XFECFrame((s-1)*90+1 : s*90);
                outIdx = outIdx + 90;

                % После каждого 16-го слота  пилотный блок (36 символов)
                % Если s == S, пилот не вставляем (он бы совпал с началом SOF)
                if obj.HasPilots && mod(s,16)==0 && (s < S)
                    XFECWithPilots(outIdx+1 : outIdx+36) = ...
                        repmat(obj.PilotSymbol, 36, 1);
                    outIdx = outIdx + 36;
                end
            end
            XFECWithPilots = XFECWithPilots(1:outIdx);

            % PLFRAME = PLHEADER (90 символов) + (XFECFRAME с пилотами)
            PLFrame = [obj.PLHeader; XFECWithPilots];
        end

        function XFECFrame = RemovePilots(obj, Payload)
            % Обратная операция для приёма
            Payload  = Payload(:);
            XFECLen  = obj.N_ldpc / obj.log2M;
            XFECFrame = complex(zeros(XFECLen, 1));

            inIdx = 0; outIdx = 0; slotIdx = 0;
            while outIdx < XFECLen
                XFECFrame(outIdx+1 : outIdx+90) = Payload(inIdx+1 : inIdx+90);
                inIdx  = inIdx  + 90;
                outIdx = outIdx + 90;
                slotIdx = slotIdx + 1;
                if obj.HasPilots && mod(slotIdx,16)==0 && outIdx < XFECLen
                    inIdx = inIdx + 36;   % пропускаем пилотный блок
                end
            end
        end
        %**********************************
        % function OutData = StepTx(obj, InData)
        %     if obj.isTransparent
        %         OutData = InData;
        %         return
        %     end
        % 
        %     OutData = obj.Mapper.step(InData);
        % end
        %         function OutData = StepRx(obj, InData, InstChannelParams)
        %             if obj.isTransparent
        %                 OutData = InData;
        %                 return
        %             end
        %
        %             if ~(strcmp(obj.DecisionMethod, 'Hard decision'))
        %                 set(obj.DeMapper, 'Variance', InstChannelParams.Variance);
        %             end
        %             OutData = obj.DeMapper.step(InData);
        %         end
        %     end
        % end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            % 1) Модуляция: биты - XFECFRAME
            XFECFrame = obj.Mapper.step(InData);
            % 2) Формирование PLFRAME: PLHEADER + слоты + пилоты
            OutData   = obj.InsertPilotsAndSlots(XFECFrame);
        end

        function OutData = StepRx(obj, InData, InstChannelParams)
            if obj.isTransparent
                OutData = InData;
                return
            end
            % 1) Отбрасываем PLHEADER (90 символов)
            Payload = InData(91:end);
            % 2) Убираем пилотные блоки
            XFECFrame = obj.RemovePilots(Payload);
            % 3) Демодуляция
            if ~strcmp(obj.DecisionMethod, 'Hard decision')
                set(obj.DeMapper, 'Variance', InstChannelParams.Variance);
            end
            OutData = obj.DeMapper.step(XFECFrame);
        end
    end
end
