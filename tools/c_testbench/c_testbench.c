/* ============================================================================
 * c_testbench.c —— MATLAB 对照测试程序（验证 C 实现与仿真逐样本一致）
 *
 * 用法:  c_testbench <testvector.csv> <meta.txt> [对比输出.csv]
 *   testvector.csv : t,omegaMeas,thetaAcc,thetaMatlab （由 export_c_testvector.m 导出）
 *   meta.txt       : R / Q / calSamples / n / biasHat / P0
 *   对比输出.csv   : t,theta_c,theta_matlab,abs_err （可选）
 *
 * 滤波器核心: src/mcu/kalman_tilt.c（与嵌入式同源，未做任何修改）
 * 流程与 MATLAB 导出脚本完全对齐:
 *   1) 启动标定期(calSamples 拍)在线累积陀螺均值 -> biasHat
 *   2) 每拍 dt = t(k) - t(k-1)（动态时间步，首拍 dt = t(0)）
 *   3) 预测 -> 更新，输出 theta
 * 统计: 全程最大绝对误差 / RMS 误差 / 末拍误差
 * ==========================================================================*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ---- 嵌入式同源滤波器（直接包含，确保被测代码就是移植目标本身） ---- */
#include "../../src/mcu/kalman_tilt.c"

#define MAXN 65536

typedef struct {
    double t, omega, acc, matlab;
} Sample;

static Sample g_s[MAXN];
static int g_n = 0;

/* ---- 读取 meta.txt ---- */
typedef struct {
    double R, Q, P0;
    int calSamples, n;
} Meta;

static int read_meta(const char *path, Meta *m)
{
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char line[128];
    while (fgets(line, sizeof line, f)) {
        if      (strncmp(line, "R=", 2) == 0)           m->R = atof(line + 2);
        else if (strncmp(line, "Q=", 2) == 0)           m->Q = atof(line + 2);
        else if (strncmp(line, "calSamples=", 11) == 0) m->calSamples = atoi(line + 11);
        else if (strncmp(line, "n=", 2) == 0)           m->n = atoi(line + 2);
        else if (strncmp(line, "P0=", 3) == 0)          m->P0 = atof(line + 3);
    }
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "用法: %s <testvector.csv> <meta.txt> [对比输出.csv]\n", argv[0]);
        return 1;
    }

    Meta meta = {0};
    if (read_meta(argv[2], &meta) != 0) { fprintf(stderr, "读 meta 失败\n"); return 1; }

    /* ---- 读测试向量 ---- */
    FILE *f = fopen(argv[1], "r");
    if (!f) { fprintf(stderr, "读 csv 失败\n"); return 1; }
    char line[256];
    fgets(line, sizeof line, f);                    /* 表头 */
    while (fgets(line, sizeof line, f) && g_n < MAXN) {
        Sample *s = &g_s[g_n];
        if (sscanf(line, "%lf,%lf,%lf,%lf", &s->t, &s->omega, &s->acc, &s->matlab) == 4)
            g_n++;
    }
    fclose(f);
    if (g_n != meta.n)
        fprintf(stderr, "警告: csv 行数 %d != meta.n %d，以实际行为准\n", g_n, meta.n);

    /* ---- 初始化滤波器（与 MATLAB kalmanInit 对齐: P0 = R） ---- */
    kalman_tilt_t kf;
    kalman_tilt_init(&kf, (float)meta.R, (float)meta.Q, meta.calSamples);
    kf.P = (float)meta.P0;

    /* ---- 逐拍运行 ---- */
    const char *outPath = (argc > 3) ? argv[3] : NULL;
    FILE *fo = outPath ? fopen(outPath, "w") : NULL;
    if (fo) fprintf(fo, "t,theta_c,theta_matlab,abs_err\n");

    double maxErr = 0.0, sumSq = 0.0;
    double prevT = 0.0;
    for (int k = 0; k < g_n; k++) {
        double dt = (k == 0) ? g_s[k].t : (g_s[k].t - prevT);
        prevT = g_s[k].t;
        float theta = kalman_tilt_update(&kf, (float)g_s[k].omega,
                                              (float)g_s[k].acc, (float)dt);
        double err = fabs((double)theta - g_s[k].matlab);
        if (err > maxErr) maxErr = err;
        sumSq += err * err;
        if (fo) fprintf(fo, "%.9f,%.9f,%.9f,%.9f\n",
                        g_s[k].t, (double)theta, g_s[k].matlab, err);
    }
    if (fo) fclose(fo);

    double rms = sqrt(sumSq / g_n);
    printf("C vs MATLAB 逐样本对比 (n=%d)\n", g_n);
    printf("  最大绝对误差 : %.3e deg\n", maxErr);
    printf("  RMS 误差     : %.3e deg\n", rms);
    printf("  末拍 C=%.9f / MATLAB=%.9f\n", (double)kf.theta, g_s[g_n-1].matlab);
    printf("结论: %s\n", maxErr < 1e-4 ? "PASS (逐样本一致, 误差在 float 精度内)"
                                             : "FAIL (误差超出 float 预期)");
    return (maxErr < 1e-4) ? 0 : 2;
}
