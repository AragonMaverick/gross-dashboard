# Gross-Dashboard — Agent Instructions

## Stack

| Service | Container | Port | URL |
|---------|-----------|------|-----|
| PostgreSQL 16 | `gross_postgres` | 5432 | — |
| n8n | `gross_n8n` | 5678 | http://localhost:5678 |
| Metabase | `gross_metabase` | 3000 | http://localhost:3000 |

## Quick commands

```bash
docker compose up -d          # Start all services
docker compose ps             # Check status
docker compose down           # Stop all (data persists in named volumes)
docker exec -it gross_postgres psql -U gross_user -d gross_dashboard  # DB shell
```

## Data format (critical — agents frequently miss these)

- **German number format**: comma = decimal, period = thousands (e.g. `3.506,850` → `3506.85`)
  - Use `parse_german_number(text_value)` function in SQL, or handle in n8n before insert.
- **Encoding**: Windows-1252 / UTF-8 with German umlauts (ä, ö, ü, ß). Display may show mojibake.
- **Semicolon-delimited CSVs** with quoted fields.
- **Multi-line fields**: `Erstell-Info` in projekte, `Meldungstext` in stundauswertung span multiple CSV lines. Must use a proper CSV parser (not naive `split('\n')`).
- **ERP 1000-row limit**: Some exports split into multiple files (e.g. 4 files for termine projekt). Must merge by name prefix before processing.

## File naming conventions

| Prefix | Meaning |
|--------|---------|
| `pds export projekte.csv` | Project records (unique key: `belegnummer`) |
| `pds export stundenauswertung [year].csv` | Time tracking per employee (composite key: `personalnummer + tag + lohnart_nr + kst_ktr + summe_faktor`) |
| `pds export termine [type] [period].csv` | Appointment scheduling (links to projekte via `Vorgang/Projekt Nummer`) |
| `projektsummen_v2_*.xlsx` | Project financial summaries (Excel, 38 columns) |

## Database schema

```
projekte (belegnummer PK)
    └── projekte_finanz (FK → projekte.belegnummer)
    ← stundenauswertung.vorgangsnummer (FK → projekte.belegnummer)
    ← termine.vorgang_projekt_nummer (FK → projekte.belegnummer)
    ← projektsummen.belegnummer (FK → projekte.belegnummer)

mitarbeiter (personalnummer PK)
    ← stundenauswertung.personalnummer (FK)

views: v_projekt_stunden (hours linked to projects)
      v_projekt_termine (appointments with employees)
      v_projekt_finanz_sichten (financials + hours + appointments)
```

SQL definitions live in `init/02-projekte.sql`, `init/03-stundenauswertung.sql`, and `init/04-termine.sql`.

## Environment

`.env` variables: `POSTGRES_DB`, `DATA_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — referenced by `docker-compose.yml`.

## n8n Configuration (critical)

- **File access**: Set `N8N_RESTRICT_FILE_ACCESS_TO=/data/files` in `docker-compose.yml` to allow the Read/Write Files node to access mounted folders.
- **Local folder mount**: `./analyzed:/data/files` in docker-compose.yml mounts the host folder into the container.
- **n8n workflow**: Located at `workflows/gross-dashboard-sync.json` — imports via n8n UI (File → Import).
- **Workflow structure**: Manual Trigger → Read/Write Files → Split Files → Route by Type → Parse CSV/Excel → Clean Data → PostgreSQL Upsert → Log Summary.
- **File type detection**: Route by Type node uses filename patterns (spaces preserved, e.g., `termine projekt` not `termineprojekt`).

## ERP → n8n → PostgreSQL flow

1. Manual export from PDS ERP → CSV/Excel files placed in local `analyzed/` folder
2. n8n (manual trigger) → reads files from `/data/files/` → parses CSV/Excel → cleans/converts numbers → upserts PostgreSQL
3. Metabase connects to PostgreSQL → dashboards for end users

## Future: REST API / direct DB access

When ERP provides API or read access, the n8n workflow changes from "file download → parse" to "API poll → upsert". The downstream tables and Metabase dashboards remain unchanged.
