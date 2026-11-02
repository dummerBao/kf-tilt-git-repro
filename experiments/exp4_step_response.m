function expResult = exp4_step_response(cfg, outDir)
%% 实验4  阶跃响应(0->30->45->60°)             —— 论文 4.4/5.4 节
%  目的: 用 3D 打印角度支架做近似瞬时换级, 观察三种信号的收敛速度、超调与
%        平台段噪声。论文结论: 每次突跳后卡尔曼需要一段恢复时间, 之后平滑稳定。
%  量化指标: 收敛时间(进入 ±tol 并保持 0.5 s)、90% 上升时间、平台段标准差。
%  输出: results/exp4_step_response.png, results/exp4_step_zoom.png

if nargin < 1 || isempty(cfg)
    root   = tiltInit();
    cfg    = tiltConfig();
    outDir = fullfile(root, 'results');
end
ref    = referenceValues();

levels    = ref.exp4.levels;      % [0 30 45 60]
holdTime  = 8;                    % 每级保持 (s)
transTime = 0.05;                 % 过渡时间 (s) —— 支架换级近似瞬时
duration  = holdTime + (numel(levels)-1)*(holdTime + transTime) + 1;

profile = struct('type', 'steps', 'levels', levels, 'holdTime', holdTime, ...
                 'transTime', transTime, 'duration', duration, 'gyroInit', 0);

% 各级过渡时刻与目标值
tStep = zeros(1, numel(levels)-1);
tgt   = levels(2:end);
for i = 2:numel(levels)
    tStep(i-1) = holdTime + (i-2)*(holdTime + transTime);
end
holdDur = holdTime * ones(size(tStep));
tolList = [0.5, 1.0, 2.0];        % 收敛判据: ±0.5° / ±1° / ±2°
holdSec = 0.3;                    % 进入判据带后需连续保持的时间 (s)

nT  = cfg.trials;
names = {'angle_acc', 'angle_gyro', 'angle_kalman'};
nS = numel(names);
settleT  = nan(nT, numel(tStep), nS, numel(tolList));
riseT    = nan(nT, numel(tStep), nS);
platStd  = nan(nT, numel(tStep), nS);
overshoot = nan(nT, numel(tStep), nS);

fh = figure('Name', 'Exp4 step response', 'Position', [50 70 1400 430]);
for it = 1:nT
    d = genTiltData(profile, cfg, 4000 + it);
    sig = {d.angleAcc, d.angleGyro, d.angleKalman};

    for is = 1:nS
        for k = 1:numel(tStep)
            t0 = tStep(k); t1 = min(t0 + holdDur(k), d.t(end));
            mAll = (d.t >= t0) & (d.t <= t1);
            x = sig{is}(mAll); tt = d.t(mAll);
            mPlat = (tt >= t1 - 2);                     % 平台末 2 s
            xRef  = mean(x(mPlat));                     % 以平台均值为参考,
                                                        % 隔离零偏造成的稳态偏差,
                                                        % 只反映动态收敛过程
            for il = 1:numel(tolList)
                st = settleTime(tt, x, xRef, tolList(il), holdSec);
                settleT(it, k, is, il) = st;
            end
            riseT(it, k, is) = riseTime(tt, x, levels(k), tgt(k));
            platStd(it, k, is) = std(x(mPlat) - tgt(k));   % 平台段仍在理想值上评估
            % 超调量（相对阶跃幅度）
            span = tgt(k) - levels(k);
            if span ~= 0
                if span > 0, overshoot(it,k,is) = max(0, max(x) - tgt(k)) / span * 100;
                else,        overshoot(it,k,is) = max(0, tgt(k) - min(x)) / abs(span) * 100;
                end
            end
        end
    end

    if it == 1, d1 = d; end
    ax = subplot(1, nT, it);
    plotTiltCompare(d.t, d, sprintf('Trial %d', it), ...
        'ax', ax, 'yLim', [min(levels)-3, max(levels)+3]);
end
sgtitle(sprintf('实验4  阶跃响应 0\\rightarrow30\\rightarrow45\\rightarrow60° （%d trials, 每级保持 %g s）', ...
        nT, holdTime), 'FontWeight', 'bold');
saveFig(fh, outDir, 'exp4_step_response');

% ---------------- 放大图: 0->30° 过渡细节（Trial 1） ----------------
kz = 1; t0z = tStep(kz);
fhz = figure('Name', 'Exp4 step zoom', 'Position', [90 90 1000 480]);
axz = axes();
mz = (d1.t >= t0z - 0.2) & (d1.t <= t0z + 1.2);
dz = struct('thetaTrue', d1.thetaTrue(mz), 'angleAcc', d1.angleAcc(mz), ...
            'angleGyro', d1.angleGyro(mz), 'angleKalman', d1.angleKalman(mz));
plotTiltCompare(d1.t(mz), dz, sprintf('阶跃细节: %g°\\rightarrow%g°（Trial 1）', ...
    levels(1), tgt(1)), 'ax', axz, 'yLim', [levels(1)-2, tgt(1)+5]);
% 标出卡尔曼 ±1° 收敛带与收敛时刻（HandleVisibility=off 避免进入图例）
hold(axz, 'on');
yline(axz, tgt(1) + 1, ':', 'Color', [0.85 0.33 0.10 0.7], 'HandleVisibility', 'off');
yline(axz, tgt(1) - 1, ':', 'Color', [0.85 0.33 0.10 0.7], 'HandleVisibility', 'off');
stK = settleT(1, kz, 3, 2);        % ±1° 判据
if ~isnan(stK)
    xline(axz, t0z + stK, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.4, ...
          'HandleVisibility', 'off');
    text(axz, t0z + stK + 0.02, tgt(1) + 3.0, ...
         sprintf('Kalman 收敛 +%.2f s (\\pm1°)', stK), ...
         'Color', [0.85 0.33 0.10], 'FontSize', 9, 'FontWeight', 'bold');
end
hold(axz, 'off');
saveFig(fhz, outDir, 'exp4_step_zoom');

% ---------------- 汇总表 ----------------
fprintf('\n===== 实验4  阶跃响应收敛时间（%d trials × %d 次阶跃 平均, 保持 %.1f s 判据）=====\n', ...
        nT, numel(tStep), holdSec);
fprintf('%-14s | %13s %13s %13s | %12s | %12s | %10s\n', ...
        '信号', '收敛±0.5°(s)', '收敛±1°(s)', '收敛±2°(s)', '90%上升(s)', '平台段std', '超调(%)');
for is = 1:nS
    fprintf('%-14s | %13.3f %13.3f %13.3f | %12.3f | %12.3f | %10.2f\n', names{is}, ...
        mean(settleT(:,:,is,1), 'all', 'omitnan'), ...
        mean(settleT(:,:,is,2), 'all', 'omitnan'), ...
        mean(settleT(:,:,is,3), 'all', 'omitnan'), ...
        mean(riseT(:,:,is), 'all', 'omitnan'), ...
        mean(platStd(:,:,is), 'all', 'omitnan'), ...
        mean(overshoot(:,:,is), 'all', 'omitnan'));
end
fprintf('每级收敛时间(±1°)明细 [行=trial, 列=阶跃]:  Kalman\n');
disp(arrayfun(@(x) sprintf('%6.3f', x), settleT(:,:,3,2), 'UniformOutput', false));
fprintf('注: 收敛判据以各级平台段均值(末 2 s)为参考, 用于隔离零偏造成的稳态偏差, 只反映动态收敛过程\n');
fprintf('平台段 std: acc %.3f / gyro %.3f / Kal %.3f deg  —— 卡尔曼噪声最小\n', ...
        mean(platStd(:,:,1),'all','omitnan'), mean(platStd(:,:,2),'all','omitnan'), ...
        mean(platStd(:,:,3),'all','omitnan'));

expResult = struct('id', 4, 'name', '实验4 阶跃响应(0->30->45->60)', ...
    'levels', levels, 'tStep', tStep, 'tolList', tolList, 'holdSec', holdSec, ...
    'settleT', settleT, 'riseT', riseT, 'platStd', platStd, ...
    'overshoot', overshoot, ...
    'settleAll', squeeze(mean(settleT, 1, 'omitnan')), ...   % nStep × nS × nTol
    'rise', squeeze(mean(riseT, 1, 'omitnan')), ...          % nStep × nS
    'platStdMean', squeeze(mean(platStd, 1, 'omitnan')), ... % nStep × nS
    'trial1', d1);
expResult.figures = {fullfile(outDir, 'exp4_step_response.png'), ...
                     fullfile(outDir, 'exp4_step_zoom.png')};
end

% ------------------------------------------------------------------
function ts = settleTime(tt, x, target, tol, holdSec)
%SETTLETIME 首次进入 ±tol 带并保持 holdSec 的时刻（相对 tt(1)），单位 s
ts = NaN;
nHold = max(1, round(holdSec / median(diff(tt))));
inBand = abs(x - target) <= tol;
n = numel(x);
for k = 1:n
    k2 = min(k + nHold, n);
    if all(inBand(k:k2))
        ts = tt(k) - tt(1);
        return;
    end
end
end

function tr = riseTime(tt, x, x0, x1)
%RISETIME 从 x0 到 x1 的 10%->90% 上升时间 (s)
tr = NaN;
if x1 == x0, return; end
lo = x0 + 0.1*(x1 - x0);
hi = x0 + 0.9*(x1 - x0);
if x1 > x0
    iLo = find(x >= lo, 1, 'first'); iHi = find(x >= hi, 1, 'first');
else
    iLo = find(x <= lo, 1, 'first'); iHi = find(x <= hi, 1, 'first');
end
if ~isempty(iLo) && ~isempty(iHi) && iHi >= iLo
    tr = tt(iHi) - tt(iLo);
end
end
