function root = tiltInit()
%TILTINIT  初始化工程路径与绘图风格，返回工程根目录
%
%   在 runAll.m 或单个实验脚本开头调用:
%       root = tiltInit();
%
%   作用:
%     1) 把 config/ src/ experiments/ 加入 MATLAB 搜索路径
%     2) 设置统一绘图风格（中文字体、白底、网格）
%     3) 返回工程根目录，便于拼接 results/ 输出路径

here = fileparts(mfilename('fullpath'));
root = here;
if isempty(here)                       % 直接运行脚本时的兜底
    root = pwd;
end
addpath(fullfile(root, 'config'), fullfile(root, 'src'), ...
        fullfile(root, 'experiments'), fullfile(root, 'tools'), '-begin');
if ~exist(fullfile(root, 'results'), 'dir')
    mkdir(fullfile(root, 'results'));
end
tiltPlotDefaults();
end
