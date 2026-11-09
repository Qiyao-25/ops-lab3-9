# A1 配额算术

按指导书先写预测并独立提交，再测量；预测见 prediction.md，原始程序输出见 burn-1.txt、burn-2.txt，执行条件、二进制哈希与起止时间见 measurement-meta.txt。两次标准错误均为空、退出码均为 0。

复现命令（仓库根目录，root 用户）：

```bash
for n in 1 2; do
  systemd-run --quiet --scope -p CPUQuota=50% bin/enrolld -burn "$n" -for 10s
done
```

两次运行使用独立的临时 scope，不修改已有监控或其他服务的 CPU 配额。没有额外绑核，也没有手动设置 GOMAXPROCS；保持本机两个逻辑 CPU 可用。运行后程序自行退出。

详细表格、计算与局限见 LAB3.md 第 2.1 节。原始输出不经过编辑；SHA-256 校验清单见 manifest.json。
