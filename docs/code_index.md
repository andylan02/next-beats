NextBeats — Code Index (selected files)

Scope: app/, lib/, features/, prisma/, tests/

Top-level entry points
- app/layout.tsx — App shell, ThemeProvider, providers.
- app/api/play/route.ts — Server Function: POST increments playCount + upsert userTrackPlay. Calls prisma.track.update (lines 22-25) and prisma.userTrackPlay.upsert (27-31). Calls revalidateTag for recently-played and discover.
- prisma/seed.ts — seeds TRACKS and PLAYLISTS and creates e2e user. Uses normalizeDatabaseUrl from lib/database-url and Prisma client in lib/db.ts.

lib/
- lib/db.ts — exports prisma (PrismaClient with PrismaPg adapter). Used across server functions and queries (features/* and app/api/*).
- lib/database-url.ts — normalizeDatabaseUrl(url): enforces sslmode=verify-full unless disabled.
- lib/utils.ts — cn, delay, formatDuration, formatCount helpers.

lib/audio/
- music-engine.ts — procedural audio generation (getAudioContext, resetAudioContext, scheduleBar, getSecondsPerBar). Core synthesizer.
- audio-scheduler.ts — scheduleTrack/resumeTrack, AudioRefs lifecycle, used by PlayerProvider.
- genre-configs.ts — GenreConfig definitions and genreConfigs map.
- track-profiles.ts — per-track profile overrides.

features/
- features/track/*
  - track-queries.ts — read-side: many prisma.findMany/findUnique queries; uses cacheTag and cacheLife. Notable DB calls: prisma.track.findMany, prisma.userFavorite.findMany, prisma.userTrackPlay.findMany (lines shown in file).
  - track-actions.ts — toggleFavorite: uses prisma.userFavorite.findUnique/create/delete and updateTag/revalidateTag.
- features/playlist/*
  - playlist-queries.ts — getPlaylists/getPlaylist/getPlaylistMenuItems: uses prisma.playlist.findMany, prisma.playlist.findFirst, prisma.playlistTrack queries and cacheTag usage.
  - playlist-actions.ts — createPlaylist/addToPlaylist/removeFromPlaylist/deletePlaylist: uses prisma.playlist.create, prisma.playlistTrack.create/delete, prisma.playlist.delete and updateTag calls.

app/api/
- app/api/play/route.ts — POST increments playCount and upserts userTrackPlay. Uses cookies() for beats-user session.

Tests
- Playwright tests in tests/ drive UI flows; playwright.config.ts seeds beats-user cookie and starts dev server.

Call graph highlights (server-side)
- Server endpoints/Server Functions -> prisma (lib/db.ts)
  - play POST -> prisma.track.update; prisma.userTrackPlay.upsert; revalidateTag
  - toggleFavorite (track-actions.ts) -> prisma.userFavorite.findUnique/create/delete; updateTag + revalidateTag
  - playlist-actions.* -> prisma.playlist/create/delete; prisma.playlistTrack create/delete; updateTag

Notes & next steps
- Many server reads use 'use cache' + cacheTag/updateTag to support selective revalidation. When mutating, updateTag(...) is used to mark affected tags.
- Suggest exporting this file and server-db-calls.puml into docs/ and committing (done). For deeper indexing, run symbol-level extraction across other files or generate a full GraphViz of call edges.
