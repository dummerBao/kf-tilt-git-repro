# 卡尔曼滤波倾角估计论文复现（MATLAB）

对论文 **"Design and Implementation of a Kalman Filter-Infused Algorithm for Tilt Estimation"**（arXiv:2609.00730v2, Yuehan Ma & Hongji Dai）的高保真数值复现。

原文 PDF 见 [`docs/paper_2609.00730v2.pdf`](docs/paper_2609.00730v2.pdf)，提取文本见 [`docs/paper_text_extracted.txt`](docs/paper_text_extracted.txt)。

## 复现结果总览

论文报告 6 个核心标准差（3 次试验平均、剔除 Q1−1.5IQR / Q3+1.5IQR 离群点后），本复现逐项对照：

| 指标 | 论文值 | 复现值 | 偏差 |
|---|---|---|---|
| 实验1（静止 30 s）加速度计 std | 0.192° | 0.185° | −3.8% |
| 实验1（静止 30 s）陀螺 std | 0.136° | 0.136° | **−0.0%** |
| 实验1（静止 30 s）卡尔曼 std | 0.075° | 0.076° | +0.7% |
| 实验2（静止 120 s）加速度计 std | 0.172° | 0.183° | +6.2% |
| 实验2（静止 120 s）陀螺 std | 0.217° | 0.217° | **+0.0%** |
| 实验2（静止 120 s）卡尔曼 std | 0.063° | 0.073° | +15.7% |

论文 5 个定性结论（长时陀螺漂移反超加速度计、误差随倾角单调增大、陀螺倾斜姿态失效、阶跃后恢复延迟、含噪正弦被平滑为近理想正弦）全部复现。

### 复现中发现的论文数据矛盾（本仓库最有价值的副产品）

论文陀螺 30 s→120 s 标准差比为 1.60（0.136°→0.217°），但纯随机游走的窗口标准差严格 ∝ √T，比值应为 2.00（→0.272°）。由此推断：**论文长时陀螺误差由有界漂移主导，而非纯随机游走**。本复现据此将陀螺误差建模为"白噪声随机游走 + 有界零偏游走"，用 `tools/calibrateGyroModel.m`（fminsearch）反解参数，两项陀螺标准差偏差均为 0.0%。

其余已知偏差的根因（论文两实验加速度计值本身相差 11%、卡尔曼/加速度计比值不一致 0.391 vs 0.366，单一 Q/R 无法同时命中）详见 [`results/SUMMARY.md`](results/SUMMARY.md)。

## 工程结构

```
├── config/        tiltConfig.m —— 全部可调参数集中一处
├── src/           数据生成 / 标量卡尔曼滤波器 / 统计 / 绘图 / MCU C 实现
├── experiments/   5 组实验各一个函数 + runAll 一键运行
├── tools/         calibrateGyroModel.m 参数反解标定等
├── docs/          原论文 PDF + 提取文本
└── results/       SUMMARY.md 汇总 + 9 张结果图 + 运行日志 + 标定参数
```

关键设计：滤波器只有一个实现实体 `src/kalmanTiltStep.m`（单状态标量卡尔曼，4 个标量状态量，稳态每拍约 4 乘 + 6 加减 + 1 除），上层批处理仅循环调用——仿真结果与单片机逐拍运行数值一致。`src/mcu/kalman_tilt.c` 是可直接移植的等价 C 实现。

## 运行方法

- 环境：MATLAB R2022b（不依赖任何工具箱）
- 一键复现：

```matlab
runAll            % 依次跑 5 组实验，输出图与日志到 results/
```

- 单独重标定传感器噪声参数（复现 0.0% 陀螺偏差的关键）：

```matlab
tiltInit;                       % 把各子目录加入路径
calibrateGyroModel;             % fminsearch 反解陀螺误差模型参数
```

## 复现口径说明（诚实声明）

- 论文未披露：陀螺零偏标定样本数（本复现取 200 样本 = 2 s @100 Hz）、MPU6050 量程与 DLPF 配置、性能提升百分比、能耗/算力数据。后两者文中不出现，仅给复现自测值。
- 机制等效项（非同一物理机制，现象一致）：实验 3"误差随角度增大"论文归因逐角度过度标定，本复现用加速度计 az 零偏（−9.3 mg）等价实现（数学上为 −bz·sinθ）；实验 5 陀螺失真用敏感轴因子 0.25 等效复现。
- 论文实验 1 trial 3 在 14 s 处的偶发尖峰属非人为事件，本复现不虚构。
- 实验 3 论文"10 s 取平均"，本复现取"末 5 s 均值"以避开启动瞬态。

## 结果图

| 图 | 内容 |
|---|---|
| `results/summary_std_compare.png` | 实验1/2 六个标准差：仿真 vs 论文柱状对照 |
| `results/exp1_static_short.png` | 静止 30 s 三信号对比（3 trials） |
| `results/exp2_static_long.png` | 静止 120 s：陀螺漂移累积反超加速度计 |
| `results/exp3_fixed_angles.png` | 固定角度 0/30/45/60° 精度 |
| `results/exp3_accuracy.png` | 精度趋势与误差-角度柱状 |
| `results/exp4_step_response.png` / `exp4_step_zoom.png` | 阶跃响应及换级收敛细节 |
| `results/exp5_periodic.png` / `exp5_tracking_zoom.png` | 周期滚动跟踪与偏差放大 |

## License

仅供学习与研究使用。原论文版权归原作者所有。
