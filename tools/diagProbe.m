function diagProbe()
%DIAGPROBE  临时诊断: 检查 plotTiltCompare 的解析与可见性
tiltInit();
fprintf('which  : %s\n', which('plotTiltCompare'));
w = which('plotTiltCompare', '-all');
for k = 1:numel(w)
    fprintf('  all(%d): %s\n', k, w{k});
end
try
    fprintf('nargin : %d\n', nargin('plotTiltCompare'));
catch ME
    fprintf('nargin ERR: %s\n', ME.message);
end
fprintf('exist  : %d\n', exist('plotTiltCompare'));
d = dir(fullfile('src', 'plotTiltCompare.m'));
if isempty(d)
    fprintf('file NOT FOUND\n');
else
    fprintf('file   : %s (%d bytes)\n', d.folder, d.bytes);
end
% 直接试调用
try
    t = (0:0.01:1).';
    dd = struct('thetaTrue', zeros(size(t)), 'angleAcc', randn(size(t)), ...
                'angleGyro', randn(size(t)), 'angleKalman', randn(size(t)));
    fh = figure('Visible', 'off');
    ax = plotTiltCompare(t, dd, 'test', 'ax', axes(), 'yLim', [-3 3]);
    fprintf('call OK, ax=%s\n', class(ax));
    close(fh);
catch ME
    fprintf('call ERR: %s | %s\n', ME.identifier, ME.message);
    for k = 1:numel(ME.stack)
        fprintf('   frame %d: %s line %d\n', k, ME.stack(k).name, ME.stack(k).line);
    end
end
% axes 是否被遮蔽
wa = which('axes', '-all');
fprintf('which axes: %d 处\n', numel(wa));
for k = 1:min(3, numel(wa))
    fprintf('   %s\n', wa{k});
end
try
    axes(gca);
    fprintf('axes(gca) OK\n');
catch ME
    fprintf('axes(gca) ERR: %s | %s\n', ME.identifier, ME.message);
end
end
