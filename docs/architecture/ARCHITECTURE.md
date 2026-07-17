NextBeats — 架构与关键组件说明（中文）

摘要
- 核心：Next.js 16.3（App Router） + React 19（React Compiler）。以 Server Components 为主，按需使用 Client Components。
- 数据：Prisma 7 + PostgreSQL；支持本地 SQLite 作为替代（dev）。
- 音频：lib/audio 包含合成与调度逻辑，浏览器端通过 Web Audio API 播放并与 UI 交互。
- 网络/体验：Instant Navigations（预取 + 客户端缓存）、Cache Components、Server Functions（用于可精细化的变更和 revalidation）。
- 测试：Playwright E2E（tests/），CI 使用 pnpm build + @next/playwright。

关键组件关系（ASCII 视图）

User Browser
  ├─> Client cache / Prefetch
  │     └─> (serve instant App Shell)
  └─> Next.js App (App Router)
         ├─> Server Functions (updateTag, mutations)
         │     └─> Prisma Client (lib/db.ts) -> Postgres/SQLite
         └─> Audio Engine (lib/audio) -> Web Audio API (client)

组件说明
- Next.js App
  - 路由与页面：app/ 下的 Server Components 优先，少量 Client Components。利用 React Compiler 优化。
  - Cache / Prefetch：link 级预取和 runtime prefetch，支持 hover/viewport 触发。
  - Server Functions：用于数据变更，调用 updateTag 来使缓存失效并部分重建页面。

- 数据层
  - Prisma 7：schema 在 prisma/schema.prisma，seed 在 prisma/seed.ts。
  - lib/db.ts：初始化 Prisma 客户端，并封装 adapter（Postgres 或 better-sqlite3）。
  - database-url.ts：规范 DATABASE_URL（强制 sslmode 除非显式禁用）。

- 音频引擎（lib/audio）
  - 包含程序化合成与调度（按曲风/轨道），在浏览器通过 Web Audio API 播放。
  - 前端控件（播放/喜欢/播放列表）通过 Server Functions 与后端同步状态（例如喜欢某曲会触发 updateTag，令相关缓存重建）。

- 测试与 E2E
  - Playwright 配置（playwright.config.ts）预置 beats-user cookie（值 e2e），webServer 启动 pnpm dev --port 3002。
  - CI 通过 pnpm run build（含 prisma generate）并运行 Playwright 场景。

如何渲染 PlantUML 图
1. 安装 plantuml 或 使用在线渲染器。
2. 在仓库根目录运行：
   - 使用 plantuml.jar: java -jar plantuml.jar docs/architecture/architecture.puml
   - 或在 IDE 插件中打开 architecture.puml 即可预览为 SVG/PNG。

建议的下步（可选）
- 生成更细化的交互序列图（例如：收藏一首歌的完整请求-缓存-重验证序列）。
- 针对 lib/audio 做单独阅读并提取模块边界与公用 API 文档。

---
需要我现在生成详细序列图（例如“favorite track”流程）或把这份 ARCHITECTURE.md 提交到仓库并 commit/push 吗？（回复：序列图 / 提交 / 都不要）