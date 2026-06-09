-- Table for appointment scheduling exports (v3 — flat structure with separate date/time)
-- Source files: pds export termine [type] [period].csv
-- Types: projekt, freier termin, stoerung, urlaub
-- Table is truncated before each batch import
-- Multi-day appointments expanded: one row per employee per day
-- Single-day appointments: 1 row; Multi-day: N days × M employees = N×M rows

DROP VIEW IF EXISTS v_projekt_termine;
DROP TABLE IF EXISTS termine CASCADE;

CREATE TABLE termine (
    id SERIAL PRIMARY KEY,
    terminbezeichnung TEXT,
    terminbeschreibung TEXT,
    von_date TEXT,
    von_time TEXT,
    bis_date TEXT,
    bis_time TEXT,
    status TEXT,
    personalnummer TEXT,
    mitarbeiter TEXT,
    dauer TEXT,
    fix BOOLEAN,
    geschaeftspartner TEXT,
    einsatzort TEXT,
    vorgang_projekt_bezeichnung TEXT,
    vorgang_projekt_nummer TEXT,
    vorgang_projekt_typ TEXT,
    file_type TEXT
);

CREATE INDEX idx_termine_von_date       ON termine(von_date);
CREATE INDEX idx_termine_von_time       ON termine(von_time);
CREATE INDEX idx_termine_bis_date       ON termine(bis_date);
CREATE INDEX idx_termine_bis_time       ON termine(bis_time);
CREATE INDEX idx_termine_status         ON termine(status);
CREATE INDEX idx_termine_projekt        ON termine(vorgang_projekt_nummer);
CREATE INDEX idx_termine_personalnummer ON termine(personalnummer);
CREATE INDEX idx_termine_mitarbeiter    ON termine(mitarbeiter);
CREATE INDEX idx_termine_file_type      ON termine(file_type);

CREATE OR REPLACE VIEW v_projekt_termine AS
SELECT
    von_date,
    von_time,
    bis_date,
    bis_time,
    status,
    personalnummer,
    mitarbeiter,
    dauer,
    fix,
    geschaeftspartner,
    einsatzort,
    vorgang_projekt_bezeichnung,
    vorgang_projekt_nummer,
    vorgang_projekt_typ,
    file_type
FROM termine;

COMMENT ON TABLE termine IS 'Flat appointment scheduling rows — all 4 types (projekt, freier_termin, stoerung, urlaub), truncated before each import. Separate date/time columns for per-day tracking. Multi-day appointments expanded: one row per employee per day.';
COMMENT ON VIEW   v_projekt_termine IS 'View: appointments with employee and project info, separate date/time columns';
