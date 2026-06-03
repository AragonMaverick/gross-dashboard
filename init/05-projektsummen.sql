-- Table for project financial summaries
-- Source files: projektsummen_v2_*.xlsx (3 files: alle, erledigt, offen)
-- 930 total rows (819 completed + 111 open = 930 all)
-- Nr. links to projekte.belegnummer

CREATE TABLE IF NOT EXISTS projektsummen (
    id SERIAL PRIMARY KEY,
    belegnummer VARCHAR(20) UNIQUE NOT NULL REFERENCES projekte(belegnummer) ON DELETE CASCADE,

     -- Project identification
    bezeichnung TEXT,                       -- Project name
    projektleiter TEXT,                    -- Comma-separated project managers
    auftraggeber TEXT,                     -- Client type (Gewerblich, etc.)
    gewerk TEXT,                           -- Trade (Klima, Heizung, Sanitär, etc.)
    baustellenart TEXT,                    -- Site type
    projektstart DATE,                    -- Project start date
    projektende DATE,                     -- Project end date
    kunde TEXT,                            -- Customer name

     -- Calculated (planned) values
    angebote NUMERIC(14,2),              -- Quotes (€)
    auftraege NUMERIC(14,2),             -- Orders (€)
    kalk_stunden NUMERIC(12,3),          -- Calculated hours
    kalk_lohnkosten NUMERIC(14,2),       -- Calculated labor costs
    kalk_lohnkosten_gmk NUMERIC(14,2),   -- Calculated labor overhead
    kalk_materialkosten NUMERIC(14,2),   -- Calculated material costs
    kalk_materialkosten_gmk NUMERIC(14,2), -- Calculated material overhead
    kalk_fremdleistungen NUMERIC(14,2),  -- Calculated subcontracts
    kalk_fremdleistungen_gmk NUMERIC(14,2), -- Calculated subcontract overhead
    kalk_gesamtkosten NUMERIC(14,2),     -- Calculated total costs
    kalk_db_euro NUMERIC(14,2),          -- Calculated margin (€)
    kalk_db_prozent NUMERIC(7,4),        -- Calculated margin (%)

     -- Actual values
    ist_stunden NUMERIC(12,3),           -- Actual hours
    eingangsrechnungen NUMERIC(14,2),    -- Incoming invoices
    lieferscheine NUMERIC(14,2),         -- Delivery notes
    materialkosten NUMERIC(14,2),        -- Actual material costs
    gmk_material NUMERIC(14,2),          -- Actual material overhead
    lohnkosten NUMERIC(14,2),            -- Actual labor costs
    gmk_lohn NUMERIC(14,2),              -- Actual labor overhead
    gesamtkosten NUMERIC(14,2),          -- Actual total costs
    delta_gesamtkosten NUMERIC(14,2),    -- Delta costs vs order value
    abschlagsrechnungen NUMERIC(14,2),   -- Interim invoices
    erloese NUMERIC(14,2),               -- Revenue
    rechnung_netto NUMERIC(14,2),        -- Net invoice
    ue_zu_vollkosten NUMERIC(14,2),      -- Under/overfinancing to full costs
    ue_unterfinanzierung NUMERIC(14,2),  -- Underfinancing amount
    ue_ueberfinanzierung NUMERIC(14,2),  -- Overfinancing amount
    ergebnis NUMERIC(14,2),              -- Result/profit (€)
    ergebnis_prozent NUMERIC(7,4),       -- Result/profit (%)
    status TEXT                          -- Project status: 'erledigt' or 'offen'

     -- Metadata
    ,import_hash TEXT,                    -- For deduplication
    imported_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for dashboard queries
CREATE INDEX IF NOT EXISTS idx_projektsummen_gewerk       ON projektsummen(gewerk);
CREATE INDEX IF NOT EXISTS idx_projektsummen_auftraggeber ON projektsummen(auftraggeber);
CREATE INDEX IF NOT EXISTS idx_projektsummen_kunde        ON projektsummen(kunde);
CREATE INDEX IF NOT EXISTS idx_projektsummen_projektleiter ON projektsummen(projektleiter);
CREATE INDEX IF NOT EXISTS idx_projektsummen_ergebnis     ON projektsummen(ergebnis_prozent);

-- View: project summaries with hours and appointments linked
CREATE OR REPLACE VIEW v_projekt_finanz_sichten AS
SELECT
    p.belegnummer,
    p.bezeichnung,
    p.projektleiter,
    p.gewerk,
    p.auftraggeber,
    ps.angebote,
    ps.auftraege,
    ps.kalk_gesamtkosten,
    ps.kalk_db_euro,
    ps.kalk_db_prozent,
    ps.gesamtkosten,
    ps.erloese,
    ps.rechnung_netto,
    ps.ergebnis,
    ps.ergebnis_prozent,
    ps.projektstart,
    ps.projektende,
    ps.kunde,
    COALESCE(SUM(h.arbeitszeit), 0) AS total_arbeitszeit,
    COALESCE(SUM(h.summe_faktor), 0) AS total_summe_faktor,
    COUNT(DISTINCT t.id) AS termine_geplant
FROM projekte p
LEFT JOIN projektsummen ps ON p.belegnummer = ps.belegnummer
LEFT JOIN (
    SELECT vorgangsnummer, personalnummer, tag, arbeitszeit, summe_faktor
    FROM stundenauswertung
) h ON p.belegnummer = h.vorgangsnummer
LEFT JOIN (
    SELECT id, vorgang_projekt_nummer, von, bis, status
    FROM termine
) t ON p.belegnummer = t.vorgang_projekt_nummer
GROUP BY p.belegnummer, p.bezeichnung, p.projektleiter, p.gewerk,
         p.auftraggeber, ps.angebote, ps.auftraege, ps.kalk_gesamtkosten,
         ps.kalk_db_euro, ps.kalk_db_prozent, ps.gesamtkosten, ps.erloese,
         ps.rechnung_netto, ps.ergebnis, ps.ergebnis_prozent,
         ps.projektstart, ps.projektende, ps.kunde;

COMMENT ON TABLE projektsummen          IS 'Project financial summaries — source: PDS ERP projektsummen exports';
COMMENT ON VIEW   v_projekt_finanz_sichten IS 'Joined view: financials + hours + appointments per project';
