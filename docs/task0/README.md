# 任务 0 环境验证

检查日期：2026-11-09（Asia/Shanghai）。主机工作目录：`/root/lab3`。

- 小组仓库为公开仓库，由课程模板初始化。组长确认组员已邀请。
- `make build test` 退出码为 0，六个程序编译成功，全部七个包测试通过。
- Go、systemd、cgroup v2、CPU、内存和 sysstat 已满足实验要求。
- Prometheus 与 node_exporter 从实验 2 工具目录复用，版本分别为 3.13.4、1.12.1。
- `promtool check config deploy/prometheus.yml` 通过。
- 监控只监听本机回环地址，二者均绑定 CPU 0；后续实例使用 CPU 1。
- Prometheus 目标 API 成功返回，node 为 up；enrolld、lbd 尚未启动，为 down。

## 文件

`environment.txt` 为主机检查命令原文；`build-test.txt` 为编译测试输出；`targets.json`、`node-up.json`、`prometheus-ready.txt` 为检查时监控接口原文。任务 0 未产生压测数据，故记录单独保存在此处；`runs/` 留给指导书指定实验脚本生成的原始输出。

## 后续使用

当前后台服务可用下列命令检查：

```bash
cd /root/lab3
systemctl status lab3-prometheus lab3-node-exporter --no-pager
curl -fsS http://127.0.0.1:9090/api/v1/targets
journalctl -u lab3-prometheus -u lab3-node-exporter -n 50 --no-pager
```

临时服务不随主机重启自动启动。主机重启后，在端口空闲时重新运行：

```bash
cd /root/lab3
mkdir -p data
[ -e data/targets.json ] || printf '[]\n' > data/targets.json
systemd-run --unit=lab3-node-exporter --property=WorkingDirectory=/root/lab3 --property=Restart=on-failure /usr/bin/taskset -c 0 /root/lab3/tools/node_exporter --web.listen-address=127.0.0.1:9100
systemd-run --unit=lab3-prometheus --property=WorkingDirectory=/root/lab3 --property=Restart=on-failure /usr/bin/taskset -c 0 /root/lab3/tools/prometheus --config.file=deploy/prometheus.yml --storage.tsdb.path=/dev/shm/lab3-prom --web.listen-address=127.0.0.1:9090
```

临时服务仍存在时，使用 `systemctl restart lab3-prometheus lab3-node-exporter` 重启。停止使用 `systemctl stop lab3-prometheus lab3-node-exporter`。任务 A～E 运行期间保持监控服务运行，不要重复占用 9090、9100 端口。Prometheus 数据暂存在 `/dev/shm/lab3-prom`，重启主机后不会保留。
