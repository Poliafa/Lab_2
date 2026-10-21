function Report = CompareWithDVBs2(TxBBData, TxSignal, Params)
% Сравнение комплексной огибающей модели с dvbs2WaveformGenerator.
% Для команды 4: 8PSK 3/4, normal FECFRAME, pilots ON, beta=0.35,
% span=10 symbols, 4 samples/symbol.
%
% TxBBData должен быть тем же BBFRAME, который сформировал человек 1,
% включая BBHEADER. Для GS/UPL=0 MATLAB использует DFL=48128 бит.

    TxBBData = logical(TxBBData(:));
    % В модели BBFrame содержит 80-битный BBHEADER + DATA FIELD.
    % Эталонный GS-генератор получает именно DATA FIELD.
    DFL = Params.BBFrame.DFL;
    if numel(TxBBData) < 80 + DFL
        error('TxBBData короче, чем BBHEADER + DFL.');
    end
    TxBBData = TxBBData(81:80+DFL);
    TxSignal = TxSignal(:);

    wg = dvbs2WaveformGenerator;
    wg.FECFrame = 'normal';
    wg.MODCOD = 14;                 % 8PSK 3/4
    wg.HasPilots = true;
    wg.RolloffFactor = 0.35;
    wg.FilterSpanInSymbols = 10;
    wg.SamplesPerSymbol = 4;
    wg.StreamFormat = 'GS';
    wg.UPL = 0;

    RefSignal = wg(TxBBData);
    RefSignal = RefSignal(:);

    % Сравниваем перекрывающуюся часть после удаления возможной задержки.
    N = min(numel(TxSignal), numel(RefSignal));
    a = TxSignal(1:N);
    b = RefSignal(1:N);

    % Нормированное комплексное выравнивание по фазе/амплитуде для оценки
    % формы огибающей без влияния общего комплексного множителя.
    alpha = (b' * a) / (b' * b + eps);
    bAligned = alpha * b;
    e = a - bAligned;

    Report.N = N;
    Report.MaxAbsError = max(abs(e));
    Report.RMSE = sqrt(mean(abs(e).^2));
    Report.RelativeRMSE = Report.RMSE / (sqrt(mean(abs(a).^2)) + eps);
    Report.Correlation = abs(a' * b) / ...
        (sqrt((a' * a) * (b' * b)) + eps);

    fprintf('\n=== DVB-S2: сравнение человека 4 с эталоном ===\n');
    fprintf('MODCOD: 14 (8PSK 3/4)\n');
    fprintf('Pilots: ON, beta=0.35, span=10T, sps=4\n');
    fprintf('Сравнено отсчётов: %d\n', Report.N);
    fprintf('Max |error|       = %.6g\n', Report.MaxAbsError);
    fprintf('RMSE              = %.6g\n', Report.RMSE);
    fprintf('Relative RMSE     = %.6g\n', Report.RelativeRMSE);
    fprintf('Correlation       = %.12f\n', Report.Correlation);

    figure;
    plot(real(a)); hold on; plot(real(bAligned)); grid on;
    legend('Модель','Эталон');
    title('Re\{s(t)\}: модель и dvbs2WaveformGenerator');
    xlabel('Отсчёт'); ylabel('Амплитуда');

    figure;
    plot(imag(a)); hold on; plot(imag(bAligned)); grid on;
    legend('Модель','Эталон');
    title('Im\{s(t)\}: модель и dvbs2WaveformGenerator');
    xlabel('Отсчёт'); ylabel('Амплитуда');

    figure;
    plot(abs(e)); grid on;
    title('|s_{model}(t)-s_{ref}(t)|');
    xlabel('Отсчёт'); ylabel('Абсолютная ошибка');
end
