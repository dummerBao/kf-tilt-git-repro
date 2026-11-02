function p = saveFig(fh, outDir, name)
%SAVEFIG  将图窗导出为 PNG（150 dpi），返回完整路径
%
%   p = SAVEFIG(fh, outDir, name)

if ~exist(outDir, 'dir'), mkdir(outDir); end
p = fullfile(outDir, [name '.png']);
exportgraphics(fh, p, 'Resolution', 150);
fprintf('  [图] %s\n', p);
end
