function ref = referenceValues()
%REFERENCEVALUES  论文报告的标准差参考值（用于对照表）
%
%   来源: arXiv:2609.00730v2
%     5.1.2 节 实验1(静止短时, 3 trials 平均):
%       angle_acc 0.192° , angle_gyro 0.136° , angle_kalman 0.075°
%     5.2.2 节 实验2(静止长时 120 s, 3 trials 平均):
%       angle_acc 0.172° , angle_gyro 0.217° , angle_kalman 0.063°
%
%   输出 ref: 结构体，字段含义见下

ref = struct();

% --- 实验1: 静止短时 ---
ref.exp1.name    = '实验1 静止短时(30 s)噪声对比';
ref.exp1.stdAcc  = 0.192;
ref.exp1.stdGyro = 0.136;
ref.exp1.stdKal  = 0.075;

% --- 实验2: 静止长时 ---
ref.exp2.name    = '实验2 静止长时(120 s)漂移对比';
ref.exp2.stdAcc  = 0.172;
ref.exp2.stdGyro = 0.217;
ref.exp2.stdKal  = 0.063;

% --- 实验3/4/5 论文只给出定性结论，阈值仅用于报告 ---
ref.exp3.angles    = [0 30 45 60];      % 标定角 (deg)
ref.exp3.note      = '论文: 偏差随倾角增大而增大(过度标定), gyro 不参与对比';
ref.exp4.levels    = [0 30 45 60];      % 阶跃目标 (deg)
ref.exp4.note      = '论文: 每次突跳后 Kalman 需要时间恢复, 随后平滑稳定';
ref.exp5.note      = '论文: 陀螺无法识别圆周运动; Kalman 把含噪正弦平滑为近似理想正弦';
end
