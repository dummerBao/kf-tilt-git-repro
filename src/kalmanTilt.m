function kf = kalmanTilt(t, omegaMeas, thetaAcc, cfg, opts)
%KALMANTILT  简化单状态标量卡尔曼滤波器（向量批处理封装）
%
%   kf = KALMANTILT(t, omegaMeas, thetaAcc, cfg)
%   kf = KALMANTILT(t, omegaMeas, thetaAcc, cfg, opts)
%
%   内部逐拍调用 kalmanTiltStep.m，与单片机实时实现完全一致。
%
%   输入
%     t         : 时间戳序列 (s)（含抖动，dt 由相邻时间戳动态计算）
%     omegaMeas : 陀螺仪角速度 (deg/s)
%     thetaAcc  : 加速度计解算角度 (deg)
%     cfg       : tiltConfig()
%     opts      : 可选
%        .biasHat  预先给定的零偏 (deg/s)；给定时跳过启动标定
%        .theta0   覆盖初始状态 (deg)
%   输出 kf
%     .theta    融合角度 (deg)
%     .thetaPred预测值 theta^- (deg)
%     .K        卡尔曼增益序列
%     .P        后验协方差序列 (deg^2)
%     .biasHat  零偏估计序列 (deg/s)
%     .biasFinal最终零偏估计 (deg/s)

if nargin < 5, opts = struct(); end
t         = t(:);
omegaMeas = omegaMeas(:);
thetaAcc  = thetaAcc(:);
N = numel(t);
assert(numel(omegaMeas) == N && numel(thetaAcc) == N, ...
       'kalmanTilt:sizeMismatch', '输入序列长度不一致');

theta0 = cfg.kalman.theta0;
if isfield(opts, 'theta0') && ~isempty(opts.theta0)
    theta0 = opts.theta0;
end

% ---- 状态初始化 ----
st = struct('theta', theta0, 'P', cfg.kalman.R, 'biasHat', 0, ...
            'calSum', 0, 'nCal', 0, 'thetaPred', theta0, 'K', NaN);
if isfield(opts, 'biasHat') && ~isempty(opts.biasHat)
    st.biasHat = opts.biasHat;
    st.nCal    = cfg.gyro.calSamples;      % 视为已标定完毕
end

theta     = zeros(N, 1);
thetaPred = zeros(N, 1);
Kgain     = nan(N, 1);
Pv        = zeros(N, 1);
biasSeq   = zeros(N, 1);

theta(1) = st.theta; thetaPred(1) = st.theta; Pv(1) = st.P; biasSeq(1) = st.biasHat;

for k = 2:N
    dt = t(k) - t(k-1);                    % dt 动态计算（论文 3.5 节）
    st = kalmanTiltStep(st, omegaMeas(k), thetaAcc(k), dt, cfg);
    theta(k)     = st.theta;
    thetaPred(k) = st.thetaPred;
    Kgain(k)     = st.K;
    Pv(k)        = st.P;
    biasSeq(k)   = st.biasHat;
end

kf = struct('theta', theta, 'thetaPred', thetaPred, 'K', Kgain, ...
            'P', Pv, 'biasHat', biasSeq, 'biasFinal', st.biasHat, ...
            'Kss', configSteadyGain(cfg));
end

% ------------------------------------------------------------------
function Kss = configSteadyGain(cfg)
%CONFIGSTEADYGAIN  由 cfg 解析求稳态卡尔曼增益（仅用于结果对照）
q = cfg.kalman.Q * cfg.dtNominal;      % 每步过程噪声方差
r = cfg.kalman.R;
x = (-q + sqrt(q^2 + 4*q*r)) / 2;      % 稳态后验协方差
Kss = (x + q) / (x + q + r);
end
