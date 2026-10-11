# AGENTS.md

面向 AI Agent / 协作者的本仓库操作说明。人类可读的项目介绍见 [README.md](./README.md)。

## 仓库定位

`fast-mcphub-docker` 是一个**纯 Dockerfile 包装仓库**：把官方 MCPHub 镜像
`samanhappy/mcphub` 加上一批预装 MCP Server 依赖，构建成
`registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest`。

仓库里只有 3 个有效文件：

| 文件 | 作用 | 改动频率 |
| --- | --- | --- |
| `dependence.sh` | 预装依赖清单（uv + npm） | 唯一日常改动点 |
| `Dockerfile` | `FROM samanhappy/mcphub` + 执行 `dependence.sh` | 几乎不动 |
| `README.md` / `AGENTS.md` | 文档 | 随流程变化更新 |

## 不变量（不要破坏）

1. **Dockerfile 保持极简**。依赖变更只改 `dependence.sh`，不要在 `Dockerfile` 里塞 `RUN npm install ...`。
2. **不覆盖官方 `ENTRYPOINT`/`CMD`**：`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`、`CMD ["pnpm", "start"]`。官方 entrypoint 负责 npm registry/proxy 注入和 dockerd 自启。
3. **不改基础镜像 tag**，当前固定为 `samanhappy/mcphub`（浮动 latest，构建时拉最新）。
4. **不改镜像名/命名空间**：`gitbuild` 前缀 + `fast-mcphub-docker` 名称 + `jcleng` 命名空间，这是历史构建的固定约定。
5. **构建在云端完成**，本地不产出正式镜像。正式产物永远来自 `jcleng/action-sync-images` 的 Actions。

## 构建流程（标准操作）

构建由外部仓库 `jcleng/action-sync-images` 的工作流
`.github/workflows/build-repo.yml` 完成，逻辑为：
`git clone → docker build → docker push 阿里云 → 创建 GitHub Release`。

### 步骤

```bash
# 0. 前置检查
gh auth status                       # 需要已登录，token 含 workflow 权限
git -C . remote -v                   # 应为 jcleng/fast-mcphub-docker

# 1. 提交并推送（关键！Actions 从 GitHub 拉代码，不推就等于构建旧版本）
git add -A && git commit -m "..." && git push origin master

# 2. 触发云端构建
gh workflow run build-repo.yml \
  --repo jcleng/action-sync-images \
  --ref main \
  -f arg_repo_url="https://github.com/jcleng/fast-mcphub-docker" \
  -f arg_branch_name="master" \
  -f arg_username="gitbuild" \
  -f arg_name="fast-mcphub-docker" \
  -f arg_aliyunurl="registry.cn-hangzhou.aliyuncs.com" \
  -f arg_aliyunuser="jcleng"

# 3. 等待并验证
gh run list --repo jcleng/action-sync-images --workflow build-repo.yml --limit 3
gh run watch <run_id> --repo jcleng/action-sync-images
```

### 验证构建正确性（必做）

```bash
# 确认本次 run 用的是预期源码与镜像名
gh run view <run_id> --repo jcleng/action-sync-images --log \
  | grep -oE "git clone --depth=1 -b [^ ]+ [^ ]+ work_src|docker (build|push)[^\r]*"

# 期望输出（示例）
# git clone --depth=1 -b master https://github.com/jcleng/fast-mcphub-docker work_src
# docker build . -t registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker
# docker push registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker
```

只有当 run 状态为 `completed/success` 且日志中的 clone 分支、镜像名与预期一致时，才能声明构建成功。

### 验证镜像内容（改动 `dependence.sh` 后建议执行）

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest

# npm 全局包
docker run --rm --entrypoint sh \
  registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest \
  -c 'npm ls -g --depth=0'

# uv 工具
docker run --rm --entrypoint sh \
  registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest \
  -c 'ls /root/.local/bin && uv tool dir'
```

## 已知坑

- **忘记 push 就触发构建**：Actions clone 的是远端 `master`，本地未推送的改动不会进镜像。这是最常见的错误。
- **`uv tool install` 的路径问题**：装到 `/root/.local/bin`，不在默认 `PATH` 里。MCPHub 中配置这些 server 时要用绝对路径（如 `/root/.local/bin/mcp-server-fetch`），或自行确保 `PATH` 包含该目录。
- **依赖层缓存**：`dependence.sh` 一行改动会让约 3 GB 的安装层缓存失效，构建变慢。批量改依赖时一次改完。
- **`latest` 覆盖推送，无版本 tag**：无法通过 tag 回滚。需要回滚时用本地镜像或 digest（`docker inspect` 的 `RepoDigests`）。
- **`arg_name` 可带 tag**：若写 `fast-mcphub-docker:v1`，Release tag 会把 `:` 替换为 `_`。
- **Release tag 冲突**：Release tag 固定为 `gitbuild-fast-mcphub-docker`，重复构建是覆盖同一个 Release，不会新建。
- **git 目录属主问题**：本机仓库可能报 `dubious ownership`，需要
  `git config --global --add safe.directory /home/jcleng/work/mywork/fast-mcphub-docker`。

## 部署参考

实际部署在 `/home/jcleng/work/mywork/simplecode/docker-compose.yml`，使用
`network_mode: host` + `PORT=3008`，挂载 `mcp_settings.json` 与宿主机工作目录。
端口、密码、挂载路径以该文件为准。

## 文档维护约定

- 依赖清单变化 → 更新 README 的「预装依赖」表。
- 构建方式/参数变化 → 同步更新 README「构建流程」与本文「构建流程」。
- 完成一次成功构建 → 在 README「构建历史」表中追加一行（Run ID、日期、结果）。
- 保持 README 与 AGENTS.md 中镜像地址、仓库地址、分支名一致，避免出现两套说法。
