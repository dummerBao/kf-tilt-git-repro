function s = robustStats(x)
%ROBUSTSTATS  标准差统计（按论文方法剔除初始收敛离群点）
%
%   s = ROBUSTSTATS(x)
%
%   论文 5.1.2 节脚注:
%     "Because of a noticeable adjustment period of the Kalman algorithm that
%      generates significant outliers, the standard deviation is calculated
%      using the data points that are not considered an outlier by the
%      standard statistics methodology, where an outlier is considered as a
%      point that is less than Q1-1.5(IQR) or more than Q3+1.5(IQR)."
%
%   即: 先算 Q1/Q3/IQR，剔除 [Q1-1.5IQR, Q3+1.5IQR] 之外的样本，再求标准差。
%
%   输出
%     .std      剔除离群点后的标准差（论文口径，deg）
%     .stdRaw   未剔除的标准差（deg，用于对照）
%     .mean     剔除后均值 (deg)
%     .n .nOut  总样本数 / 被剔除数
%     .outFrac  剔除比例
%     .lo .hi   剔除上下限

x = x(:);
x = x(~isnan(x));
q1  = localPercentile(x, 25);
q3  = localPercentile(x, 75);
iqr = q3 - q1;
lo  = q1 - 1.5*iqr;
hi  = q3 + 1.5*iqr;
mask = (x >= lo) & (x <= hi);

s = struct('std', std(x(mask)), 'stdRaw', std(x), 'mean', mean(x(mask)), ...
           'n', numel(x), 'nOut', sum(~mask), 'outFrac', sum(~mask)/numel(x), ...
           'lo', lo, 'hi', hi, 'q1', q1, 'q3', q3, 'iqr', iqr);
end

% ------------------------------------------------------------------
function p = localPercentile(x, pct)
%LOCALPERCENTILE  线性插值百分位数（不依赖 Statistics Toolbox）
x = sort(x(:));
n = numel(x);
if n == 1, p = x(1); return; end
pos = (pct/100) * (n - 1) + 1;      % 1-based 位置
f   = floor(pos);
c   = min(f + 1, n);
p   = x(f) + (pos - f) * (x(c) - x(f));
end
