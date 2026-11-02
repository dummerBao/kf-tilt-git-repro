function T = stdCompareTable(vals, ref)
%STDCOMPARETABLE  生成"仿真结果 vs 论文参考值"的对照表（结构体数组）
%
%   T = STDCOMPARETABLE(vals, ref)
%     vals : [std_acc, std_gyro, std_kalman]  本次仿真得到的标准差 (deg)
%     ref  : referenceValues().exp1 / .exp2
%
%   返回结构体数组，字段:
%     .signal    信号名
%     .measured  仿真值 (deg)
%     .paper     论文值 (deg)
%     .absDiff   绝对偏差 (deg)
%     .relPct    相对偏差 (%)

names  = {'angle_{acc}', 'angle_{gyro}', 'angle_{kalman}'};
paper  = [ref.stdAcc, ref.stdGyro, ref.stdKal];
vals   = vals(:).';
T = struct('signal', {}, 'measured', {}, 'paper', {}, 'absDiff', {}, 'relPct', {});
for i = 1:numel(names)
    T(i).signal   = names{i};
    T(i).measured = vals(i);
    T(i).paper    = paper(i);
    T(i).absDiff  = vals(i) - paper(i);
    T(i).relPct   = 100 * (vals(i) - paper(i)) / paper(i);
end
end
