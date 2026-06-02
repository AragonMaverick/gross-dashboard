-- Table for time tracking / hours evaluation exports
-- Source file: pds export stundenauswertung [year].csv

CREATE TABLE IF NOT EXISTS mitarbeiter (
    personalnummer VARCHAR(10) PRIMARY KEY,  -- Employee number (e.g., "279", "84")
    name TEXT NOT NULL                        -- Employee full name
);

CREATE TABLE IF NOT EXISTS stundenauswertung (
    id SERIAL PRIMARY KEY,

      -- Date & time
    tag DATE,                                -- Day of the entry
    wochentag TEXT,                         -- Day of week (Montag, Dienstag, etc.)
    von_zeit TIME,                          -- Start time (e.g., "07:00")
    bis_zeit TIME,                          -- End time (e.g., "15:00")
    ende_datum DATE,                        -- End date (for multi-day entries)

      -- Employee (FK)
    personalnummer VARCHAR(10),            -- Links to mitarbeiter(personalnummer)

      -- Time tracking
    arbeitszeit NUMERIC(10,2),            -- Working hours
    pausenzeit NUMERIC(10,2),             -- Break hours
    zeitabzug_min NUMERIC(10,2),          -- Time deduction in minutes

      -- Wage type
    lohnart_bezzeichnung TEXT,             -- Description (Arbeitsstunden, Feiertag, Urlaub, Krank, etc.)
    lohnart_nr TEXT,                      -- Wage type number (110, 205, 300, 400, 461, 462, etc.)
    produktivitaet TEXT,                  -- Productivity flag (Produktiv/Nicht-Produktiv)

      -- Financials
    satz NUMERIC(12,3),                  -- Rate per hour
    summe_satz NUMERIC(14,3),           -- Total (arbeitszeit * satz)
    faktor NUMERIC(12,3),                -- Factor/hourly rate
    summe_faktor NUMERIC(14,3),         -- Factor sum (arbeitszeit * faktor)
    gesamtwert NUMERIC(14,3),           -- Grand total
    betrag NUMERIC(14,3),              -- Flat amount (e.g., Notdienstpauschale)
    aufschlag NUMERIC(14,3),            -- Surcharge rate
    aufschlag_summe NUMERIC(14,3),      -- Surcharge total

      -- Project linkage
    kst_ktr TEXT,                       -- Cost center / rate code
    vorgang_projektakte TEXT,           -- Project description
    vorgangsnummer TEXT,                -- Links to projekte.belegnummer
    vorgang_projekttyp TEXT,            -- Type (Serviceauftrag, etc.)

      -- Details
    buchungskategorie TEXT,              -- Booking category (Ohne Auftrag, etc.)
    meldungstyp TEXT,                   -- Message type (Fahrt, Beginn, etc.)
    meldungstext TEXT,                  -- Message / location
    bemerkung TEXT,                     -- Freeform notes
    kundennummer TEXT,                  -- Customer/vendor number
    menge NUMERIC(10,2),               -- Quantity
    prozent NUMERIC(10,2),             -- Percentage
    gerat TEXT,                       -- Device

     -- Metadata
    import_hash TEXT,                           -- For dedup on reimport
    imported_at TIMESTAMP DEFAULT NOW()
);

-- FK to mitarbeiter
ALTER TABLE stundenauswertung
    ADD CONSTRAINT fk_stunde_mitarbeiter
    FOREIGN KEY (personalnummer) REFERENCES mitarbeiter(personalnummer);

-- Indexes for dashboard queries
CREATE INDEX IF NOT EXISTS idx_stunde_tag         ON stundenauswertung(tag);
CREATE INDEX IF NOT EXISTS idx_stunde_lohnart     ON stundenauswertung(lohnart_bezzeichnung);
CREATE INDEX IF NOT EXISTS idx_stunde_vorgang     ON stundenauswertung(vorgangsnummer);
CREATE INDEX IF NOT EXISTS idx_stunde_kst         ON stundenauswertung(kst_ktr);
CREATE INDEX IF NOT EXISTS idx_stunde_pnum_tag    ON stundenauswertung(personalnummer, tag);

-- View: link hours to projects
CREATE OR REPLACE VIEW v_projekt_stunden AS
SELECT
    s.id,
    s.tag,
    s.wochentag,
    m.name AS mitarbeiter,
    s.arbeitszeit,
    s.summe_faktor,
    s.gesamtwert,
    s.kst_ktr,
    p.belegnummer,
    p.bezeichnung AS projekt_bezeichnung,
    p.projektleiter,
    p.gewerk
FROM stundenauswertung s
-- Link via employee lookup
JOIN mitarbeiter m ON s.personalnummer = m.personalnummer
-- Link via operation number to project
LEFT JOIN projekte p ON s.vorgangsnummer = p.belegnummer;

COMMENT ON TABLE mitarbeiter         IS 'Dim table: employees extracted from stundenauswertung rows';
COMMENT ON TABLE stundenauswertung   IS 'Time tracking rows per employee per day — source: PDS ERP export';
COMMENT ON VIEW   v_projekt_stunden  IS 'Joined view: hours linked to projects for dashboard queries';
