classdef ClassEncoder < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять кодирование и декодирование
            isTransparent;
        % Скорость LDPC-кода (например, 3/4)
            Rate;
        % Длина LDPC-кодового слова (n_ldpc)
            N_ldpc;
        % Максимальное число итераций LDPC-декодера
            MaxNumIterations;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Параметры каскада BCH+LDPC (для n_ldpc = 64800)
            K_bch;   % длина BBFRAME (вход BCH)
            N_bch;   % длина BCH-кодового слова (= K_ldpc)
            t;       % корректирующая способность BCH
            K_ldpc;  % длина информационной части LDPC (= N_bch)
        % Полная скорость каскада BCH+LDPC
            FullRate;
        % Флаг: являются ли решения демодулятора мягкими
            isSoftInput;
        % Объекты для кодирования/декодирования
            BCHEncoder;
            BCHDecoder;
            LDPCEncoderCfg;   % ldpcEncoderConfig
            LDPCDecoderCfg;   % ldpcDecoderConfig
    end
    methods
        function obj = ClassEncoder(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Encoder = Params.Encoder;
                Mapper  = Params.Mapper;
            % Инициализация значений переменных из параметров
                obj.isTransparent     = Encoder.isTransparent;
                obj.Rate              = Encoder.Rate;
                obj.N_ldpc            = Encoder.N_ldpc;
                obj.MaxNumIterations  = Encoder.MaxNumIterations;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

            % Если блок прозрачный — дальнейшие вычисления не нужны
                if obj.isTransparent
                    obj.isSoftInput = false;
                    obj.FullRate    = 1;
                    return
                end

            % Согласно стандарту DVB-S2 (таблица 5a для n_ldpc = 64800)
            % определяем параметры каскада BCH+LDPC по скорости LDPC
                if obj.N_ldpc ~= 64800
                    error('Only normal FECFRAME (64800 bits) is supported.');
                end
                obj.N_ldpc = 64800;   % нормальный FECFRAME
                switch obj.Rate
                    case 1/4
                        obj.K_bch = 16008; obj.N_bch = 16200; obj.t = 12;
                    case 1/3
                        obj.K_bch = 21408; obj.N_bch = 21600; obj.t = 12;
                    case 2/5
                        obj.K_bch = 25728; obj.N_bch = 25920; obj.t = 12;
                    case 1/2
                        obj.K_bch = 32208; obj.N_bch = 32400; obj.t = 12;
                    case 3/5
                        obj.K_bch = 38688; obj.N_bch = 38880; obj.t = 12;
                    case 2/3
                        obj.K_bch = 43040; obj.N_bch = 43200; obj.t = 10;
                    case 3/4
                        obj.K_bch = 48408; obj.N_bch = 48600; obj.t = 12;
                    case 4/5
                        obj.K_bch = 51648; obj.N_bch = 51840; obj.t = 12;
                    case 5/6
                        obj.K_bch = 53840; obj.N_bch = 54000; obj.t = 10;
                    case 8/9
                        obj.K_bch = 57472; obj.N_bch = 57600; obj.t = 8;
                    case 9/10
                        obj.K_bch = 58192; obj.N_bch = 58320; obj.t = 8;
                    otherwise
                        if strcmp(obj.LogLanguage, 'Russian')
                            error(['Недопустимое значение Encoder.Rate ', ...
                                'для n_ldpc = 64800.']);
                        else
                            error(['Invalid value of Encoder.Rate for ', ...
                                'n_ldpc = 64800.']);
                        end
                end
                obj.K_ldpc = obj.N_bch;
                obj.FullRate = obj.K_bch / obj.N_ldpc;

            % Флаг мягкого входа (зависит от решения демодулятора)
                obj.isSoftInput = ~strcmp(Mapper.DecisionMethod, ...
                    'Hard decision');

            % Инициализация объектов-кодеров/декодеров BCH
                obj.BCHEncoder = comm.BCHEncoder(obj.N_bch, obj.K_bch);
                obj.BCHDecoder = comm.BCHDecoder(obj.N_bch, obj.K_bch);

            % Проверочная матрица LDPC и конфигурации кодера/декодера
                H = dvbs2ldpc(obj.Rate);
                obj.LDPCEncoderCfg = ldpcEncoderConfig(H);
                obj.LDPCDecoderCfg = ldpcDecoderConfig(H);
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            InData = InData(:);

            % BCH-кодирование (внешний код)
            % Приведение к double обязательно: comm.BCHEncoder не принимает
            % logical/int8 на входе
                BCHData = obj.BCHEncoder.step(double(InData));

            % LDPC-кодирование (внутренний код)
                OutData = ldpcEncode(BCHData, obj.LDPCEncoderCfg);
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            InData = InData(:);

            % ldpcDecode expects LLR: positive means bit 0.
            if obj.isSoftInput
                LLR = double(InData);
            else
                % Convert hard bits into confident LLRs.
                LLR = 20 * (1 - 2 * double(InData));
            end
            LDPCData = ldpcDecode(LLR, obj.LDPCDecoderCfg, ...
                obj.MaxNumIterations, 'DecisionType', 'hard');
            LDPCData = double(LDPCData(:));

            % BCH-декодирование (внешний код)
            % Приведение к double обязательно: comm.BCHDecoder не принимает
            % logical/int8 на входе
                OutData = obj.BCHDecoder.step(double(LDPCData(:)));
        end
    end
end
