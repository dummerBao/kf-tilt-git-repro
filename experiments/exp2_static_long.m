function expResult = exp2_static_long(cfg, outDir)
%% 实验2  静止长时(120 s)漂移对比               —— 论文 4.2/5.2 节
%  目的: 观察长时间静止下陀螺积分的累积漂移, 验证卡尔曼滤波对漂移的抑制。
%        论文要点: 长时下陀螺标准差首次超过加速度计 (0.217° > 0.172°)。
%  输出: results/exp2_static_long.png  +  控制台对照表

if nargin < 1 || isempty(cfg)
    root   = tiltInit();
    cfg    = tiltConfig();
    outDir = fullfile(root, 'results');
end
ref    = referenceValues();

profile = struct('type', 'static', 'angle', 0, 'duration', 120, 'gyroInit', 0);

nT = cfg.trials;
stdA = zeros(1, nT); stdG = zeros(1, nT); stdK = zeros(1, nT);
stdAraw = zeros(1, nT); stdGraw = zeros(1, nT); stdKraw = zeros(1, nT);
gyroEndErr = zeros(1, nT);      % 陀螺末尾偏差(deg), 用于量化漂移
outFracK = zeros(1, nT);

fh = figure('Name', 'Exp2 static long-term', 'Position', [60 80 1400 430]);
for it = 1:nT
    d = genTiltData(profile, cfg, 2000 + it);
    sA = robustStats(d.angleAcc);
    sG = robustStats(d.angleGyro);
    sK = robustStats(d.angleKalman);
    stdA(it) = sA.std; stdG(it) = sG.std; stdK(it) = sK.std;
    stdAraw(it) = sA.stdRaw; stdGraw(it) = sG.stdRaw; stdKraw(it) = sK.stdRaw;
    gyroEndErr(it) = mean(d.angleGyro(end-49:end)) - mean(d.thetaTrue(end-49:end));
    outFracK(it) = sK.outFrac;

    ax = subplot(1, nT, it);
    ymax = 1.25 * max(abs([d.angleAcc; d.angleGyro; d.angleKalman]));
    ymax = max(ymax, 0.5);
    txt = sprintf('std: acc=%.3f°  gyro=%.3f°  Kal=%.3f°', sA.std, sG.std, sK.std);
    plotTiltCompare(d.t, d, sprintf('Trial %d', it), ...
        'ax', ax, 'statText', txt, 'yLim', [-ymax ymax]);
end
sgtitle(sprintf('实验2  静止长时(%.0f s) 三信号漂移对比  —— 100 Hz, %d trials', ...
        profile.duration, nT), 'FontWeight', 'bold');
saveFig(fh, outDir, 'exp2_static_long');

% ---------------- 对照表 ----------------
vals = [mean(stdA), mean(stdG), mean(stdK)];
T = stdCompareTable(vals, ref.exp2);

fprintf('\n===== 实验2  静止长时(120 s) 标准差对照表 =====\n');
fprintf('%-16s %10s %10s %10s %10s\n', '信号', '仿真(deg)', '论文(deg)', '偏差(deg)', '相对偏差');
for i = 1:numel(T)
    fprintf('%-16s %10.3f %10.3f %+10.3f %9.1f%%\n', ...
        T(i).signal, T(i).measured, T(i).paper, T(i).absDiff, T(i).relPct);
end
fprintf(['注: 陀螺末尾(最后 0.5 s)平均偏差 = %+.3f deg (漂移量)；' ...
         '卡尔曼离群点占比 %.2f%%\n'], mean(gyroEndErr), 100*mean(outFracK));
fprintf('    陀螺长时 std (%.3f) %s 加速度计 (%.3f) —— %s\n', ...
        mean(stdG), ternary(mean(stdG) > mean(stdA), '>', '<='), mean(stdA), ...
        ternary(mean(stdG) > mean(stdA), '复现了论文"长时陀螺劣于加速度计"的结论', ...
                '未复现该结论, 需调大 gyro.noiseStd / driftAmp'));

expResult = struct('id', 2, 'name', ref.exp2.name, ...
    'duration', profile.duration, 'vals', vals, 'table', T, ...
    'stdPerTrial', struct('acc', stdA, 'gyro', stdG, 'kalman', stdK), ...
    'gyroEndErr', mean(gyroEndErr), 'outFracKalman', mean(outFracK), ...
    'figure', fullfile(outDir, 'exp2_static_long.png'));
end

% ------------------------------------------------------------------
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
