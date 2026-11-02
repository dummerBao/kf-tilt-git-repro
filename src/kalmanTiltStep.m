function st = kalmanTiltStep(st, omegaMeas, thetaAcc, dt, cfg)
%KALMANTILTSTEP  单状态标量卡尔曼滤波器 —— 单步更新（面向单片机实时运行）
%
%   st = KALMANTILTSTEP(st, omegaMeas, thetaAcc, dt, cfg)
%
%   本函数是滤波器唯一的实现实体，kalmanTilt.m 只是对它做循环调用，
%   因此"仿真结果"与"单片机逐拍运行"在数值上完全一致。
%   无矩阵运算、无动态内存，仅 4 个标量状态，适合 MCU 中断/主循环内执行。
%
%   对应论文公式:
%     预测: theta_k^- = theta_{k-1}^- + omega*dt                    ... 式(3)
%     更新: theta_k   = theta_k^- + K*(theta_acc - theta_k^-)       ... 式(4)
%           K = P^- / (P^- + R),  P^- = P + Q*dt,  P = (1-K)*P^-
%
%   输入
%     st        : 滤波器状态（首次调用前用 kalmanInit.m 初始化）
%       .theta      上一拍融合角度 (deg)
%       .P          上一拍后验协方差 (deg^2)
%       .biasHat    当前陀螺零偏估计 (deg/s)
%       .calSum/.nCal  启动标定累加器
%     omegaMeas : 当前陀螺角速度读数 (deg/s)
%     thetaAcc  : 当前加速度计角度 (deg)
%     dt        : 与上一拍的实际时间间隔 (s) —— 动态计算
%     cfg       : tiltConfig()
%   输出
%     st        : 更新后的状态（附加 thetaPred / K 便于分析）

% ---- 启动阶段: 累积样本估计陀螺零偏（论文 2.4 节 传感器标定） ----
calN = cfg.gyro.calSamples;
if st.nCal < calN
    st.nCal   = st.nCal + 1;
    st.calSum = st.calSum + omegaMeas;
    st.biasHat = st.calSum / st.nCal;
end

% ---- 预测步 (式3): 陀螺角速度前向积分 ----
thetaPred = st.theta + (omegaMeas - st.biasHat) * dt;
st.P      = st.P + cfg.kalman.Q * dt;

% ---- 更新步 (式4): 加速度计角度作为量测修正 ----
K        = st.P / (st.P + cfg.kalman.R);      % 卡尔曼增益（由协方差动态求得）
st.theta = thetaPred + K * (thetaAcc - thetaPred);
st.P     = (1 - K) * st.P;

% ---- 便于分析的中间量 ----
st.thetaPred = thetaPred;
st.K         = K;
end
