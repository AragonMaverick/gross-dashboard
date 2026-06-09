# Gross-Dashboard — Agent Instructions

## Stack

| Service | Container | Port | URL |
|---------|-----------|------|-----|
| PostgreSQL 16 | `gross_postgres` | 5432 | — |
| n8n | `gross_n8n` | 5678 | http://localhost:5678 |
| Metabase | `gross_metabase` | 3000 | http://localhost:3000 |

PostgreSQL hosts 3 databases: `gross_dashboard` (app data), `gross_dashboard_n8n` (n8n metadata), `gross_dashboard_metabase` (Metabase metadata).

## Quick commands

```bash
docker compose up -d                                            # Start all services
docker compose ps                                               # Check status
docker compose down                                             # Stop all (data persists in named volumes)
docker exec -it gross_postgres psql -U gross_user -d gross_dashboard  # DB shell
```

## Data format (critical — agents frequently miss these)

- **German number format**: comma = decimal, period = thousands (e.g. `3.506,850` → `3506.85`)
   - Use `parse_german_number(text_value)` function — defined in `init/02-projekte.sql`, or handle in n8n before insert.
- **Encoding**: Windows-1252 / UTF-8 with German umlauts (ä, ö, ü, ß). Display may show mojibake.
- **Semicolon-delimited CSVs** with quoted fields.
- **Multi-line fields**: `Erstell-Info` in projekte, `Meldungstext` in stundenauswertung span multiple CSV lines. Must use a proper CSV parser (not naive `split('\n')`).
- **ERP 1000-row limit**: Some exports split into multiple files (e.g. 4 files for termine projekt). Must merge by name prefix before processing.

## File naming conventions

| Prefix | Meaning |
|--------|---------|
| `pds export projekte.csv` | Project records (unique key: `belegnummer`) |
| `pds export stundenauswertung [year].csv` | Time tracking per employee (dedup via `import_hash`) |
| `pds export termine [type] [period].csv` | Appointment scheduling (links to projekte via `vorgang_projekt_nummer`). Types: `projekt`, `freier termin`, `stoerung`, `urlaub` |
| `projektsummen_v2_*.xlsx` | Project financial summaries (Excel, 3 files: `alle`, `erledigt`, `offen`) |

## Database schema

```
projekte (belegnummer PK) — 29 columns (id + 28 data columns including financials)
     ← stundenauswertung.vorgangsnummer (FK → projekte.belegnummer)
     ← termine.vorgang_projekt_nummer (FK → projekte.belegnummer)
     ← projektsummen.belegnummer (FK → projekte.belegnummer)

mitarbeiter (personalnummer PK)
     ← stundenauswertung.personalnummer (FK)

termine (id PK) — flat structure with separate date/time columns
     → Multi-day appointments expanded: one row per employee per day
     → Single-day: 1 row; Multi-day: N days × M employees = N×M rows
     → Columns: von_date, von_time, bis_date, bis_time (TEXT), personalnummer (TEXT), mitarbeiter (TEXT)

projektsummen (belegnummer PK, FK → projekte)

views: v_projekt_stunden          (hours linked to projects)
       v_projekt_termine            (appointments with employees)
       v_projekt_finanz_sichten     (financials + hours + appointments)
```

SQL definitions: `init/01-databases.sql` through `init/05-projektsummen.sql`.

**Note**: `projekte_finanz` was dropped — all 28 financial CSV columns merged into `projekte` table (columns: `gemeinkostensatz_lohn`, `gemeinkostensatz_material`, `gewaehrleistungsbuergschaft`, `gueltigkeitszeitraum`, `uebertrag_umsatz_handycraft`, `vertragserfueellungsbuergschaften`, `vorauszahlungsbuergschaft`).

## Environment

Copy `.env.example` → `.env`. Variables: `POSTGRES_DB`, `DATA_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — referenced by `docker-compose.yml`. n8n and Metabase each get their own database (`${DATA_DB}_n8n`, `${DATA_DB}_metabase`).

## n8n Configuration (critical)

- **File access**: `N8N_RESTRICT_FILE_ACCESS_TO=/data/files` in `docker-compose.yml` (n8n 2.0+ default is `~/.n8n-files`).
- **Local folder mount**: `./analyzed:/data/files` in `docker-compose.yml`.
- **n8n workflow**: `workflows/Gross Dashboard — Data Sync.json` — import via n8n UI (File → Import).
- **Workflow structure**: Manual Trigger → Truncate tables → Read Files from Disk → Split Files → 3 Filter nodes (by file type) → 3 processing pipelines.
- **Clean Data node**: `runOnceForEachItem` mode, outputs single objects (not arrays). Uses `$json.data[0]` (single row), returns `{ ...cleaned, file_type }`.
- **Clean Data output keys**: All keys are **lowercase** (`.toLowerCase()`). Matching columns from `matchingColumnsMap` also output lowercase — this is the critical fix for PostgreSQL upserts.
- **Clean Data matching columns**: `belegnummer, personalnummer, tag, von_zeit, bis_zeit, ende_datum, lohnart_nr, kst_ktr, summe_faktor, vorgangsnummer, vorgang_projekt_nummer`. These map CSV columns (original casing) to lowercase output keys matching PostgreSQL column names.
- **Upsert projekte column mapping**: Maps all data columns from Clean Data output. Uses `$json.<fieldname>` (lowercase). Do NOT reference parent nodes (`$('Clean Data').item.json`) — Clean Data already outputs the cleaned row.
- **File type detection**: Filters route by filename patterns (spaces preserved, e.g., `termine projekt` not `termineprojekt`).
- **Clean termine node**: Full transformation pipeline — parses German datetime (Von/Bis), splits into date + time (defaults: 07:00 for Von, 15:00 for Bis), splits by Mitarbeiter (if `<diverse>`), expands by DateList (multi-day), calculates per-day Start/End times. 17 columns in column mapping (removed `bis`/`von` — PostgreSQL `termine` table has no such columns). `fix` column: 'ja'/'nein' → boolean true/false. Outputs 8,947 rows from 3,624 CSV rows (986 diverse → ~3,806 employee rows; 3,276 multi-day → expanded by day count, max 46 days).
- **Row count note**: Source CSV files (2026Q2+ to 2027) produce 8,947 rows. Excel file includes 2025 historical data (18,751 additional rows) for 32,027 total — place 2025 CSV files in `analyzed/` folder to match Excel output.

## ERP → n8n → PostgreSQL flow

1. Manual export from PDS ERP → CSV/Excel files placed in local `analyzed/` folder
2. n8n (manual trigger) → reads files from `/data/files/` → parses CSV/Excel → cleans/converts numbers → upserts PostgreSQL
3. Metabase connects to PostgreSQL → dashboards for end users

## Future: REST API / direct DB access

When ERP provides API or read access, the n8n workflow changes from "file download → parse" to "API poll → upsert". The downstream tables and Metabase dashboards remain unchanged.
