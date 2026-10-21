classdef ClassStat < handle
    properties (SetAccess = private)
        % Параметры, используемые для накопления статистики
            NumTrBits;   % количество переданных бит
            NumTrFrames; % количество переданных кадров
            NumErBits;   % количество ошибочных  бит
            NumErFrames; % количество ошибочных  кадров
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    methods
        function obj = ClassStat(LogLanguage) % Конструктор
            obj.NumTrBits   = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits   = 0;
            obj.NumErFrames = 0;
            obj.LogLanguage = LogLanguage;
        end
        function Step(obj, Frame)
            % Проверка: длины должны совпадать
            if numel(Frame.TxData) ~= numel(Frame.RxData)
                fprintf('!!! ДЛИНЫ НЕ СОВПАДАЮТ: TxData=%d, RxData=%d\n', ...
                    numel(Frame.TxData), numel(Frame.RxData));
                return;   % не считаем этот кадр
            end

            obj.NumTrBits   = obj.NumTrBits   + numel(Frame.TxData);
            obj.NumTrFrames = obj.NumTrFrames + 1;
            Buf = sum(Frame.TxData ~= Frame.RxData);
            obj.NumErBits   = obj.NumErBits   + Buf;
            obj.NumErFrames = obj.NumErFrames + sign(Buf);
        end
        function Reset(obj)
            obj.NumTrBits   = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits   = 0;
            obj.NumErFrames = 0;
        end
    end
end
