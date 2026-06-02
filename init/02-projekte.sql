-- Table for PDS project exports
-- Source file: pds export projekte.csv
-- Unique key: belegnummer (Belegnummer)

CREATE TABLE IF NOT EXISTS projekte (
    id SERIAL PRIMARY KEY,
    belegnummer VARCHAR(20) UNIQUE NOT NULL,  -- Belegnummer (unique document number)

    -- Project info
    bezeichnung TEXT,                          -- Project title/description
    status TEXT,                              -- Status (e.g., "Erledigt")
    bereich TEXT,                             -- Department/area
    gewerk TEXT,                              -- Trade category (Klima, Heizung, Sanitär, etc.)
    auftraggeber TEXT,                        -- Client type (Privat, Gewerblich, Öffentlich)
    standort TEXT,                            -- Location

    -- People
    empfaenger TEXT,                          -- Customer name
    empfaengeranschrift TEXT,                -- Customer address
    lieferanschrift TEXT,                    -- Delivery address
    bearbeiter TEXT,                         -- Handler/processor
    benutzer TEXT,                           -- User
    ansprechpartner TEXT,                    -- Contact person
    projektleiter TEXT,                      -- Project manager
    kundendienst TEXT,                       -- Customer service

    -- References
    externe_nummer TEXT,                     -- External number
    berechnung_projekakte TEXT,             -- Project folder reference
    variante TEXT,                           -- Variant
    kst_ktr VARCHAR(20)                    -- Cost rate identifier (typically = belegnummer)
);

-- Table for project financials
-- Separated from main table to keep numeric types clean and enable aggregation queries

CREATE TABLE IF NOT EXISTS projekte_finanz (
    id SERIAL PRIMARY KEY,
    belegnummer VARCHAR(20) NOT NULL REFERENCES projekte(belegnummer) ON DELETE CASCADE,

    -- Overhead rates (German format "26,000" → stored as 26.000)
    gemeinkostensatz_lohn NUMERIC(12,3),    -- Overhead rate labor
    gemeinkostensatz_material NUMERIC(12,3), -- Overhead rate material

    -- Revenue from Handycraft field (German format "3.506,850" → stored as 3506.850)
    uebertrag_umsatz_handycraft NUMERIC(14,3),

    -- Bonds / guarantees
    gewaehrleistungsbuergschaft TEXT,        -- Warranty bond
    vertragserfueellungsbuergschaften TEXT,  -- Performance bonds
    vorauszahlungsbuergschaft TEXT,          -- Advance payment bond

    -- Metadata
    gueltigkeitszeitraum TEXT,               -- Validity period

    -- Tracking
    imported_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_projekte_gewerk ON projekte(gewerk);
CREATE INDEX IF NOT EXISTS idx_projekte_status ON projekte(status);
CREATE INDEX IF NOT EXISTS idx_projekte_auftraggeber ON projekte(auftraggeber);
CREATE INDEX IF NOT EXISTS idx_projekte_standort ON projekte(standort);
CREATE INDEX IF NOT EXISTS idx_projekte_bearbeiter ON projekte(bearbeiter);

-- Index on belegnummer_finanz for fast joins
CREATE INDEX IF NOT EXISTS idx_projekte_finanz_belegnummer ON projekte_finanz(belegnummer);

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

COMMENT ON TABLE projekte IS 'Imported from PDS ERP via pds export projekte.csv — managed by n8n daily sync';
COMMENT ON TABLE projekte_finanz IS 'Financial subtable for projekte — tracks rates, revenue, and bonds';
