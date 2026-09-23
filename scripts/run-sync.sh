#!/bin/sh
set -eu

mkdir -p logs
npx tsx scripts/sync-internships.ts --log-file=logs/sync-latest.json
cp logs/sync-latest.json "logs/sync-$(date -u +%Y-%m-%dT%H-%M-%SZ).json"
npm run db:prune
