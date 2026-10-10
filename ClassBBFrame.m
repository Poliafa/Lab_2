classdef ClassBBFrame < handle
    properties (SetAccess = private)
        isTransparent;
        RollOff;
        DFL;
        LogLanguage;
        K_bch;
    end
    properties (Access = private)
        PRBS;
        PrevCRC;
    end
    methods
        % Конструктор
        function obj = ClassBBFrame(Params, LogLanguage)
            BBFrame = Params.BBFrame;
            obj.isTransparent = BBFrame.isTransparent;
            obj.RollOff = BBFrame.RollOff;
            obj.DFL = BBFrame.DFL;
            obj.LogLanguage = LogLanguage;
            obj.K_bch = BBFrame.K_bch;
            obj.PRBS = [];
            obj.PrevCRC = zeros(8, 1);
            if obj.isTransparent
                return;
            end
            if obj.DFL <= 0 || mod(obj.DFL, 1504) ~= 0
                error('DFL должно быть положительным и кратным 1504.');
            end
            if obj.DFL > 65535
                error('DFL не помещается в 16 бит.');
            end
            if obj.K_bch < obj.DFL + 80
                error('Недостаточная длина K_bch.');
            end
            if ~ismember(obj.RollOff, [0.35 0.25 0.20])
                error('Недопустимое значение RollOff.');
            end
            % PRBS создаётся один раз
            obj.PRBS = obj.GeneratePRBS(obj.K_bch);
        end
        % Передатчик
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            TS = obj.FormTSPackets(InData);
            TS_CRC = obj.CalcCRC8ForPackets(TS);
            DF = TS_CRC(:);
            BBH = obj.FormBBHeader();
            BBF = obj.FormBBFrame(BBH, DF);
            OutData = double(xor(BBF(:), obj.PRBS));
        end
        % Приёмник
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            InData = InData(:);
            if numel(InData) ~= obj.K_bch
                error('Неверная длина принятого BBFRAME.');
            end
            % Дескремблирование
            BBF = double(xor(InData, obj.PRBS));
            % Заголовок
            BBH = BBF(1:80);
            Bytes = reshape(BBH, 8, 10);
            % Проверка CRC заголовка
            CRC_recv = BBH(73:80);
            CRC_calc = obj.CalcCRC8(BBH(1:72));
            if any(CRC_recv ~= CRC_calc)
                error('Ошибка CRC-8 заголовка BBFRAME.');
            end
            % DFL занимает два байта
            DFL_bits = Bytes(:, 5:6);
            DFL_recv = bi2de(DFL_bits(:)', 'left-msb');
            if DFL_recv ~= obj.DFL
                error('Неверный DFL: %d, ожидалось %d.', ...
                    DFL_recv, obj.DFL);
            end
            if mod(DFL_recv, 1504) ~= 0
                error('DFL не кратно длине TS-пакета.');
            end
            % Синхробайт
            SYNC = Bytes(:, 7);
            % DATA FIELD
            DF = BBF(81:80+DFL_recv);
            TS = reshape(DF, 1504, []);
            % Восстановление синхробайтов
            TS(1:8, :) = repmat(SYNC, 1, size(TS, 2));
            OutData = double(TS(:));
        end
    end
    methods (Access = private)
        % Формирование TS-пакетов
        function TS = FormTSPackets(obj, InData)
            InData = double(InData(:));
            if numel(InData) ~= obj.DFL
                error('Длина входных данных не совпадает с DFL.');
            end
            if any(InData ~= 0 & InData ~= 1)
                error('Входные данные должны состоять из 0 и 1.');
            end
            TS = reshape(InData, 1504, []);
        end
        % CRC-8 и замена синхробайтов
        function TS_CRC = CalcCRC8ForPackets(obj, TS)
            TS_CRC = TS;
            for k = 1:size(TS, 2)
                % CRC предыдущего пакета
                TS_CRC(1:8, k) = obj.PrevCRC;
                % CRC текущего пакета
                DataBits = TS(9:1504, k);
                CRC = obj.CalcCRC8(DataBits);
                % Сохраняем для следующего пакета
                obj.PrevCRC = CRC;
            end
        end
        % CRC-8 DVB-S2
        % g(x) = x^8 + x^7 + x^6 + x^4 + x^2 + 1
        function CRC = CalcCRC8(~, DataBits)
            DataBits = double(DataBits(:));
            G = [1 1 1 0 1 0 1 0 1];
            Work = [DataBits; zeros(8, 1)];
            for k = 1:numel(DataBits)
                if Work(k) == 1
                    for j = 1:9
                        Work(k+j-1) = ...
                            xor(Work(k+j-1), G(j));
                    end
                end
            end
            CRC = double(Work(end-7:end));
        end
        % Формирование BBHEADER
        function BBH = FormBBHeader(obj)
            switch obj.RollOff
                case 0.35
                    MATYPE1 = 240;
                case 0.25
                    MATYPE1 = 241;
                case 0.20
                    MATYPE1 = 242;
                otherwise
                    error('Недопустимый RollOff.');
            end
            Bytes = zeros(8, 10);
            % MATYPE-1
            Bytes(:, 1) = de2bi(MATYPE1, 8, 'left-msb')';
            % MATYPE-2
            Bytes(:, 2) = de2bi(0, 8, 'left-msb')';
            % UPL = 1504
            UPLbits = de2bi(1504, 16, 'left-msb')';
            Bytes(:, 3:4) = reshape(UPLbits, 8, 2);
            % DFL
            DFLbits = de2bi(obj.DFL, 16, 'left-msb')';
            Bytes(:, 5:6) = reshape(DFLbits, 8, 2);
            % SYNC = 0x47
            Bytes(:, 7) = de2bi(71, 8, 'left-msb')';
            % SYNCD = 0
            Bytes(:, 8:9) = zeros(8, 2);
            % CRC-8 BBHEADER
            HeaderBits = Bytes(:, 1:9);
            Bytes(:, 10) = obj.CalcCRC8(HeaderBits(:));
            BBH = double(Bytes(:));
        end
        % Формирование BBFRAME
        function BBF = FormBBFrame(obj, BBH, DF)
            PaddingLength = obj.K_bch - 80 - obj.DFL;
            Padding = zeros(PaddingLength, 1);
            BBF = [BBH(:); DF(:); Padding];
            if numel(BBF) ~= obj.K_bch
                error('Неверная длина BBFRAME.');
            end
        end
        % Генерация PRBS
        function PRBS = GeneratePRBS(~, Length)
            Reg = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];
            PRBS = zeros(Length, 1);
            for k = 1:Length
                p = xor(Reg(14), Reg(15));
                PRBS(k) = p;
                Reg = [p, Reg(1:14)];
            end
        end
    end
end
