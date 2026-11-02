function expResult = exp3_fixed_angles(cfg, outDir)
%% 实验3  固定角度(0/30/45/60°)精度对比        —— 论文 4.3/5.3 节
%  目的: 在数字角度尺给定的固定倾角上, 比较 angle_acc 与 angle_kalman 的
%        测量精度(均值)与偏差随角度的变化趋势。
%  论文结论复现点:
%    1) 陀螺仪不参与对比 —— 实验时传感器被"抬到"倾斜姿态而未绕敏感轴旋转,
%       陀螺积分角≈0, 无法反映倾角(本脚本中 gyroInit=0 即此物理含义);
%    2) 卡尔曼数据随角度增大偏差更大 —— 源于加速度计刻度误差被融合继承。
%  输出: results/exp3_fixed_angles.png, results/exp3_accuracy.png

if nargin < 1 || isempty(cfg)
    root   = tiltInit();
    cfg    = tiltConfig();
    outDir = fullfile(root, 'results');
end
ref    = referenceValues();

angles = ref.exp3.angles;      % [0 30 45 60]
nA = numel(angles);
nT = cfg.trials;
Tseg = 10;                     % 每个角度记录 10 s（论文 5.3.2 节）
avgWin = 5;                    % 取末 5 s 求均值（已过收敛期）

measAcc = zeros(nT, nA);  measKal = zeros(nT, nA);  measGyro = zeros(nT, nA);
stdAccT = zeros(nT, nA);  stdKalT = zeros(nT, nA);

fh = figure('Name', 'Exp3 fixed angles', 'Position', [40 60 1500 700]);
for ia = 1:nA
    ang = angles(ia);
    profile = struct('type', 'static', 'angle', ang, 'duration', Tseg, 'gyroInit', 0);
    d0 = [];
    for it = 1:nT
        d = genTiltData(profile, cfg, 3000 + 100*ia + it);
        if it == 1, d0 = d; end                    % 绘图用 trial 1
        idx = d.t >= (Tseg - avgWin);
        sA = robustStats(d.angleAcc(idx));  sK = robustStats(d.angleKalman(idx));
        measAcc(it, ia) = sA.mean;  stdAccT(it, ia) = sA.std;
        measKal(it, ia) = sK.mean;  stdKalT(it, ia) = sK.std;
        measGyro(it, ia) = mean(d.angleGyro(idx));
    end

    % --- 上排: 三种信号时间曲线（纵轴围绕理想角 ±1.5°） ---
    ax1 = subplot(2, nA, ia);
    plotTiltCompare(d0.t, d0, sprintf('理想 %g°  (Trial 1)', ang), ...
        'ax', ax1, 'yLim', [ang-1.5, ang+1.5]);
    ylabel(ax1, '\theta (deg)');

    % --- 下排: 相对理想值的偏差（放大显示） ---
    dDev = struct('thetaTrue', zeros(size(d0.t)), ...
                  'angleAcc', d0.angleAcc - ang, ...
                  'angleGyro', d0.angleGyro - ang, ...
                  'angleKalman', d0.angleKalman - ang);
    ax2 = subplot(2, nA, nA + ia);
    plotTiltCompare(d0.t, dDev, sprintf('相对 %g° 的偏差', ang), ...
        'ax', ax2, 'showTrue', false, 'yLim', [-1.0 1.0]);
    ylabel(ax2, '偏差 (deg)');
end
angleList = strjoin(arrayfun(@(x) sprintf('%g', x), angles, 'UniformOutput', false), '/');
sgtitle(sprintf('实验3  固定倾角精度对比（%s°）—— 上: 实测曲线, 下: 相对理想值偏差', ...
        angleList), 'FontWeight', 'bold');
saveFig(fh, outDir, 'exp3_fixed_angles');

% ---------------- 精度汇总 ----------------
errAcc  = mean(measAcc)  - angles;
errKal  = mean(measKal)  - angles;
errGyro = mean(measGyro) - angles;

fprintf('\n===== 实验3  固定倾角精度对照表（3 trials 平均, 末 %d s 均值）=====\n', avgWin);
fprintf('%6s | %10s %9s | %10s %9s | %10s %9s\n', ...
        '理想角', 'acc均值', 'acc误差', 'Kal均值', 'Kal误差', 'gyro均值', 'gyro误差');
for ia = 1:nA
    fprintf('%5g° | %9.3f° %+8.3f° | %9.3f° %+8.3f° | %9.3f° %+8.3f°\n', ...
        angles(ia), mean(measAcc(:,ia)), errAcc(ia), ...
        mean(measKal(:,ia)), errKal(ia), mean(measGyro(:,ia)), errGyro(ia));
end
fprintf('acc 平均绝对误差 = %.3f°  |  Kalman 平均绝对误差 = %.3f°  |  gyro = %.3f°(不可用)\n', ...
        mean(abs(errAcc)), mean(abs(errKal)), mean(abs(errGyro)));
fprintf('偏差随角度单调性: acc %s, Kalman %s\n', monoStr(errAcc), monoStr(errKal));

% --- 图2: 均值-理想值 关系 & 误差-角度 趋势 ---
fh2 = figure('Name', 'Exp3 accuracy', 'Position', [80 80 1200 460]);
ax = subplot(1, 2, 1);
hold(ax, 'on');
plot(ax, [-5 65], [-5 65], 'k--', 'LineWidth', 1.0);
plot(ax, angles, mean(measAcc), 'o-', 'Color', [0.55 0.55 0.55], ...
     'MarkerFaceColor', [0.55 0.55 0.55], 'LineWidth', 1.6);
plot(ax, angles, mean(measKal), 's-', 'Color', [0.85 0.33 0.10], ...
     'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 2.0);
xlabel(ax, '理想倾角 (deg)'); ylabel(ax, '实测均值 (deg)');
title(ax, '实测均值 vs 理想倾角', 'FontWeight', 'bold');
legend(ax, {'理想 y=x', 'angle_{acc}', 'angle_{kalman}'}, 'Location', 'northwest');
grid(ax, 'on'); axis(ax, [-5 65 -5 65]); axis(ax, 'square');

ax = subplot(1, 2, 2);
b = bar(ax, angles, [errAcc(:), errKal(:), errGyro(:)]);
b(1).FaceColor = [0.55 0.55 0.55];
b(2).FaceColor = [0.85 0.33 0.10];
b(3).FaceColor = [0.00 0.45 0.74];
hold(ax, 'on'); yline(ax, 0, 'k-');
xlabel(ax, '理想倾角 (deg)'); ylabel(ax, '平均误差 (deg)');
title(ax, '平均误差 vs 理想倾角', 'FontWeight', 'bold');
legend(ax, {'angle_{acc}', 'angle_{kalman}', 'angle_{gyro}(不可用)'}, 'Location', 'best');
grid(ax, 'on');
saveFig(fh2, outDir, 'exp3_accuracy');

expResult = struct('id', 3, 'name', '实验3 固定角度精度对比', ...
    'angles', angles, 'measAcc', mean(measAcc,1), 'measKal', mean(measKal,1), ...
    'measGyro', mean(measGyro,1), 'errAcc', errAcc, 'errKal', errKal, ...
    'errGyro', errGyro, 'stdAcc', mean(stdAccT,1), 'stdKal', mean(stdKalT,1), ...
    'maeAcc', mean(abs(errAcc)), 'maeKal', mean(abs(errKal)), 'trial1', d0);
expResult.figures = {fullfile(outDir, 'exp3_fixed_angles.png'), ...
                     fullfile(outDir, 'exp3_accuracy.png')};
end

% ------------------------------------------------------------------
function s = monoStr(e)
% 判断偏差序列是否随角度单调增大
d = diff(e);
if all(d > 0),      s = '单调增大 (与论文一致)';
elseif all(d < 0),  s = '单调减小';
else,               s = '非单调';
end
end
