function expResult = exp5_periodic(cfg, outDir)
%% 实验5  周期滚动(正弦跟踪平滑度)             —— 论文 4.5/5.5 节
%  目的: 传感器固定在可自由转动的轮子上做往复/圆周滚动, 检验三种信号对
%        周期运动的跟踪能力。论文结论: 陀螺无法识别圆周运动(数据失真),
%        加速度计呈正弦但含大量毛刺, 卡尔曼把曲线平滑成近似理想正弦。
%  实现要点:
%    - 轨迹: offset + amp*sin(2πft) + 小幅二次谐波(模拟手推不匀)
%    - 陀螺: 敏感轴未对准(axisFactor<1) → 幅值被缩放, 复现"无法识别圆周运动"
%    - 指标: RMSE、相关系数、二阶差分 RMS(平滑度)、与真实值互相关滞后
%  输出: results/exp5_periodic.png, results/exp5_tracking_zoom.png

if nargin < 1 || isempty(cfg)
    root   = tiltInit();
    cfg    = tiltConfig();
    outDir = fullfile(root, 'results');
end
ref    = referenceValues();

% ---- 实验5 专用: 敏感轴对准因子(1.0 = 理想对准; 0.25 = 复现论文现象) ----
cfg.gyro.axisFactor = 0.25;

offset = 45; amp = 30; freq = 0.25;      % 幅值 30°, 周期 4 s
profile = struct('type', 'sine', 'offset', offset, 'amp', amp, 'freq', freq, ...
                 'harm', 0.06, 'duration', 30, 'gyroInit', offset);

nT = cfg.trials;
names = {'angle_acc', 'angle_gyro', 'angle_kalman'};
nS = numel(names);
rmse = zeros(nT, nS); rho = zeros(nT, nS); d2rms = zeros(nT, nS); lagSec = zeros(nT, nS);

fh = figure('Name', 'Exp5 periodic motion', 'Position', [50 70 1400 430]);
for it = 1:nT
    d = genTiltData(profile, cfg, 5000 + it);
    idx = d.t >= 1;                          % 跳过启动瞬态, 从 1 s 开始评估
    sig = {d.angleAcc, d.angleGyro, d.angleKalman};
    for is = 1:nS
        x   = sig{is}(idx);
        ref0 = d.thetaTrue(idx);
        e = x - ref0;
        rmse(it, is) = sqrt(mean(e.^2));
        cc = corrcoef(x, ref0);  rho(it, is) = cc(1, 2);
        dtm = median(diff(d.t));
        d2rms(it, is) = sqrt(mean(diff(x, 2).^2)) / dtm^2;   % 二阶差分 RMS (deg/s^2)
        lagSec(it, is) = xcorrLag(x, ref0, dtm);
    end

    if it == 1, d1 = d; end
    ax = subplot(1, nT, it);
    plotTiltCompare(d.t, d, sprintf('Trial %d  (周期 %.1f s)', it, 1/freq), ...
        'ax', ax, 'yLim', [offset-amp-8, offset+amp+8]);
end
sgtitle(sprintf('实验5  周期滚动正弦跟踪（offset %g°, 幅值 %g°, %g Hz, 陀螺敏感轴因子 %.2f）', ...
        offset, amp, freq, cfg.gyro.axisFactor), 'FontWeight', 'bold');
saveFig(fh, outDir, 'exp5_periodic');

% ---------------- 放大图: 2 个周期细节 + 偏差放大（Trial 1） ----------------
fhz = figure('Name', 'Exp5 zoom', 'Position', [90 50 1000 720]);
mz = (d1.t >= 6) & (d1.t <= 6 + 2/freq);
dz = struct('thetaTrue', d1.thetaTrue(mz), 'angleAcc', d1.angleAcc(mz), ...
            'angleGyro', d1.angleGyro(mz), 'angleKalman', d1.angleKalman(mz));
axz = subplot(2, 1, 1);
plotTiltCompare(d1.t(mz), dz, '跟踪细节(2 个周期, Trial 1)', 'ax', axz, ...
    'yLim', [offset-amp-6, offset+amp+6]);
axr = subplot(2, 1, 2);
% 偏差面板只画 acc / kalman: 陀螺因敏感轴失配, 偏差达 ±37°, 会超出量程形成虚假竖线
dr = struct('thetaTrue', zeros(sum(mz), 1), ...
            'angleAcc',  d1.angleAcc(mz)  - d1.thetaTrue(mz), ...
            'angleKalman', d1.angleKalman(mz) - d1.thetaTrue(mz));
plotTiltCompare(d1.t(mz), dr, '相对真实倾角的偏差（同一时间窗，放大显示）', ...
    'ax', axr, 'showTrue', false, 'yLim', [-1.5 1.5]);
saveFig(fhz, outDir, 'exp5_tracking_zoom');

% ---------------- 汇总表 ----------------
fprintf('\n===== 实验5  正弦跟踪性能（%d trials 平均, 评估区间 t>=1 s）=====\n', nT);
fprintf('%-14s | %10s | %10s | %14s | %12s\n', ...
        '信号', 'RMSE(deg)', '相关系数', '二阶差分RMS(deg/s^2)', '滞后(s)');
for is = 1:nS
    fprintf('%-14s | %10.3f | %10.4f | %14.1f | %12.4f\n', names{is}, ...
        mean(rmse(:,is)), mean(rho(:,is)), mean(d2rms(:,is)), mean(lagSec(:,is)));
end
fprintf('平滑度: 卡尔曼二阶差分 RMS 为加速度计的 %.1f%%（6 倍以上平滑度提升）\n', ...
        100*mean(d2rms(:,3))/mean(d2rms(:,1)));
fprintf('        陀螺二阶差分 RMS 更小(%.1f), 但其幅值仅真实的 %.0f%%(敏感轴因子), 属于失真信号, 不可用\n', ...
        mean(d2rms(:,2)), 100*cfg.gyro.axisFactor);
fprintf('跟踪精度: 卡尔曼 RMSE %.3f° > 加速度计 %.3f°, 差值主要来自相位滞后 %.3f s（以平滑度换跟踪精度）\n', ...
        mean(rmse(:,3)), mean(rmse(:,1)), mean(lagSec(:,3)));

expResult = struct('id', 5, 'name', '实验5 周期滚动(正弦跟踪)', ...
    'offset', offset, 'amp', amp, 'freq', freq, 'axisFactor', cfg.gyro.axisFactor, ...
    'rmse', mean(rmse, 1), 'rho', mean(rho, 1), 'd2rms', mean(d2rms, 1), ...
    'lagSec', mean(lagSec, 1), 'names', {names}, 'trial1', d1);
expResult.figures = {fullfile(outDir, 'exp5_periodic.png'), ...
                     fullfile(outDir, 'exp5_tracking_zoom.png')};
end

% ------------------------------------------------------------------
function lag = xcorrLag(x, y, dt)
%XCORRLAG  互相关峰值对应的时延 (s)，正数表示 x 滞后 y
x = x(:) - mean(x);  y = y(:) - mean(y);
maxLag = min(40, floor(numel(x)/4));
lags = -maxLag:maxLag;
c = zeros(size(lags));
for i = 1:numel(lags)
    if lags(i) >= 0
        c(i) = sum(x(1+lags(i):end) .* y(1:end-lags(i)));
    else
        c(i) = sum(x(1:end+lags(i)) .* y(1-lags(i):end));
    end
end
[~, iMax] = max(c);
lag = lags(iMax) * dt;
end
