classdef ClassBBFrame < handle
    properties (SetAccess = private) % из параметров
        isTransparent;
        RollOff;        % 0.35, 0.25, 0.20
        DFL;            % длина DATA FIELD (кратна 1504)
        LogLanguage;
    end
    properties (SetAccess = private) % вычисляемые
        K_bch;
    end
    methods
        function obj = ClassBBFrame(Params, LogLanguage)
            % Инициализация из Params.BBFrame
            BBFrame = Params.BBFrame;

            % Сохранение параметров в свойства объекта
            obj.isTransparent = BBFrame.isTransparent;
            obj.RollOff       = BBFrame.RollOff;
            obj.DFL           = BBFrame.DFL;
            obj.LogLanguage   = LogLanguage;
            obj.K_bch         = BBFrame.K_bch;

            % Если блок прозрачный — дальнейшие проверки не нужны
            if obj.isTransparent
                return
            end

            % DFL должен быть кратен длине TS-пакета (188 байт = 1504 бита),
            % иначе DATA FIELD не удастся нарезать на целое число пакетов
            if mod(obj.DFL, 1504) ~= 0
                error('DFL должно быть кратно 1504 битам.');
            end
        end

        function OutData = StepTx(obj, InData)
            % Прямая цепочка обработки: InData -> BBFRAME -> скремблирование
            if obj.isTransparent
                OutData = InData;
                return
            end

            TS      = obj.FormTSPackets(InData);       % нарезка на TS-пакеты
            TS_CRC  = obj.CalcCRC8ForPackets(TS);      % CRC-8 и замена sync
            DF      = obj.FormDataField(TS_CRC);       % сборка DATA FIELD
            BBH     = obj.FormBBHeader();              % сборка BBHEADER
            BBF     = obj.FormBBFrame(BBH, DF);        % сборка BBFRAME
            OutData = obj.BBScramble(BBF);             % BB scrambling
        end

        function OutData = StepRx(obj, InData)
            % Обратная процедура — для проверки корректности в модели
            if obj.isTransparent
                OutData = InData;
                return
            end

            % Дескремблирование — та же PRBS, что и в StepTx, XOR
            PRBS = obj.GeneratePRBS(obj.K_bch);
            BBF  = xor(InData(:), PRBS);

            % Извлечение BBHEADER (80 бит) и разбор полей:
            % байты 5-6 — DFL, байт 7 — SYNC
            Bytes    = reshape(BBF(1:80), 8, 10);
            DFL_recv = bi2de(Bytes(:, 5:6)', 'left-msb');
            SYNC     = Bytes(:, 7);

            % Извлечение DATA FIELD и восстановление sync-байтов:
            % вместо CRC-8 (первые 8 бит каждого пакета) возвращаем 0x47
            DF = reshape(BBF(81 : 80 + DFL_recv), 1504, []);
            DF(1:8, :) = repmat(SYNC, 1, size(DF, 2));
            OutData = DF(:);
        end
    end

    methods (Access = private)
        % ---------------------------------------------------------------
        % 1. Нарезка входного потока на MPEG-TS пакеты по 1504 бита
        % ---------------------------------------------------------------
        function TS = FormTSPackets(obj, InData)
            TS = reshape(InData, 1504, []);
        end

        % ---------------------------------------------------------------
        % 2. CRC-8 для каждого пакета + замена sync-байта на CRC
        % ---------------------------------------------------------------
        function TS_CRC = CalcCRC8ForPackets(obj, TS)
            [~, NumPackets] = size(TS);
            TS_CRC = TS;
            for k = 1:NumPackets
                % CRC считается от 1496 бит данных без sync-байта
                CRC = obj.CalcCRC8(TS(9:1504, k));
                % CRC заменяет sync-байт (первые 8 бит)
                TS_CRC(1:8, k) = CRC;
            end
        end

        % ---------------------------------------------------------------
        %    CRC-8: сдвиговый регистр из 8 триггеров
        %    Полином: X^8 + X^7 + X^6 + X^4 + X^2 + 1
        %    Все триггеры обновляются одновременно (через r_new)
        % ---------------------------------------------------------------
        function CRC = CalcCRC8(~, DataBits)
            r = zeros(8, 1);   % начальное состояние регистра

            for k = 1:length(DataBits)
                f = xor(DataBits(k), r(8));   % обратная связь

                % Одновременное обновление всех восьми триггеров
                r_new    = zeros(8, 1);
                r_new(1) = f;
                r_new(2) = r(1);
                r_new(3) = xor(r(2), f);
                r_new(4) = r(3);
                r_new(5) = xor(r(4), f);
                r_new(6) = r(5);
                r_new(7) = xor(r(6), f);
                r_new(8) = xor(r(7), f);

                r = r_new;
            end
            CRC = r;
        end

        % ---------------------------------------------------------------
        % 3. Сборка DATA FIELD из нарезанных TS-пакетов
        % ---------------------------------------------------------------
        function DF = FormDataField(obj, TS_CRC)
            DF = TS_CRC(:);
        end

        % ---------------------------------------------------------------
        % 4. Формирование BBHEADER (80 бит = 10 байт)
        %    Раскладка: MATYPE-1(1) MATYPE-2(1) UPL(2) DFL(2)
        %               SYNC(1) SYNCD(2) CRC-8(1)
        % ---------------------------------------------------------------
        function BBH = FormBBHeader(obj)
            % MATYPE-1: TS/GS=11, SIS=1, CCM=1, ISSYI=0, NPD=0, RO
            switch obj.RollOff
                case 0.35, MATYPE1 = 0xF0;   % RO = 00
                case 0.25, MATYPE1 = 0xF1;   % RO = 01
                case 0.20, MATYPE1 = 0xF2;   % RO = 10
                otherwise, error('Недопустимое значение RollOff.');
            end

            % Сборка байтов в матрицу 8 x 10 (каждый столбец — байт)
            Bytes = zeros(8, 10);
            Bytes(:, 1)   = de2bi(MATYPE1, 8, 'left-msb')';                  % MATYPE-1
            Bytes(:, 2)   = de2bi(0x00, 8, 'left-msb')';                     % MATYPE-2 (SIS)
            Bytes(:, 3:4) = reshape(de2bi(1504, 16, 'left-msb')', 8, 2);     % UPL = 1504
            Bytes(:, 5:6) = reshape(de2bi(obj.DFL, 16, 'left-msb')', 8, 2);  % DFL
            Bytes(:, 7)   = de2bi(0x47, 8, 'left-msb')';                     % SYNC = 0x47
            Bytes(:, 8:9) = reshape(de2bi(0, 16, 'left-msb')', 8, 2);        % SYNCD = 0

            % CRC-8 считается от первых 9 байт (72 бита)
            HeaderBits = Bytes(:, 1:9);
                Bytes(:, 10) = obj.CalcCRC8(HeaderBits(:));
            BBH = Bytes(:);
        end

        % ---------------------------------------------------------------
        % 5. Сборка BBFRAME = BBHEADER + DATA FIELD + PADDING
        % ---------------------------------------------------------------
        function BBF = FormBBFrame(obj, BBH, DF)
            Padding = zeros(obj.K_bch - 80 - obj.DFL, 1);
            BBF = [BBH(:); DF(:); Padding];
        end

        % ---------------------------------------------------------------
        % 6. BB scrambling: XOR BBFRAME с PRBS-последовательностью
        % ---------------------------------------------------------------
        function OutData = BBScramble(obj, BBF)
            PRBS = obj.GeneratePRBS(obj.K_bch);
            OutData = xor(BBF(:), PRBS);
        end

        % ---------------------------------------------------------------
        %    PRBS-генератор: полином 1 + X^14 + X^15
        %    Начальное состояние: 100101010000000
        %    Регистр сдвигается вправо, новый бит — слева
        % ---------------------------------------------------------------
        function PRBS = GeneratePRBS(~, Length)
            Reg = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];   % 15 бит
            PRBS = zeros(Length, 1);
            for k = 1:Length
                p = xor(Reg(14), Reg(15));   % обратная связь
                PRBS(k) = p;
                Reg = [p, Reg(1:14)];        % сдвиг вправо
            end
        end
    end
end