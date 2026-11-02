function fontName = tiltPlotDefaults()
%TILTPLOTDEFAULTS  统一绘图风格（支持中文标签，白底、网格、加粗线宽）
%
%   在每个实验脚本开头调用一次即可。返回实际使用的中文字体名。

avail = listfonts;
cands = {'Microsoft YaHei', 'Microsoft YaHei UI', 'SimHei', 'SimSun', 'Arial Unicode MS'};
fontName = 'Helvetica';
for i = 1:numel(cands)
    if any(strcmpi(avail, cands{i}))
        fontName = cands{i};
        break;
    end
end

set(0, 'defaultAxesFontName', fontName);
set(0, 'defaultTextFontName', fontName);
set(0, 'defaultLegendFontName', fontName);
set(0, 'defaultAxesFontSize', 10);
set(0, 'defaultAxesGridLineStyle', ':');
set(0, 'defaultAxesXGrid', 'on');
set(0, 'defaultAxesYGrid', 'on');
set(0, 'defaultAxesBox', 'on');
set(0, 'defaultAxesLineWidth', 0.8);
set(0, 'defaultLineLineWidth', 1.2);
set(0, 'defaultFigureColor', 'w');
set(0, 'defaultFigurePosition', [80 80 1100 620]);
end
