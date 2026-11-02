function export_c_testvector()
%EXPORT_C_TESTVECTOR  导出实验1 trial1 的滤波器输入/输出, 供 C 实现逐样本对照
%  输出: results/c_testvector.csv  (t, omegaMeas, thetaAcc, thetaMatlab)
%        results/c_testvector_meta.txt (初始状态与参数)

root = tiltInit();
cfg  = tiltConfig();

% 与 exp1_static_short 完全一致的轨迹与随机种子 (trial 1)
profile = struct('type', 'static', 'angle', 0, 'duration', 30, 'gyroInit', 0);
d = genTiltData(profile, cfg, 1001);   % 与 exp1_static_short trial 1 相同种子

% 用与仿真完全相同的启动标定: 先取前 calSamples 个陀螺样本求均值
biasHat = mean(d.omegaRaw(1:cfg.gyro.calSamples));

% 逐拍复现 kalmanTilt 的调用方式 (dt 动态 = 实际时间戳差)
% 滤波器状态内联初始化 (theta=0, P=R, 零偏由启动标定期在线估计)
st = struct('theta', 0, 'P', cfg.kalman.R, 'biasHat', 0, ...
            'calSum', 0, 'nCal', 0);
n = numel(d.t);
thetaOut = zeros(n,1);
for k = 1:n
    if k == 1
        dt = d.t(1) - 0;            % 第一拍 dt 用首时间戳
    else
        dt = d.t(k) - d.t(k-1);
    end
    st = kalmanTiltStep(st, d.omegaRaw(k), d.angleAcc(k), dt, cfg);
    thetaOut(k) = st.theta;
end

% 导出 CSV (跳过启动标定期, 与论文口径一致; 但 C 从第 1 拍开始, 故全量导出)
fid = fopen(fullfile(root,'results','c_testvector.csv'), 'w');
fprintf(fid, 't,omegaMeas,thetaAcc,thetaMatlab\n');
for k = 1:n
    fprintf(fid, '%.9f,%.9f,%.9f,%.9f\n', d.t(k), d.omegaRaw(k), d.angleAcc(k), thetaOut(k));
end
fclose(fid);

% 导出参数元数据
mid = fullfile(root,'results','c_testvector_meta.txt');
fid = fopen(mid, 'w');
fprintf(fid, 'R=%.10f\n', cfg.kalman.R);
fprintf(fid, 'Q=%.10f\n', cfg.kalman.Q);
fprintf(fid, 'calSamples=%d\n', cfg.gyro.calSamples);
fprintf(fid, 'n=%d\n', n);
fprintf(fid, 'biasHat=%.10f\n', biasHat);
fprintf(fid, 'P0=%.10f\n', cfg.kalman.R);   % kalmanInit 中 P 初值 = R
fclose(fid);

fprintf('导出完成: %d 样本, biasHat=%.6f, 末拍 theta=%.6f\n', n, biasHat, thetaOut(end));
end
