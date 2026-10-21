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
            obj.PRBS = obj.GeneratePRBS(obj.K_bch);
        end
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

            % DFL берём из Setup (а не из заголовка), потому что при низком
            % SNR заголовок может быть битым, а для построения кривой
            % BER/FER нам важно «вырезать» DATA FIELD, даже если он с
            % ошибками. (В реальном приёмнике CRC заголовка проверяется,
            % и кадр отбрасывается — но для лабораторной мы этого не делаем.)
            DFL_recv = obj.DFL;

            % DATA FIELD
            DF = BBF(81:80+DFL_recv);
            TS = reshape(DF, 1504, []);

            % Возвращаем ТОЛЬКО полезные биты (без CRC и без sync),
            % то есть 1496 бит на пакет — ровно то, что генерирует Source
            OutData = double(TS(9:1504, :));
            OutData = OutData(:);
        end
    end
    methods (Access = private)
        function TS = FormTSPackets(obj, InData)
            InData = double(InData(:));
            % На входе — полезные биты без синхробайтов: 1496 на пакет
            if mod(numel(InData), 1496) ~= 0
                error('Длина входных данных должна быть кратна 1496.');
            end
            if any(InData ~= 0 & InData ~= 1)
                error('Входные данные должны состоять из 0 и 1.');
            end
            TS = reshape(InData, 1496, []);
        end
        function TS_CRC = CalcCRC8ForPackets(obj, TS)
            NumPackets = size(TS, 2);
            TS_CRC = zeros(1504, NumPackets);
            for k = 1:NumPackets
                DataBits = TS(:, k);
                CRC = obj.CalcCRC8(DataBits);
                TS_CRC(:, k) = [CRC; DataBits];
            end
        end
        function CRC = CalcCRC8(~, DataBits)
            DataBits = double(DataBits(:));
            G = [1 1 1 0 1 0 1 0 1];
            Work = [DataBits; zeros(8, 1)];
            for k = 1:numel(DataBits)
                if Work(k) == 1
                    for j = 1:9
                        Work(k+j-1) = xor(Work(k+j-1), G(j));
                    end
                end
            end
            CRC = double(Work(end-7:end));
        end
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
            Bytes(:, 1) = de2bi(MATYPE1, 8, 'left-msb')';
            Bytes(:, 2) = de2bi(0, 8, 'left-msb')';
            UPLbits = de2bi(1504, 16, 'left-msb')';
            Bytes(:, 3:4) = reshape(UPLbits, 8, 2);
            DFLbits = de2bi(obj.DFL, 16, 'left-msb')';
            Bytes(:, 5:6) = reshape(DFLbits, 8, 2);
            Bytes(:, 7) = de2bi(71, 8, 'left-msb')';
            Bytes(:, 8:9) = zeros(8, 2);
            HeaderBits = Bytes(:, 1:9);
            Bytes(:, 10) = obj.CalcCRC8(HeaderBits(:));
            BBH = double(Bytes(:));
        end
        function BBF = FormBBFrame(obj, BBH, DF)
            PaddingLength = obj.K_bch - 80 - obj.DFL;
            Padding = zeros(PaddingLength, 1);
            BBF = [BBH(:); DF(:); Padding];
            if numel(BBF) ~= obj.K_bch
                error('Неверная длина BBFRAME.');
            end
        end
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
