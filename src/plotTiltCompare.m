function ax = plotTiltCompare(t, d, ttl, varargin)
%PLOTTILTCOMPARE  绘制 angle_acc / angle_gyro / angle_kalman 三条曲线对比图
%
%   ax = PLOTTILTCOMPARE(t, d, ttl)
%   ax = PLOTTILTCOMPARE(t, d, ttl, 'Name', Value, ...)
%
%   输入
%     t    : 时间 (s)
%     d    : 结构体，可含字段 thetaTrue / angleAcc / angleGyro / angleKalman
%            （字段缺失或为 [] 时该曲线不绘制）
%     ttl  : 标题字符串
%     可选参数（名称-取值对）
%       'ax'       目标坐标轴句柄（默认新建图窗）
%       'showTrue' 是否绘制真实值，默认 true
%       'legend'   是否显示图例，默认 true
%       'yLim'     纵轴范围，默认自动
%       'xLabel' / 'yLabel'  轴标签
%       'statText' 轴内附加文本（如标准差）
%
%   配色: 加速度计=灰实线, 陀螺仪=蓝虚线, 卡尔曼=橙红粗实线, 真实值=黑点线

% ---------------- 可选参数解析 ----------------
opts = struct('ax', [], 'showTrue', true, 'legend', true, 'yLim', [], ...
              'xLabel', '', 'yLabel', '', 'statText', '');
if mod(numel(varargin), 2) ~= 0
    error('plotTiltCompare:oddArgs', '可选参数必须成对出现 (名称, 取值)');
end
for k = 1:2:numel(varargin)
    nm = varargin{k};
    if ~isfield(opts, nm)
        error('plotTiltCompare:badArg', '未知的可选参数: %s', nm);
    end
    opts.(nm) = varargin{k+1};
end

t = t(:);

% ---------------- 目标坐标轴 ----------------
if ~isempty(opts.ax)
    ax = opts.ax;                 % 后续绘图调用均显式传入句柄, 无需切换当前轴
else
    figure('Name', ttl);
    ax = axes();
end
hold(ax, 'on');

cAcc  = [0.55 0.55 0.55];
cGyro = [0.00 0.45 0.74];
cKal  = [0.85 0.33 0.10];
cTrue = [0.10 0.10 0.10];
h = gobjects(0); leg = {};

if opts.showTrue && isfield(d, 'thetaTrue') && ~isempty(d.thetaTrue)
    h(end+1) = plot(ax, t, d.thetaTrue, '--', 'Color', cTrue, 'LineWidth', 1.0); %#ok<AGROW>
    leg{end+1} = '真实倾角'; %#ok<AGROW>
end
if isfield(d, 'angleAcc') && ~isempty(d.angleAcc)
    h(end+1) = plot(ax, t, d.angleAcc, '-', 'Color', cAcc, 'LineWidth', 0.9); %#ok<AGROW>
    leg{end+1} = 'acc 加速度计'; %#ok<AGROW>
end
if isfield(d, 'angleGyro') && ~isempty(d.angleGyro)
    h(end+1) = plot(ax, t, d.angleGyro, '--', 'Color', cGyro, 'LineWidth', 1.1); %#ok<AGROW>
    leg{end+1} = 'gyro 陀螺仪积分'; %#ok<AGROW>
end
if isfield(d, 'angleKalman') && ~isempty(d.angleKalman)
    h(end+1) = plot(ax, t, d.angleKalman, '-', 'Color', cKal, 'LineWidth', 1.8); %#ok<AGROW>
    leg{end+1} = 'kalman 融合'; %#ok<AGROW>
end

if ~isempty(ttl), title(ax, ttl, 'FontWeight', 'bold'); end
xlabel(ax, '时间 t (s)'); ylabel(ax, '倾角 \theta (deg)');
if ~isempty(opts.xLabel), xlabel(ax, opts.xLabel); end
if ~isempty(opts.yLabel), ylabel(ax, opts.yLabel); end
if ~isempty(opts.yLim),   ylim(ax, opts.yLim); end
xlim(ax, [t(1), t(end)]);

if opts.legend && ~isempty(h)
    lg = legend(ax, h, leg, 'Location', 'southeast', 'FontSize', 8);
    lg.Box = 'on';
end

if ~isempty(opts.statText)
    xl = xlim(ax); yl = ylim(ax);
    text(ax, xl(1) + 0.02*diff(xl), yl(2) - 0.03*diff(yl), opts.statText, ...
         'FontSize', 8, 'Color', [0.15 0.15 0.15], 'BackgroundColor', [1 1 1 0.8], ...
         'VerticalAlignment', 'top', 'Interpreter', 'none');
end
hold(ax, 'off');
end
