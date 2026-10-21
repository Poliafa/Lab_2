function [Objs, Ruler] = PrepareObjects(Params, ParamsNum, NumParams, LogLanguage)
% Инициализация объектов модели.

    Objs = cell(Params.Common.NumWorkers, 1);

    for k = 1:Params.Common.NumWorkers
        Objs{k}.Source       = ClassSource(Params, LogLanguage);
        Objs{k}.BBFrame      = ClassBBFrame(Params, LogLanguage);
        Objs{k}.Encoder      = ClassEncoder(Params, LogLanguage);
        Objs{k}.Interleaver  = ClassInterleaver(Params, LogLanguage);
        Objs{k}.Mapper       = ClassMapper(Params, LogLanguage);

        % Человек 4: PL scrambling выполняется после формирования PLFRAME
        % (человек 3) и до RRC-фильтрации.
        Objs{k}.PLScrambler  = ClassPLScrambler(Params, LogLanguage);
        Objs{k}.Sig           = ClassSig(Params, LogLanguage);

        Objs{k}.Channel       = ClassChannel(Params, Objs{k}, LogLanguage);
        Objs{k}.Stat          = ClassStat(LogLanguage);
    end

    Ruler = ClassBERRuler(Params, ParamsNum, NumParams, LogLanguage);
end
