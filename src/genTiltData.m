function data = genTiltData(profile, cfg, seed)
%GENTILTDATA  生成真实倾角轨迹、模拟 MPU6050 原始量测，并解算三种角度
%
%   data = GENTILTDATA(profile, cfg, seed)
%
%   输入
%     profile : 轨迹定义（结构体）
%        .type      : 'static' | 'steps' | 'sine'
%        .duration  : 时长 (s)
%        --- static ---
%        .angle     : 固定倾角 (deg)
%        --- steps ---
%        .levels    : 目标角度序列 (deg)，例 [0 30 45 60]
%        .holdTime  : 每级保持时间 (s)
%        .transTime : 相邻级之间的过渡时间 (s)（论文实验4 用 3D 打印支架，
%                     过渡近似瞬时，取 0.05 s 即 5 个采样点）
%        --- sine ---
%        .offset .amp .freq : 倾角 = offset + amp*sin(2*pi*freq*t) (deg, Hz)
%        .harm      : 二次谐波比例（模拟手推不匀）
%        --- 通用 ---
%        .gyroInit  : 陀螺积分初值 (deg)，默认 0（论文式2 从 0 开始积分）
%     cfg    : tiltConfig() 返回的配置
%     seed   : 随机种子（保证可复现）
%
%   输出 data（结构体，字段均为列向量）
%     .t           时间戳 (s)，含 dt 抖动
%     .dt          逐步时间间隔 (s)
%     .thetaTrue   真实倾角 (deg)
%     .omegaTrue   真实角速度 (deg/s)
%     .ay .az      模拟加速度计读数 (g)
%     .omegaRaw    模拟陀螺仪读数 (deg/s，含零偏/漂移/噪声)
%     .angleAcc    加速度计解算角度 atan2(ay,az)  (deg)   —— 式(1)
%     .angleGyro   陀螺积分角度（零偏标定后）      (deg)   —— 式(2)
%     .angleKalman 卡尔曼融合角度                  (deg)   —— 式(3)(4)
%     .biasHat     启动阶段标定出的陀螺零偏估计 (deg/s)
%     .biasTrue    该次仿真的真实零偏序列 (deg/s)，用于分析
%
%   依赖: evalTiltProfile.m, gyroBiasCalibration.m, kalmanTilt.m

if nargin < 3 || isempty(seed), seed = 1; end
rng(seed, 'twister');

% ---------- 1. 时间轴（含抖动，供滤波器动态计算 dt） ----------
N = round(profile.duration * cfg.fs);
jitter = 1 + cfg.dtJitterStd * randn(N, 1);
jitter = max(jitter, 0.2);                     % 防止出现非正的时间步
dt = cfg.dtNominal * jitter;
dt = dt * (profile.duration / sum(dt));        % 归一化，保证总时长准确
t  = [0; cumsum(dt(1:end-1))];

% ---------- 2. 真实轨迹与真实角速度 ----------
thetaTrue = evalTiltProfile(profile, t);
omegaTrue = gradient(thetaTrue, t);            % 数值微分，阶跃处自动给脉冲

% ---------- 3. 加速度计模拟 ----------
g = 1.0;                                       % 归一化重力 (g)
th = deg2rad(thetaTrue);
ay = (1 + cfg.acc.scaleMismatch) * g * sin(th) + cfg.acc.biasG(1) ...
     + cfg.acc.noiseStdG * randn(N, 1);
az = g * cos(th) + cfg.acc.biasG(2) + cfg.acc.noiseStdG * randn(N, 1);

% ---------- 4. 陀螺仪模拟 ----------
biasTrue = cfg.gyro.bias0 * ones(N, 1);
nDrift = numel(cfg.gyro.driftAmp);
phase  = cfg.gyro.driftPhase;
if isempty(phase) || numel(phase) ~= nDrift
    phase = 2*pi*rand(1, nDrift);              % 每个 trial 随机相位
end
% 启动零偏标定会减掉"标定窗口内的平均角速度"。因此漂移频率取
% 1/tCal 的整数倍（tCal≈2 s -> 0.5 Hz 的整数倍），使每个漂移分量在标定
% 窗口内的均值严格为 0，避免残留常值被积分为不真实的长时间线性漂移。
% 物理含义: 低成本的 MEMS 陀螺零偏不稳定度(1/f 噪声 + 振动整流)表现为
% 0.5~2.5 Hz 的有界角速度游走，积分后为有界的角度摆动。
for j = 1:nDrift
    biasTrue = biasTrue + cfg.gyro.driftAmp(j) * ...
               sin(2*pi*cfg.gyro.driftFreq(j)*t + phase(j));
end
omegaRaw = cfg.gyro.axisFactor * omegaTrue + biasTrue ...
           + cfg.gyro.noiseStd * randn(N, 1);

% ---------- 5. 三种角度解算 ----------
% (1) 加速度计角度: theta_acc = atan(ay/az)  —— 论文式(1)
%     用 atan2 保证四象限正确；在单轴 ±90° 范围内与 arctan(ay/az) 完全等价
angleAcc = atan2d(ay, az);

% (2) 陀螺仪角度: 先标定零偏，再积分 —— 论文式(2)
biasHat = gyroBiasCalibration(omegaRaw, cfg.gyro.calSamples);
if isfield(profile, 'gyroInit') && ~isempty(profile.gyroInit)
    gInit = profile.gyroInit;
else
    gInit = 0;
end
wCal = omegaRaw - biasHat;                     % 标定后角速度
angleGyro = zeros(N, 1);
angleGyro(1) = gInit;
for k = 2:N
    angleGyro(k) = angleGyro(k-1) + wCal(k) * (t(k) - t(k-1));   % 式(2)
end

% (3) 卡尔曼融合 —— 论文式(3)(4)
kf = kalmanTilt(t, omegaRaw, angleAcc, cfg);
angleKalman = kf.theta;

% ---------- 6. 打包 ----------
data = struct('t', t, 'dt', [dt(1); diff(t)], 'thetaTrue', thetaTrue, ...
              'omegaTrue', omegaTrue, 'ay', ay, 'az', az, ...
              'omegaRaw', omegaRaw, 'biasTrue', biasTrue, ...
              'angleAcc', angleAcc, 'angleGyro', angleGyro, ...
              'angleKalman', angleKalman, 'biasHat', biasHat, ...
              'kalmanInfo', kf, 'seed', seed, 'profile', profile);
end
