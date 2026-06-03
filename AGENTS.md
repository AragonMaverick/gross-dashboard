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
projekte (belegnummer PK) — 29 columns (id + 28 data columns including financial fields)
    ← stundenauswertung.vorgangsnummer (FK → projekte.belegnummer)
    ← termine.vorgang_projekt_nummer (FK → projekte.belegnummer)
    ← projektsummen.belegnummer (FK → projekte.belegnummer)

mitarbeiter (personalnummer PK)
    ← stundenauswertung.personalnummer (FK)

views: v_projekt_stunden (hours linked to projects)
      v_projekt_termine (appointments with employees)
      v_projekt_finanz_sichten (financials + hours + appointments)
```

SQL definitions in `init/01-databases.sql` through `init/05-projektsummen.sql`.

**Note**: `projekte_finanz` was dropped — all 28 financial CSV columns merged into `projekte` table (columns: `gemeinkostensatz_lohn`, `gemeinkostensatz_material`, `gewaehrleistungsbuergschaft`, `gueltigkeitszeitraum`, `uebertrag_umsatz_handycraft`, `vertragserfueellungsbuergschaften`, `vorauszahlungsbuergschaft`).

## Environment

`.env` variables: `POSTGRES_DB`, `DATA_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — referenced by `docker-compose.yml`.

## n8n Configuration (critical)

- **File access**: Set `N8N_RESTRICT_FILE_ACCESS_TO=/data/files` in `docker-compose.yml` (n8n 2.0+ default is `~/.n8n-files`).
- **Local folder mount**: `./analyzed:/data/files` in `docker-compose.yml`.
- **n8n workflow**: `workflows/Gross Dashboard — Data Sync(2).json` — import via n8n UI (File → Import).
- **Workflow ID**: `N3wubpslwPf7vDjK` (when importing into n8n).
- **Workflow structure**: Manual Trigger → Split Files → Switch (csv/xlsx) → Extract from File → Add File Type (Code) → Clean Data → 4 Filter nodes → 4 PostgreSQL nodes → Log Summary.
- **Clean Data node**: `runOnceForEachItem` mode, outputs single objects (not arrays). Uses `$json.data[0]` (single row), returns `{ ...cleaned, file_type }`.
- **Clean Data output keys**: All keys are **lowercase** (outputKey is `.toLowerCase()`). Matching columns from `matchingColumnsMap` also output lowercase — this is the critical fix for PostgreSQL upserts.
- **Clean Data matching columns**: `belegnummer, personalnummer, tag, von_zeit, bis_zeit, ende_datum, lohnart_nr, kst_ktr, summe_faktor, vorgangsnummer, vorgang_projekt_nummer`. These map CSV columns (original casing) to lowercase output keys matching PostgreSQL column names.
- **Upsertprojekte column mapping**: Maps all 27 data columns (belegnummer through `vorauszahlungsbuergschaft`) from Clean Data output. Uses `$json.<fieldname>` (lowercase). Do NOT reference parent nodes (`$('Clean Data').item.json`) — Clean Data already outputs the cleaned row.
- **File type detection**: Switch node routes by filename patterns (spaces preserved, e.g., `termine projekt` not `termineprojekt`).

## ERP → n8n → PostgreSQL flow

1. Manual export from PDS ERP → CSV/Excel files placed in local `analyzed/` folder
2. n8n (manual trigger) → reads files from `/data/files/` → parses CSV/Excel → cleans/converts numbers → upserts PostgreSQL
3. Metabase connects to PostgreSQL → dashboards for end users

## Future: REST API / direct DB access

When ERP provides API or read access, the n8n workflow changes from "file download → parse" to "API poll → upsert". The downstream tables and Metabase dashboards remain unchanged.
