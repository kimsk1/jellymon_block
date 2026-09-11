# Build from repository root: docker build -f server/leaderboard/Dockerfile .
FROM node:24-bookworm-slim AS build
WORKDIR /workspace/server/leaderboard
COPY server/leaderboard/package.json server/leaderboard/package-lock.json server/leaderboard/tsconfig.json ./
RUN npm ci
COPY server/leaderboard/src ./src
COPY server/leaderboard/test ./test
COPY server/leaderboard/config ./config
COPY assets/data/item.json /workspace/assets/data/item.json
RUN npm test

FROM node:24-bookworm-slim
ENV NODE_ENV=production HOST=0.0.0.0 PORT=8787 RANKING_DB_PATH=/data/ranking.sqlite3
WORKDIR /app
COPY --from=build /workspace/server/leaderboard/dist/src ./dist/src
COPY --from=build /workspace/server/leaderboard/config ./config
COPY server/leaderboard/package.json ./
RUN mkdir /data && chown node:node /data
USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
 CMD node -e "fetch('http://127.0.0.1:8787/healthz').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "dist/src/index.js"]
