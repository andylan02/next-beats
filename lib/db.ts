import 'server-only';

import { PrismaBetterSqlite3 } from '@prisma/adapter-better-sqlite3';
import { PrismaClient } from '@/generated/prisma/client';

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

const rawDbUrl = process.env.DATABASE_URL!;
// strip leading file: prefix and optional ./ so adapter receives a filesystem path
const sqlitePath = rawDbUrl.replace(/^file:/, '').replace(/^\.\//, '');

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    adapter: new PrismaBetterSqlite3({ url: sqlitePath }),
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}
