function expResult = exp1_static_short(cfg, outDir)
%% 实验1  静止短时(30 s)噪声对比               —— 论文 4.1/5.1 节
%  目的: 评估加速度计(噪声大)、陀螺仪(平滑但有小漂移)与卡尔曼融合的
%        短期标准差, 验证融合后噪声显著下降。
%  输出: results/exp1_static_short.png  +  控制台对照表
%  说明: 本脚本不含 clear, 可直接被 runAll.m 调用（run 方式，共享工作区）

if nargin < 1 || isempty(cfg)
    root   = tiltInit();
    cfg    = tiltConfig();
    outDir = fullfile(root, 'results');
end
ref    = referenceValues();

% ---------------- 轨迹: 水平静止 30 s (传感器完全静止) ----------------
profile = struct('type', 'static', 'angle', 0, 'duration', 30, 'gyroInit', 0);

nT = cfg.trials;
stdA = zeros(1, nT); stdG = zeros(1, nT); stdK = zeros(1, nT);
stdAraw = zeros(1, nT); stdGraw = zeros(1, nT); stdKraw = zeros(1, nT);
outFracK = zeros(1, nT);

fh = figure('Name', 'Exp1 static short-term', 'Position', [60 80 1400 430]);
for it = 1:nT
    d = genTiltData(profile, cfg, 1000 + it);          % 3 个不同种子 trial
    sA = robustStats(d.angleAcc);
    sG = robustStats(d.angleGyro);
    sK = robustStats(d.angleKalman);
    stdA(it) = sA.std; stdG(it) = sG.std; stdK(it) = sK.std;
    stdAraw(it) = sA.stdRaw; stdGraw(it) = sG.stdRaw; stdKraw(it) = sK.stdRaw;
    outFracK(it) = sK.outFrac;

    ax = subplot(1, nT, it);
    txt = sprintf('std: acc=%.3f°  gyro=%.3f°  Kal=%.3f°', sA.std, sG.std, sK.std);
    plotTiltCompare(d.t, d, sprintf('Trial %d', it), ...
        'ax', ax, 'statText', txt, 'yLim', [-0.8 0.8]);
end
sgtitle(sprintf('实验1  静止短时(%.0f s) 三信号噪声对比  —— 100 Hz, %d trials', ...
        profile.duration, nT), 'FontWeight', 'bold');
saveFig(fh, outDir, 'exp1_static_short');

% ---------------- 统计数据（论文口径: 3 trials 平均 + IQR 剔除离群点） ----------------
vals = [mean(stdA), mean(stdG), mean(stdK)];
T = stdCompareTable(vals, ref.exp1);

fprintf('\n===== 实验1  静止短时(30 s) 标准差对照表 =====\n');
fprintf('%-16s %10s %10s %10s %10s\n', '信号', '仿真(deg)', '论文(deg)', '偏差(deg)', '相对偏差');
for i = 1:numel(T)
    fprintf('%-16s %10.3f %10.3f %+10.3f %9.1f%%\n', ...
        T(i).signal, T(i).measured, T(i).paper, T(i).absDiff, T(i).relPct);
end
fprintf(['注: 不剔除离群点时为 acc %.3f / gyro %.3f / Kal %.3f deg；' ...
         '卡尔曼启动段离群点占比 %.2f%%\n'], ...
         mean(stdAraw), mean(stdGraw), mean(stdKraw), 100*mean(outFracK));

expResult = struct('id', 1, 'name', ref.exp1.name, ...
    'duration', profile.duration, 'vals', vals, 'table', T, ...
    'stdPerTrial', struct('acc', stdA, 'gyro', stdG, 'kalman', stdK), ...
    'outFracKalman', mean(outFracK), ...
    'figure', fullfile(outDir, 'exp1_static_short.png'));
end
