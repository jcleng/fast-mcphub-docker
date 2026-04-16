FROM samanhappy/mcphub
# 先将脚本复制到容器中
COPY dependence.sh /tmp/dependence.sh
# 运行脚本
RUN chmod +x /tmp/dependence.sh && /tmp/dependence.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["pnpm", "start"]