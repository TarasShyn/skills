FROM oven/bun:1-alpine

WORKDIR /app/mcp-server

COPY mcp-server/package.json mcp-server/bun.lock ./
RUN bun install --frozen-lockfile --production

COPY mcp-server/src ./src

CMD ["bun", "run", "src/index.ts"]
