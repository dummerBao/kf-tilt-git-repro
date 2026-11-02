/* ============================================================================
 * kalman_tilt.c  —— 单状态标量卡尔曼滤波器（倾角估计）单片机实现
 *
 * 对应论文: "Design and Implementation of a Kalman Filter-Infused Algorithm
 *           for Tilt Estimation" (arXiv:2609.00730v2)  式(1)~(4)
 *
 * 与 MATLAB 仿真数值等价: 见 src/kalmanTiltStep.m
 *   预测: theta_k^- = theta_{k-1} + (omega - bias) * dt              ... 式(3)
 *   更新: theta_k   = theta_k^- + K * (theta_acc - theta_k^-)        ... 式(4)
 *         K = P^- / (P^- + R),  P^- = P + Q*dt,  P = (1-K)*P^-
 *
 * 特点（面向 MCU 实时运行）:
 *   - 只用 4 个 float 状态量, 无矩阵/无动态内存
 *   - 每拍运算量: 约 4 乘 + 4 加 + 1 除（100 Hz 下开销可忽略）
 *   - dt 由调用方按实际时间戳动态计算（论文 3.5 节）
 *   - 启动阶段自动完成陀螺零偏标定（论文 2.4 节）
 *
 * 使用（100 Hz）:
 *      kalman_tilt_t kf;
 *      kalman_tilt_init(&kf, 0.0369f, 0.3075f, 200);   // R, Q, 2 s 标定样本
 *      // 每 10 ms 一次：
 *      float theta = kalman_tilt_update(&kf, gyro_dps, acc_angle_deg, 0.01f);
 * ==========================================================================*/

#include <math.h>

#ifndef KALMAN_TILT_C
#define KALMAN_TILT_C

typedef struct {
    float theta;        /* 融合后倾角 (deg)          —— 滤波器输出        */
    float P;            /* 后验协方差 (deg^2)                              */
    float bias;         /* 陀螺零偏估计 (deg/s)                            */
    float cal_sum;      /* 启动标定累加器                                  */
    int   cal_n;        /* 启动标定已累积样本数                            */
    int   cal_need;     /* 启动标定所需样本数                              */
    float Q;            /* 过程噪声方差密度 (deg^2/s)                      */
    float R;            /* 量测噪声方差 (deg^2)                            */
    float theta_pred;   /* 上一拍预测值 (调试用)                           */
    float K;            /* 上一拍卡尔曼增益 (调试用)                       */
} kalman_tilt_t;

/* 初始化。
 *   R      = theta_acc 的噪声方差, 例 (0.192deg)^2 = 0.0369
 *   Q      = 过程噪声方差密度,     例 0.3075  (等价 Q/R 每步 = 1/12)
 *   cal_n  = 启动零偏标定样本数,   例 200 (100 Hz 下 2 s)
 * 返回: 无。theta0 默认 0（对应论文式(2)(3) 由 0 开始积分）。
 */
static inline void kalman_tilt_init(kalman_tilt_t *kf, float R, float Q, int cal_n)
{
    kf->theta      = 0.0f;
    kf->P          = R;
    kf->bias       = 0.0f;
    kf->cal_sum    = 0.0f;
    kf->cal_n      = 0;
    kf->cal_need   = cal_n;
    kf->Q          = Q;
    kf->R          = R;
    kf->theta_pred = 0.0f;
    kf->K          = 0.0f;
}

/* 加速度计角度: theta_acc = atan(ay / az)  —— 论文式(1)
 *   ay, az : 加速度计读数 (g)。用 atan2f 保证四象限正确,
 *            单轴 ±90° 内与 arctan(ay/az) 完全等价。
 */
static inline float kalman_tilt_acc_angle(float ay, float az)
{
    return atan2f(ay, az) * 57.29577951f;     /* rad -> deg */
}

/* 单步更新: 返回融合倾角 (deg)。
 *   gyro_dps : 陀螺仪角速度 (deg/s)
 *   acc_deg  : 加速度计角度 (deg), 由 kalman_tilt_acc_angle() 得到
 *   dt       : 距上一拍的实际时间间隔 (s) —— 动态计算
 */
static inline float kalman_tilt_update(kalman_tilt_t *kf, float gyro_dps,
                                       float acc_deg, float dt)
{
    float theta_pred, K;

    /* ---- 启动阶段: 累积零偏标定样本 (论文 2.4 节) ---- */
    if (kf->cal_n < kf->cal_need) {
        kf->cal_n++;
        kf->cal_sum += gyro_dps;
        kf->bias     = kf->cal_sum / (float)kf->cal_n;
    }

    /* ---- 预测 (式3): 陀螺角速度前向积分 ---- */
    theta_pred  = kf->theta + (gyro_dps - kf->bias) * dt;
    kf->P      += kf->Q * dt;

    /* ---- 更新 (式4): 加速度计角度修正, K 由协方差动态求得 ---- */
    K           = kf->P / (kf->P + kf->R);
    kf->theta   = theta_pred + K * (acc_deg - theta_pred);
    kf->P       = (1.0f - K) * kf->P;

    kf->theta_pred = theta_pred;
    kf->K          = K;
    return kf->theta;
}

#endif /* KALMAN_TILT_C */
