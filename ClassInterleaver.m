classdef ClassInterleaver < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять перемежение и деперемежение
            isTransparent;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Размеры блочного перемежителя
            NumRows;
            NumCols;
        % Вектор перестановки: PermVec(ReadPos) = WritePos
            PermVec;
        % Обратный вектор перестановки: InvPermVec(WritePos) = ReadPos
            InvPermVec;
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Interleaver = Params.Interleaver;
                Mapper      = Params.Mapper;
                Encoder     = Params.Encoder;
            % Инициализация значений переменных из параметров
                obj.isTransparent = Interleaver.isTransparent;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

            % Если блок прозрачный — дальнейшие вычисления не нужны
                if obj.isTransparent
                    return
                end

            % Если кодирование прозрачно, перемежитель тоже не нужен
                if Encoder.isTransparent
                    obj.isTransparent = true;
                    return
                end

            % Определим параметры блочного перемежителя по типу модуляции
            % (таблица 8 стандарта DVB-S2)
                n_ldpc = 64800;   % нормальный FECFRAME
                switch Mapper.Type
                    case 'QAM'
                        if Mapper.ModulationOrder == 4
                            % QPSK: перемежитель не применяется
                            obj.isTransparent = true;
                            return
                        else
                            error(['Перемежитель определён только для ', ...
                                'QPSK, 8PSK, 16APSK, 32APSK.']);
                        end
                    case 'PSK'
                        switch Mapper.ModulationOrder
                            case 4   % QPSK
                                obj.isTransparent = true;
                                return
                            case 8   % 8PSK
                                obj.NumCols = 3;
                            otherwise
                                error(['Перемежитель для PSK с M=%d ', ...
                                    'не определён.'], ...
                                    Mapper.ModulationOrder);
                        end
                    otherwise
                        error('Недопустимое значение Mapper.Type.');
                end

            if Mapper.ModulationOrder == 8 && Encoder.Rate == 3/5
                error(['8PSK rate 3/5 requires special DVB-S2 interleaver ', ...
                    'column ordering; this mode is not implemented yet.']);
            end
            % Число строк: n_ldpc / NumCols
                obj.NumRows = n_ldpc / obj.NumCols;

            % Построим вектор перестановки:
            % запись по столбцам, чтение по строкам
            %   WritePos = col*NumRows + row + 1   (col = 0..NumCols-1)
            %   ReadPos  = row*NumCols + col + 1   (row = 0..NumRows-1)
                obj.PermVec    = zeros(n_ldpc, 1);
                obj.InvPermVec = zeros(n_ldpc, 1);
                for row = 0:obj.NumRows-1
                    for col = 0:obj.NumCols-1
                        WritePos = col*obj.NumRows + row + 1;
                        ReadPos  = row*obj.NumCols + col + 1;
                        obj.PermVec(ReadPos)     = WritePos;
                        obj.InvPermVec(WritePos) = ReadPos;
                    end
                end
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            InData = InData(:);
            OutData = InData(obj.PermVec);
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            InData = InData(:);
            OutData = InData(obj.InvPermVec);
        end
    end
end
