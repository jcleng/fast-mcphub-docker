# fast-mcphub-docker

基于官方镜像 [`samanhappy/mcphub`](https://hub.docker.com/r/samanhappy/mcphub) 构建的 **MCPHub 开箱即用镜像**：
在官方 MCPHub 网关/控制面之上，预装一批常用的 MCP Server（uv 工具 + npm 全局包），
启动容器后即可直接在 MCPHub 面板中添加/运行这些 MCP Server，无需再进入容器安装依赖。

构建产物推送到阿里云镜像仓库：

```
registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest
```

---

## 1. 项目结构

```
.
├── Dockerfile          # 构建入口：以 samanhappy/mcphub 为基础，执行 dependence.sh
├── dependence.sh       # 预装依赖脚本（唯一需要日常维护的依赖清单）
├── README.md           # 本文档
├── AGENTS.md           # 给 AI Agent / 协作者的构建与维护说明
└── .vscode/            # 编辑器配色（Peacock），已 gitignore
```

> 仓库根目录就是 Docker 构建上下文，`Dockerfile` 与 `dependence.sh` 必须同时存在。

---

## 2. 镜像说明

| 项目 | 值 |
| --- | --- |
| 基础镜像 | `samanhappy/mcphub`（MCPHub `@samanhappy/mcphub`，Node 22 / pnpm） |
| 工作目录 | `/app` |
| 暴露端口 | `3000`（实际端口由环境变量 `PORT` 覆盖，例如 `3008`） |
| Entrypoint | `/usr/local/bin/entrypoint.sh`（官方脚本，负责 npm registry/proxy、dockerd 自启等） |
| CMD | `pnpm start`（即 `node dist/index.js`） |
| 预装依赖层体积 | 约 3.07 GB（镜像总计约 4.4 GB） |
| 配置/数据 | `/app/mcp_settings.json`（兼容旧挂载）或 `/app/data/mcp_settings.json` |

`Dockerfile` 内容极简，只做三件事：

```dockerfile
FROM samanhappy/mcphub
COPY dependence.sh /tmp/dependence.sh
RUN chmod +x /tmp/dependence.sh && /tmp/dependence.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["pnpm", "start"]
```

即：**基础镜像 + 依赖脚本 = 本镜像**。除依赖清单外，不修改官方行为。

---

## 3. 预装依赖

全部在 `dependence.sh` 中定义，分两类：

### 3.1 Python（`uv tool install`，安装到 `/root/.local/bin`）

| 包 | 提供的命令 |
| --- | --- |
| `mcp-server-fetch` | `mcp-server-fetch` |
| `mysql_mcp_server` | `mysql_mcp_server` |
| `mcp-server-git` | `mcp-server-git` |
| `mindmap-mcp-server` | `mindmap-mcp-server` |

### 3.2 Node（`npm install -g`，安装到 `/usr/lib/node_modules`）

| 包 | 用途 | 最近构建版本 |
| --- | --- | --- |
| `@wonderwhy-er/desktop-commander` | 终端/文件操作 | 0.2.52 |
| `@upstash/context7-mcp` | 文档检索 | 4.1.1 |
| `@modelcontextprotocol/server-sequential-thinking` | 顺序思考 | 2026.8.31 |
| `@modelcontextprotocol/server-filesystem` | 文件系统 | 2026.8.31 |
| `@negokaz/excel-mcp-server` | Excel 读写 | 0.12.0 |
| `@dbx-app/mcp-server` | DBX | 0.4.102 |
| `dingtalk-mcp@latest` | 钉钉 | 1.1.21 |
| `mcp-local-rag` | 本地 RAG | 0.19.1 |

> 版本号仅代表最近一次成功构建时的实际安装结果，每次构建都会拉取当时的最新版。

> 新增/升级依赖：只改 `dependence.sh`，然后按第 4 节重新构建即可，**不要**改 `Dockerfile`。

---

## 4. 构建流程

本项目**不在本地构建**，统一通过公共构建仓库
[`jcleng/action-sync-images`](https://github.com/jcleng/action-sync-images)
的 GitHub Actions 工作流
[`.github/workflows/build-repo.yml`](https://github.com/jcleng/action-sync-images/blob/main/.github/workflows/build-repo.yml)
在云端 clone 源码 → `docker build` → 推送阿里云 → 打 Release。

### 4.1 工作流做了什么

```yaml
on:
  workflow_dispatch:
    inputs:
      arg_repo_url:     # 源码仓库地址
      arg_branch_name:  # 分支名
      arg_username:     # 镜像前缀（固定 gitbuild）
      arg_name:         # 镜像名（可带 tag，如 mybuild:1.0）
      arg_aliyunurl:    # 阿里云 registry
      arg_aliyunuser:   # 阿里云命名空间
```

关键步骤：

```bash
git clone --depth=1 -b <branch> <repo_url> work_src
cd work_src
docker build . -t <aliyunurl>/<user>/<username>-<name>
docker push      <aliyunurl>/<user>/<username>-<name>
```

最后用 `softprops/action-gh-release` 生成 tag 为 `<username>-<name>` 的 Release，
附上 `release.txt`（镜像地址）与源码里的 `Dockerfile`。
Release tag 中的 `:` 会被替换成 `_`。

### 4.2 本项目的固定参数

| 输入 | 值 |
| --- | --- |
| `arg_repo_url` | `https://github.com/jcleng/fast-mcphub-docker` |
| `arg_branch_name` | `master` |
| `arg_username` | `gitbuild` |
| `arg_name` | `fast-mcphub-docker` |
| `arg_aliyunurl` | `registry.cn-hangzhou.aliyuncs.com` |
| `arg_aliyunuser` | `jcleng` |

拼出的镜像地址：

```
registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker
```

### 4.3 触发一次构建

前置：本机已安装并登录 `gh`（`gh auth status` 正常，token 需含 `workflow` 权限）。

```bash
gh workflow run build-repo.yml \
  --repo jcleng/action-sync-images \
  --ref main \
  -f arg_repo_url="https://github.com/jcleng/fast-mcphub-docker" \
  -f arg_branch_name="master" \
  -f arg_username="gitbuild" \
  -f arg_name="fast-mcphub-docker" \
  -f arg_aliyunurl="registry.cn-hangzhou.aliyuncs.com" \
  -f arg_aliyunuser="jcleng"
```

查看/等待结果：

```bash
# 最近一次运行
gh run list --repo jcleng/action-sync-images --workflow build-repo.yml --limit 3

# 实时查看某个 run
gh run watch <run_id> --repo jcleng/action-sync-images

# 查看构建/推送命令是否与预期一致
gh run view <run_id> --repo jcleng/action-sync-images --log \
  | grep -oE "git clone[^\r]*|docker (build|push)[^\r]*"
```

> **重要**：Actions 在云端 clone 的是 GitHub 上的源码，因此触发构建前必须先
> `git push origin master`，否则构建的是旧代码。

### 4.4 本地复现（可选）

需要本机 Docker 与阿里云登录：

```bash
docker build . -t registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest
docker login registry.cn-hangzhou.aliyuncs.com
docker push registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker:latest
```

本地构建会复用 Docker 层缓存，仅 `dependence.sh` 变化时才重跑安装层。

---

## 5. 运行 / 部署

示例 `docker-compose.yml`（取自实际部署）：

```yaml
services:
  mcphub:
    image: registry.cn-hangzhou.aliyuncs.com/jcleng/gitbuild-fast-mcphub-docker
    container_name: mcphub
    network_mode: host
    environment:
      - ADMIN_PASSWORD=jclengpass
      - PORT=3008
      - PUPPETEER_SKIP_DOWNLOAD=true
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    volumes:
      - "/home/jcleng/work/mywork/:/home/jcleng/work/mywork/"
      - ./mcp_settings.json:/app/mcp_settings.json
      - "./php:/usr/bin/php"
```

启动后访问 `http://<host>:3008`，默认分组 MCP 入口形如
`http://<host>:3008/mcp/default`（需先在面板创建 `default` 分组）。

常用环境变量：

| 变量 | 说明 |
| --- | --- |
| `PORT` | 服务端口，默认 `3000` |
| `ADMIN_PASSWORD` | 管理面板密码 |
| `MCPHUB_SETTING_PATH` | 配置文件路径；未设置时优先 `/app/mcp_settings.json`，否则 `/app/data/mcp_settings.json` |
| `NPM_REGISTRY` | entrypoint 会据此设置 npm registry |
| `HTTP_PROXY` / `HTTPS_PROXY` | entrypoint 会据此设置 npm 代理 |
| `REQUEST_TIMEOUT` | 请求超时 |

---

## 6. 构建历史

| Run | 时间 | 结果 |
| --- | --- | --- |
| [38117185264](https://github.com/jcleng/action-sync-images/actions/runs/38117185264) | 2026-10-11 | success |
| [36662614342](https://github.com/jcleng/action-sync-images/actions/runs/36662614342) | 2026-09-30 | success |
| [33741973949](https://github.com/jcleng/action-sync-images/actions/runs/33741973949) | 2026-09-03 | success |
| [30324495899](https://github.com/jcleng/action-sync-images/actions/runs/30324495899) | 2026-07-28 | success |
| [30062426695](https://github.com/jcleng/action-sync-images/actions/runs/30062426695) | 2026-07-24 | success |
| [24497234813](https://github.com/jcleng/action-sync-images/actions/runs/24497234813) | 2026-04-16 | success（README 中记录的首次运行） |

Release 页面：
<https://github.com/jcleng/action-sync-images/releases/tag/gitbuild-fast-mcphub-docker>

---

## 7. 注意事项

- 依赖安装层约 3 GB，`dependence.sh` 任何改动都会让该层缓存失效、重新下载全部包，构建时间较长（通常数分钟到十几分钟）。
- 新镜像使用 `latest` 覆盖式推送，**没有版本 tag**；回滚只能依赖本地已拉取的镜像或 digest。
- 新增依赖时，优先确认其在容器内（root、musl/glibc、Node 22）可安装、可执行。
- `uv tool install` 的产物在 `/root/.local/bin`，该路径不在默认 `PATH` 中；在 MCPHub 里配置命令时请写绝对路径。
