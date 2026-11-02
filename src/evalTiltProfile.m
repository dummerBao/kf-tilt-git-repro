function theta = evalTiltProfile(profile, t)
%EVALTILTPROFILE  按轨迹定义求取 t 时刻的真实倾角 (deg)
%
%   支持三种轨迹:
%     'static' : 恒定倾角
%     'steps'  : 阶梯（保持 -> 过渡 -> 保持 ...），用于阶跃响应实验
%     'sine'   : 正弦周期滚动，可选二次谐波
%
%   见 genTiltData.m 头部说明。

t = t(:);
switch lower(profile.type)
    case 'static'
        theta = profile.angle * ones(size(t));

    case 'steps'
        lv = profile.levels(:).';
        th = lv(1) * ones(size(t));
        cur = lv(1);
        tEdge = 0;                                  % 当前级保持结束时刻
        for i = 2:numel(lv)
            tSeg0 = tEdge + profile.holdTime;       % 过渡起点
            tSeg1 = tSeg0 + profile.transTime;      % 过渡终点
            m = (t >= tSeg0) & (t < tSeg1);
            th(m) = cur + (lv(i) - cur) * (t(m) - tSeg0) / profile.transTime;
            m2 = (t >= tSeg1);
            th(m2) = lv(i);
            cur = lv(i);
            tEdge = tSeg1;
        end
        theta = th;

    case 'sine'
        f = profile.freq;
        theta = profile.offset + profile.amp * sin(2*pi*f*t);
        if isfield(profile, 'harm') && ~isempty(profile.harm)
            theta = theta + profile.harm * profile.amp * sin(2*pi*2*f*t);
        end

    otherwise
        error('evalTiltProfile:badType', '未知轨迹类型: %s', profile.type);
end
end
