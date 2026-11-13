# O4 Kubernetes HPA：测量前预测

2026-11-13T14:00:00+08:00（正式测量前写入，不随后续结果回改）

## 问题

用 Kubernetes 的 HPA（Horizontal Pod Autoscaler）重做实验 3 的 B2（反应式伸缩，CPU 信号），与原生 scaler 的 `runs/b2-cpu` 对照：HPA 的决策、扩容延迟、缺口、实例·分钟与原生 scaler 有何异同？

## 已有依据（来自 B2 与 scaler 源码）

1. **B2 基线（原生 scaler，CPU 信号）。** `runs/b2-cpu`：到达曲线 `34@120s,34~340@30s,340@300s,340~34@60s,34@120s`（630 秒），scaler 参数 `min=2 max=4 target=0.7 sync=15s down-window=300s`，信号 `avg(rate(cgroup_cpu_usage_seconds_total{job="instances"}[15s])) / ${quota}`。结果：缺口 110 秒、错误 21243、实例·分钟 36.7；爬升至新实例就绪 116.4 秒（指标+决策 32s + 拉镜像 21s + 启动预热健康检查 63s）。
2. **单实例容量。** `runs/b0-refine`：25% CPU 配额下单实例上限约 122 请求/秒，容量线 `0.7×122=85.4` 请求/秒；峰值 340 请求/秒需 `ceil(340/85.4)=4` 实例。
3. **scaler 的算法就是 HPA 算法。** `cmd/scaler/main.go` 的 `desiredReplicas`：`期望 = ⌈当前 × 信号 ÷ 目标⌉`，容差 0.1，扩容上限 `max(2×当前, 当前+4)`，缩容取 300s 窗口内期望最大值。这与 Kubernetes HPA 的默认算法一致（L-11 第 13 页）。

## 预测

- **算法层面：HPA 与原生 scaler 行为接近。** 两者都用 `⌈current × metric / target⌉`、容差 0.1、缩容稳定窗口 5 分钟；因此决策时刻和期望实例数预计相似。
- **扩容延迟：主要差异在 Pod 启动。** 原生 scaler 的"创建到就绪"84 秒 = `systemd-run` 21s（拉镜像）+ 60s 预热 + 健康检查。K8s HPA 的 Pod 启动包含：调度、拉镜像、容器启动、就绪探针（`/readyz`）。若镜像已在节点上，拉镜像可忽略；若未拉取，需 21s 左右。预热 60s 相同。预计 K8s HPA 从决策到就绪约 80～100 秒，与原生 scaler 同量级。
- **缺口：预计与 b2-cpu 接近（约 100～120 秒）。** 因为算法和启动延迟都相似。若 K8s 就绪探针配置更灵敏或镜像已缓存，缺口可能略短；反之略长。
- **实例·分钟：预计约 36～37。** 与 b2-cpu 的 36.7 接近，因为 min=2、max=4、缩容窗口相同。
- **错误数：预计 1.5～2.2 万量级。** 与 b2-cpu 的 21243 接近，取决于缺口期间 lbd/Service 的转发行为。K8s Service 是 iptables/IPVS 轮询，Pod 未就绪时 kube-proxy 会摘除 endpoints，与 lbd 的健康检查类似，但摘除粒度和时机可能不同。

## 实验设计（预测阶段确定）

- 部署：`deploy/o4/` 下的 Namespace、Deployment（enrolld，CPU request/limit 对应 25% 配额、内存 128M、`-warmup 60s -work 1000000`）、Service、HPA（`metrics: Resource cpu target AverageUtilization 70`，min=2，max=4）。
- 负载：与 b2-cpu 完全相同的到达曲线 `34@120s,34~340@30s,340@300s,340~34@60s,34@120s`，经 K8s Service 访问。
- 记录：`timeline.csv`（逐秒 ok_rps/error/p99）、HPA 事件（`kubectl describe hpa`）、Pod 事件（创建、就绪时刻）、Prometheus 容器 CPU 指标。
- 对照：与 `runs/b2-cpu/summary.md` 的缺口秒数、错误数、实例·分钟、就绪延迟逐项比较。

## 局限

- 本预测假设 K8s 节点与原生 scaler 实验为同一台主机、同一镜像、同一 CPU 配额；若节点不同或镜像拉取行为不同，启动延迟会变。
- K8s HPA 的 CPU 指标来自 `metrics-server`（容器 CPU 使用率），原生 scaler 来自 Prometheus 的 `cgroup_cpu_usage_seconds_total`；两者统计口径和采样窗口可能有差异，导致决策时刻略有偏移。
- K8s Service 的连接处理与 lbd 不同（无 lbd 的主动健康检查和离群摘除），错误分布可能不同。
