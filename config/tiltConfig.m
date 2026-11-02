function cfg = tiltConfig()
%TILTCONFIG  倾角估计仿真参数配置（论文复现）
%
%   对应论文:
%     "Design and Implementation of a Kalman Filter-Infused Algorithm for
%      Tilt Estimation", arXiv:2609.00730v2
%
%   用途:
%     集中管理"数据生成 -> 滤波器 -> 实验"全链路的可调参数。
%     所有实验脚本都从本函数取参数，修改此处即可全局生效。
%
%   单位约定:
%     角度 deg | 加速度 g | 角速度 deg/s | 时间 s
%
%   用法:
%     cfg = tiltConfig();                 % 默认参数（已按论文结果标定）
%     cfg.acc.noiseStdG = 0.005;          % 按需覆盖单个字段
%     cfg.kalman.Q      = 0.6;            % 例如加大过程噪声
%
%   标定说明:
%     acc.noiseStdG / gyro.noiseStd / gyro.driftAmp 三个参数由
%     tools/calibrateGyroModel.m 自动标定，目标是让实验1、实验2 的
%     三个信号标准差逼近论文报告值（见 src/referenceValues.m）。

%% ---------- 采样: 100 Hz, dt 动态计算 ----------
cfg.fs          = 100;              % 采样率 100 Hz（论文 2.1 节）
cfg.dtNominal   = 1/cfg.fs;         % 名义采样间隔 10 ms
cfg.dtJitterStd = 0.02;             % dt 相对抖动(标准差)，模拟定时抖动
                                    % 滤波器内部用 dt = t(k)-t(k-1) 动态计算
cfg.trials      = 3;                % 每组实验重复 3 次（论文每实验 3 trials）

%% ---------- 加速度计模型 ----------
% 0.00323 g ≈ 0.19 deg  → 对应论文实验1/2 的 angle_acc 标准差（论文两个
% 实验报 0.192/0.172，同一噪声水平下取值不同，此处匹配其均值 0.182）
cfg.acc.noiseStdG     = 0.00323;    % 单轴白噪声 (g)
cfg.acc.biasG         = [0.0014; -0.0093];  % [ay; az] 常值零偏 (g)
                                    % az 的 -9.3 mg 零偏使 theta_acc 误差 ≈ -bz*sin(theta)
                                    % 随倾角单调增大(0°→0.08°, 30°→0.34°, 45°→0.44°,
                                    % 60°→0.50°)，复现论文实验3 的观察
cfg.acc.scaleMismatch = 0.0;        % ay 相对 az 的刻度误差(保留为可调项)

%% ---------- 陀螺仪模型 ----------
% 角速度误差 = 标定残差(常值) + 低频漂移(有界正弦叠加) + 白噪声
cfg.gyro.noiseStd   = 0.1670;       % 白噪声 (deg/s)，积分后为随机游走，方差 ∝ T
cfg.gyro.bias0      = 0.35;         % 初始常值零偏 (deg/s)，启动阶段标定掉
cfg.gyro.calSamples = 200;          % 零偏标定样本数（2 s @100 Hz）
cfg.gyro.driftAmp   = [0.2433 0.7298 1.2163];  % 零偏游走幅度 (deg/s)
cfg.gyro.driftFreq  = [0.500 1.500 2.500];  % 零偏游走频率 (Hz)
                                    % 必须取 1/(calSamples*dt) = 0.5 Hz 的整数倍，
                                    % 使各分量在标定窗口内均值=0（否则残余常值会被
                                    % 积分为不真实的长时间线性漂移）。
                                    % 幅值/频率 等比例设置 -> 积分后各分量角度幅值
                                    % 相同(≈0.032 deg)，形成有界的角度摆动。
                                    % 备注: 该高频游走对卡尔曼输出影响很小——滤波器被
                                    % 加速度计锚定，速率误差只产生 ~0.03*b 的偏移。
cfg.gyro.driftPhase = [];           % [] = 每个 trial 随机相位
cfg.gyro.axisFactor = 1.0;          % 敏感轴对准因子（实验5 用 0.25 复现论文
                                    % 中"陀螺无法识别圆周运动"的现象）

%% ---------- 卡尔曼滤波参数（式3/式4） ----------
% 稳态增益 K = P-/(P-+R)，取 Q/R(每步) = 1/12 时 K = 0.25
% 此时滤波输出标准差 ≈ sqrt(K/(2-K)) * std(theta_acc) ≈ 0.378*0.192 = 0.073 deg
% 与论文实验1(0.075)/实验2(0.063) 吻合
cfg.kalman.R      = 0.0369;         % 量测噪声方差 deg^2 (theta_acc std 0.192 deg)
cfg.kalman.Q      = 0.3075;         % 过程噪声方差密度 deg^2/s
                                    % = (R/12) * fs = 0.003075 * 100
cfg.kalman.theta0 = 0;              % 初始状态 (deg)，对应式(2)(3) 从 0 开始积分
                                    % 这会在启动段产生论文所述的"调整期离群点"

end
