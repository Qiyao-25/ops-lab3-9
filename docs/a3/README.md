# A3 复现与证据

执行日期：2026-11-10，Asia/Shanghai；目录 /root/lab3。

先以 MemoryMax=200M、MemorySwapMax=0 启动 lab3-a，不设置 CPU 配额或 GOMAXPROCS，程序参数为 -addr 127.0.0.1:8081 -data /root/lab3/data/a。写预测后执行：

```bash
GEN_CPUS=0 scripts/run.sh a3-oom -url 'http://127.0.0.1:8081/api/report?mb=8&ms=500' -rates 10,20,30 -step 20s
```

先保留失败 unit 与内核证据，再 stop/reset-failed，重新以 MemoryMax=362M 启动，其余不变，运行同样的负载并改名 a3-limit362。最后再次 stop/reset-failed，以 MemoryMax=200M、MemorySwapMax=0、程序增加 -report-max 10 启动，运行 a3-cap10。

prediction.md 是基线测量前预测，fix-prediction.md 是两种改法测量前预测，均独立提交且之后不修改。baseline.json、selection.json 保存测量值与算式，operations.json、*-start/end.json 保存改法操作、参数和状态。补查首次死亡前并发的 PromQL 原文与结果见 pre-oom-inflight-query.json；原 red.csv 保持不变。

三组 CSV 提取结果见 comparison.json，原始数据 SHA-256 见 manifest.json。基线和提高上限方案均有 OOM，分别发生在 20 和 30 请求/秒阶段；限制并发方案存活且出现明确的 503。报告详见 LAB3.md 第 2.3 节。全部实验结束后停止 lab3-a 并清除其失败状态，监控保持运行。
