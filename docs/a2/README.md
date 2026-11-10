# A2 复现与证据

执行日期：2026-11-10（Asia/Shanghai）。目录：/root/lab3。

先以 CPUQuota=100%、MemoryMax=256M、-work 2000000 启动 lab3-a。测 30、60 请求/秒后，取第二阶段每请求 CPU=4.27909 ms，计算 R=round(400/4.27909)=93。预计用核 0.39795537，改法一配额 ceil(0.39795537/0.7*100)=57%。预测在修改配额前独立提交，之后保持原文。

四组均使用：

```bash
export GEN_CPUS=0
scripts/run.sh a2-base-r -url http://127.0.0.1:8081/api/courses/1 -rates 93,93 -step 20s
```

100% 对照完成后，不重启实例，执行 systemctl set-property --runtime lab3-a CPUQuota=50%，运行 a2-q50；再改为 CPUQuota=57%，运行 a2-q57。最后停止实例，以原参数加 --setenv=GOMAXPROCS=1、配额 50% 重启，运行 a2-gmp1。每组更换实验名字，不覆盖旧数据。

完整操作与状态见 operations.json、*-state.json；LAB3.md 第 2.2 节保存四张表及分析。comparison.json 提取 CSV 便于核对，manifest.json 保存所有原始实验文件的 SHA-256。测量后停止 lab3-a，保留监控服务，状态见 final-state.json。
