#!/usr/bin/env sh
uv tool install mcp-server-fetch
uv tool install mysql_mcp_server
uv tool install mcp-server-git
uv tool install mindmap-mcp-server

npm install -g @wonderwhy-er/desktop-commander
npm install -g @upstash/context7-mcp
npm install -g @modelcontextprotocol/server-sequential-thinking
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @negokaz/excel-mcp-server