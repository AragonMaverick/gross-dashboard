-- Table for PDS project exports
-- Source file: pds export projekte.csv
-- Unique key: belegnummer (Belegnummer)
-- All 28 CSV columns included in single table

CREATE TABLE IF NOT EXISTS projekte (
    id SERIAL PRIMARY KEY,
    belegnummer VARCHAR(20) UNIQUE NOT NULL,  -- Belegnummer (unique document number)

    -- 28 CSV columns (all from pds export projekte.csv)
    bezeichnung TEXT,                          -- Bezeichnung (project title/description)
    empfaenger TEXT,                           -- Empfaenger (customer name)
    empfaengeranschrift TEXT,                  -- Empfaengeranschrift (customer address)
    bearbeiter TEXT,                           -- Bearbeiter (handler/processor)
    -- belegnummer already defined above
    lieferanschrift TEXT,                      -- Lieferanschrift (delivery address)
    status TEXT,                               -- Status (e.g., "Erledigt")
    status2 TEXT,                              -- Status (column 28, often empty)
    benutzer TEXT,                             -- Benutzer (user)
    bereich TEXT,                              -- Bereich (department/area)
    erstell_info TEXT,                         -- Erstell-Info (creation info)
    ansprechpartner TEXT,                      -- Ansprechpartner (contact person)
    externe_nummer TEXT,                       -- Externe Nummer (external number)
    projektleiter TEXT,                        -- Projektleiter (project manager)
    auftraggeber TEXT,                         -- Auftraggeber (client type)
    gewerk TEXT,                               -- Gewerk (trade category)
    kundendienst TEXT,                         -- Kundendienst (customer service)
    standort TEXT,                             -- Standort (location)
    berechnung_projekakte TEXT,                -- Berechnung Projektakte (project folder ref)
    variante TEXT,                             -- Variante (variant)
    kst_ktr VARCHAR(20),                       -- KST/KTR (cost rate identifier)
    gemeinkostensatz_lohn NUMERIC(12,3),       -- Gemeinkostensatz Lohn (overhead rate labor)
    gemeinkostensatz_material NUMERIC(12,3),    -- Gemeinkostensatz Material (overhead rate material)
    gewaehrleistungsbuergschaft TEXT,           -- Gewaehrleistungsbuergschaft (warranty bond)
    gueltigkeitszeitraum TEXT,                  -- Gueltigkeitszeitraum (validity period)
    uebertrag_umsatz_handycraft NUMERIC(14,3),  -- Uebertrag Umsatz aus Handycraft (handycraft revenue)
    vertragserfueellungsbuergschaften TEXT,      -- Vertragserfueellungsbuergschaften (performance bonds)
    vorauszahlungsbuergschaft TEXT              -- Vorauszahlungsbuergschaft (advance payment bond)
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_projekte_gewerk ON projekte(gewerk);
CREATE INDEX IF NOT EXISTS idx_projekte_status ON projekte(status);
CREATE INDEX IF NOT EXISTS idx_projekte_auftraggeber ON projekte(auftraggeber);
CREATE INDEX IF NOT EXISTS idx_projekte_standort ON projekte(standort);
CREATE INDEX IF NOT EXISTS idx_projekte_bearbeiter ON projekte(bearbeiter);

-- Function to parse German numeric format (e.g., "3.506,850" → 3506.850)
CREATE OR REPLACE FUNCTION parse_german_number(text_value TEXT)
RETURNS NUMERIC AS $$
BEGIN
    -- Remove periods (thousands separator), replace comma with period (decimal separator)
    IF text_value IS NULL OR trim(text_value) = '' THEN
        RETURN NULL;
    END IF;
    RETURN replace(regexp_replace(trim(text_value), '\.', '', 'g'), ',', '.')::NUMERIC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE projekte IS 'Imported from PDS ERP via pds export projekte.csv — managed by n8n daily sync (all 28 CSV columns, single table)';
