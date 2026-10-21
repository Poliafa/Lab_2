classdef ClassEncoder < handle
    properties (SetAccess = private)
        isTransparent;
        Rate;
        N_ldpc;
        MaxNumIterations;
        LogLanguage;
    end
    properties (SetAccess = private)
        K_bch;
        N_bch;
        t;
        K_ldpc;
        FullRate;
        isSoftInput;
        BCHEncoder;
        BCHDecoder;
        LDPCEncoderCfg;
        LDPCDecoderCfg;
    end
    methods
        function obj = ClassEncoder(Params, LogLanguage)
            Encoder = Params.Encoder;
            Mapper  = Params.Mapper;
            obj.isTransparent     = Encoder.isTransparent;
            obj.Rate              = Encoder.Rate;
            obj.N_ldpc            = Encoder.N_ldpc;
            obj.MaxNumIterations  = Encoder.MaxNumIterations;
            obj.LogLanguage       = LogLanguage;

            if obj.isTransparent
                obj.isSoftInput = false;
                obj.FullRate    = 1;
                return
            end

            if obj.N_ldpc ~= 64800
                error('Only normal FECFRAME (64800 bits) is supported.');
            end
            obj.N_ldpc = 64800;
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
                    error('Invalid value of Encoder.Rate for n_ldpc = 64800.');
            end
            obj.K_ldpc = obj.N_bch;
            obj.FullRate = obj.K_bch / obj.N_ldpc;

            obj.isSoftInput = ~strcmp(Mapper.DecisionMethod, 'Hard decision');

            obj.BCHEncoder = comm.BCHEncoder(obj.N_bch, obj.K_bch);
            obj.BCHDecoder = comm.BCHDecoder(obj.N_bch, obj.K_bch);

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
            BCHData = obj.BCHEncoder.step(double(InData));
            OutData = ldpcEncode(BCHData, obj.LDPCEncoderCfg);
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            InData = InData(:);
            if obj.isSoftInput
                LLR = -double(InData);
            else
                LLR = 20 * (2 * double(InData) - 1);
            end
            LDPCData = ldpcDecode(LLR, obj.LDPCDecoderCfg, ...
                obj.MaxNumIterations, 'DecisionType', 'hard');
            LDPCData = double(LDPCData(:));
            LDPCData = 1 - LDPCData;
            OutData = obj.BCHDecoder.step(double(LDPCData(:)));
            OutData = double(OutData(:));
        end
    end
end
