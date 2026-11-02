function biasHat = gyroBiasCalibration(omegaRaw, calSamples)
%GYROBIASCALIBRATION  陀螺仪静态零偏标定
%
%   biasHat = GYROBIASCALIBRATION(omegaRaw, calSamples)
%
%   论文 2.4 节: "Basic sensor calibration is performed to reduce bias,
%   particularly for the gyroscope, which is critical for minimizing drift."
%
%   实现: 取启动阶段前 calSamples 个采样点的角速度均值作为零偏估计。
%   要求标定期间传感器静止（本仿真中各实验启动时均满足）。
%
%   输入
%     omegaRaw   : 陀螺仪原始角速度序列 (deg/s)
%     calSamples : 标定所用样本数（默认 200，即 100 Hz 下 2 s）
%   输出
%     biasHat    : 零偏估计 (deg/s)

if nargin < 2 || isempty(calSamples)
    calSamples = 200;
end
omegaRaw = omegaRaw(:);
n = min(calSamples, numel(omegaRaw));
biasHat = mean(omegaRaw(1:n));
end
