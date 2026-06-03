-- Table for appointment scheduling exports
-- Source files: pds export termine projekt [period].csv (4 files, ~1650 rows)
--                pds export termine freier termin [period].csv (4 files, ~1030 rows)
--                pds export termine stoerung [period].csv (3 files, ~6590 rows)
--                pds export termine urlaub [period].csv (4 files, ~370 rows)
-- Multi-employee handling: one row per appointment + junction table

CREATE TABLE IF NOT EXISTS termine (
    id SERIAL PRIMARY KEY,
    terminbezeichnung TEXT,           -- Full label (composite: address + project num + name)
    terminbeschreibung TEXT,          -- Description (mostly empty)
    von TIMESTAMP,                   -- Start datetime (e.g., "07.04.2026 07:00")
    bis TIMESTAMP,                   -- End datetime
    status TEXT,                     -- Status ("Geplant", "Erledigt")
    dauer TEXT,                      -- Duration (e.g., "8:45")
    fix BOOLEAN,                     -- Fixed appointment (ja/nein)
    geschaeftspartner TEXT,          -- Business partner name
    einsatzort TEXT,                 -- Location address
    vorgang_projekt_bezeichnung TEXT, -- Project name
    vorgang_projekt_nummer TEXT,     -- Links to projekte.belegnummer
    vorgang_projekt_typ TEXT,        -- Project type
    import_hash TEXT,                -- For deduplication
    imported_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS termine_mitarbeiter (
    id SERIAL PRIMARY KEY,
    termine_id INTEGER NOT NULL REFERENCES termine(id) ON DELETE CASCADE,
    personalnummer VARCHAR(10),      -- Links to mitarbeiter (NULL for "<diverse>")
    mitarbeiter TEXT,                -- Employee full name
    imported_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for dashboard queries
CREATE INDEX IF NOT EXISTS idx_termine_von       ON termine(von);
CREATE INDEX IF NOT EXISTS idx_termine_status    ON termine(status);
CREATE INDEX IF NOT EXISTS idx_termine_projekt   ON termine(vorgang_projekt_nummer);
CREATE INDEX IF NOT EXISTS idx_termine_geschaeft ON termine(geschaeftspartner);
CREATE INDEX IF NOT EXISTS idx_termine_mitarbeiter ON termine_mitarbeiter(mitarbeiter);
CREATE INDEX IF NOT EXISTS idx_termine_mitarbeiter_pnum ON termine_mitarbeiter(personalnummer);

-- View: appointments linked to projects and employees
CREATE OR REPLACE VIEW v_projekt_termine AS
SELECT
    t.von,
    t.bis,
    t.dauer,
    t.status,
    t.fix,
    t.geschaeftspartner,
    t.einsatzort,
    t.vorgang_projekt_bezeichnung,
    t.vorgang_projekt_nummer,
    tm.mitarbeiter,
    tm.personalnummer
FROM termine t
LEFT JOIN termine_mitarbeiter tm ON t.id = tm.termine_id;

COMMENT ON TABLE termine              IS 'Appointment scheduling rows — source: PDS ERP termine exports (~9640 total across 4 file types)';
COMMENT ON TABLE termine_mitarbeiter  IS 'Junction table: one row per employee per appointment';
COMMENT ON VIEW   v_projekt_termine  IS 'Joined view: appointments with employee assignments and project links';
