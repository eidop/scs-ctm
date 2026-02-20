-- ══════════════════════════════════════════════════════════════
-- SCS CTM Platform — Supabase Schema
-- Run in Supabase SQL Editor (or via migration)
-- ══════════════════════════════════════════════════════════════

-- ┌──────────────────────────────────────────────────────────┐
-- │  EXTENSIONS                                              │
-- └──────────────────────────────────────────────────────────┘
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ┌──────────────────────────────────────────────────────────┐
-- │  ENUMS                                                   │
-- └──────────────────────────────────────────────────────────┘
CREATE TYPE user_role AS ENUM ('admin', 'client');
CREATE TYPE client_status AS ENUM ('aktiv', 'pauset', 'arkivert');
CREATE TYPE agent_status AS ENUM ('aktiv', 'pauset', 'feil');
CREATE TYPE tier_level AS ENUM ('1', '2', '3');
CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
CREATE TYPE voice_provider AS ENUM ('VAPI', 'ElevenLabs', 'Twilio');
CREATE TYPE agent_tone AS ENUM ('Profesjonell', 'Vennlig', 'Uformell', 'Teknisk');

-- ┌──────────────────────────────────────────────────────────┐
-- │  TIERS (reference table)                                 │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE tiers (
    id              INTEGER PRIMARY KEY,
    name            VARCHAR(20) NOT NULL,        -- Liten, Medium, Stor
    max_agents      INTEGER NOT NULL,            -- 5, 10, 20
    icon            VARCHAR(10) NOT NULL,
    color           VARCHAR(20) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO tiers (id, name, max_agents, icon, color) VALUES
    (1, 'Liten',  5,  '⚡', 'var(--t1)'),
    (2, 'Medium', 10, '🚀', 'var(--t2)'),
    (3, 'Stor',   20, '🏆', 'var(--t3)');

-- ┌──────────────────────────────────────────────────────────┐
-- │  USERS (auth-linked)                                     │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id         UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email           VARCHAR(255) UNIQUE NOT NULL,
    role            user_role NOT NULL DEFAULT 'client',
    display_name    VARCHAR(100),
    avatar_url      VARCHAR(500),
    company         VARCHAR(200),
    is_active       BOOLEAN DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  CLIENTS                                                 │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE clients (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(200) NOT NULL,
    bransje         VARCHAR(100),               -- industry/sector
    tier_id         INTEGER REFERENCES tiers(id) DEFAULT 1,
    status          client_status DEFAULT 'aktiv',
    contact_name    VARCHAR(200),
    contact_email   VARCHAR(255),
    contact_phone   VARCHAR(50),
    
    -- Financials
    avtale_kr       INTEGER DEFAULT 0,          -- monthly agreement NOK
    besparing_kr    INTEGER DEFAULT 0,          -- estimated savings NOK
    
    -- API limits
    api_kost_kr     NUMERIC(10,2) DEFAULT 0,    -- current API cost NOK
    api_grense_kr   NUMERIC(10,2) DEFAULT 0,    -- API cost limit NOK
    
    -- Voice config
    voice_provider  voice_provider DEFAULT 'VAPI',
    
    -- General knowledge (shared across all agents for this client)
    general_knowledge TEXT DEFAULT '',
    
    -- Webhook
    webhook_url     VARCHAR(500),
    
    -- Avatar/display
    avatar_letter   CHAR(1),
    avatar_color    VARCHAR(20) DEFAULT '#2f8bff',
    
    -- Supabase/n8n config per client
    n8n_url         VARCHAR(500),
    
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  CLIENT_USERS (join table: which users belong to which   │
-- │  client, supports multiple users per client)             │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE client_users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    is_primary      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, user_id)
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  CLIENT_API_KEYS (stored encrypted, per-client keys)     │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE client_api_keys (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    key_type        VARCHAR(50) NOT NULL,        -- openai, vapi, elevenlabs, twilio_sid, twilio_token, hubspot
    key_value       TEXT NOT NULL,               -- encrypted in production
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, key_type)
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  AGENTS                                                  │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE agents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    name            VARCHAR(200) NOT NULL,
    emoji           VARCHAR(10) DEFAULT '🤖',
    bg_color        VARCHAR(50) DEFAULT 'rgba(47,139,255,0.1)',
    channels        VARCHAR(200),               -- 'Gmail · HubSpot', etc.
    status          agent_status DEFAULT 'aktiv',
    
    -- Config
    tone            agent_tone DEFAULT 'Profesjonell',
    greeting        TEXT DEFAULT '',
    knowledge       TEXT DEFAULT '',             -- agent-specific knowledge
    client_knowledge TEXT DEFAULT '',            -- client-editable knowledge
    client_feedback TEXT DEFAULT '',             -- client feedback/notes
    webhook_url     VARCHAR(500),
    voice_name      VARCHAR(100) DEFAULT 'Sofia',
    
    -- Stats (denormalized for fast reads, updated via triggers/cron)
    total_actions   INTEGER DEFAULT 0,
    success_rate    NUMERIC(5,2) DEFAULT 0,
    
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  AGENT_ACTIONS (activity log per agent)                  │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE agent_actions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID REFERENCES agents(id) ON DELETE CASCADE,
    client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
    action_type     VARCHAR(50) NOT NULL,        -- email_sent, call_made, lead_captured, ticket_resolved, etc.
    description     TEXT,
    metadata        JSONB DEFAULT '{}',          -- flexible data (email subject, phone number, etc.)
    success         BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  API_COSTS (daily cost tracking per client)              │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE api_costs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    date            DATE NOT NULL DEFAULT CURRENT_DATE,
    provider        VARCHAR(50) NOT NULL,        -- openai, vapi, elevenlabs, twilio
    model           VARCHAR(100),                -- gpt-4o, whisper, etc.
    tokens_in       INTEGER DEFAULT 0,
    tokens_out      INTEGER DEFAULT 0,
    calls           INTEGER DEFAULT 0,
    cost_usd        NUMERIC(10,4) DEFAULT 0,
    cost_nok        NUMERIC(10,2) DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, date, provider, model)
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  INVOICES (fakturering)                                  │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE invoices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
    invoice_number  VARCHAR(50) UNIQUE,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    avtale_kr       NUMERIC(10,2) DEFAULT 0,
    api_cost_kr     NUMERIC(10,2) DEFAULT 0,
    total_kr        NUMERIC(10,2) DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'usendt',  -- usendt, sendt, betalt, forfalt
    due_date        DATE,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  SUPPORT_TICKETS                                         │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE support_tickets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    subject         VARCHAR(300) NOT NULL,
    description     TEXT,
    status          ticket_status DEFAULT 'open',
    priority        INTEGER DEFAULT 2,           -- 1=high, 2=medium, 3=low
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  SUPPORT_MESSAGES (thread on a ticket)                   │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE support_messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id       UUID REFERENCES support_tickets(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    message         TEXT NOT NULL,
    is_admin        BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  AUDIT_LOG (admin activity log)                          │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(100) NOT NULL,       -- login, client_created, agent_paused, settings_changed, etc.
    target_type     VARCHAR(50),                 -- client, agent, user, settings
    target_id       UUID,
    details         JSONB DEFAULT '{}',
    ip_address      INET,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  INTEGRATIONS (connected services per client)            │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE integrations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
    service         VARCHAR(100) NOT NULL,       -- gmail, hubspot, n8n, vapi, twilio, etc.
    status          VARCHAR(20) DEFAULT 'disconnected',  -- connected, disconnected, error
    config          JSONB DEFAULT '{}',          -- service-specific config
    last_sync       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, service)
);

-- ┌──────────────────────────────────────────────────────────┐
-- │  SCS_SETTINGS (global platform settings)                 │
-- └──────────────────────────────────────────────────────────┘
CREATE TABLE scs_settings (
    key             VARCHAR(100) PRIMARY KEY,
    value           JSONB NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO scs_settings (key, value) VALUES
    ('supabase_url', '""'),
    ('n8n_base_url', '""'),
    ('default_voice_provider', '"VAPI"'),
    ('usd_to_nok_rate', '10.5'),
    ('ai_act_article4_enabled', 'true');


-- ══════════════════════════════════════════════════════════════
-- INDEXES
-- ══════════════════════════════════════════════════════════════

CREATE INDEX idx_agent_actions_agent      ON agent_actions(agent_id, created_at DESC);
CREATE INDEX idx_agent_actions_client     ON agent_actions(client_id, created_at DESC);
CREATE INDEX idx_agent_actions_type       ON agent_actions(action_type);
CREATE INDEX idx_api_costs_client_date    ON api_costs(client_id, date DESC);
CREATE INDEX idx_invoices_client          ON invoices(client_id, period_start DESC);
CREATE INDEX idx_support_tickets_client   ON support_tickets(client_id, status);
CREATE INDEX idx_audit_log_user           ON audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_log_target         ON audit_log(target_type, target_id);
CREATE INDEX idx_agents_client            ON agents(client_id);
CREATE INDEX idx_client_users_user        ON client_users(user_id);
CREATE INDEX idx_client_users_client      ON client_users(client_id);


-- ══════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════════════════════

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

-- Helper: get user role from auth
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
    SELECT role FROM users WHERE auth_id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: get client_ids for current user
CREATE OR REPLACE FUNCTION get_user_client_ids()
RETURNS SETOF UUID AS $$
    SELECT cu.client_id 
    FROM client_users cu 
    JOIN users u ON u.id = cu.user_id 
    WHERE u.auth_id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── USERS ──
CREATE POLICY "Admins see all users" ON users
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Users see own profile" ON users
    FOR SELECT USING (auth_id = auth.uid());

-- ── CLIENTS ──
CREATE POLICY "Admins manage all clients" ON clients
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own client" ON clients
    FOR SELECT USING (id IN (SELECT get_user_client_ids()));

-- ── CLIENT_USERS ──
CREATE POLICY "Admins manage client_users" ON client_users
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Users see own memberships" ON client_users
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ── CLIENT_API_KEYS ──
CREATE POLICY "Admins manage api keys" ON client_api_keys
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users manage own keys" ON client_api_keys
    FOR ALL USING (client_id IN (SELECT get_user_client_ids()));

-- ── AGENTS ──
CREATE POLICY "Admins manage all agents" ON agents
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own agents" ON agents
    FOR SELECT USING (client_id IN (SELECT get_user_client_ids()));
CREATE POLICY "Client users update own agents" ON agents
    FOR UPDATE USING (client_id IN (SELECT get_user_client_ids()))
    WITH CHECK (client_id IN (SELECT get_user_client_ids()));

-- ── AGENT_ACTIONS ──
CREATE POLICY "Admins see all actions" ON agent_actions
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own actions" ON agent_actions
    FOR SELECT USING (client_id IN (SELECT get_user_client_ids()));

-- ── API_COSTS ──
CREATE POLICY "Admins see all costs" ON api_costs
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own costs" ON api_costs
    FOR SELECT USING (client_id IN (SELECT get_user_client_ids()));

-- ── INVOICES ──
CREATE POLICY "Admins manage invoices" ON invoices
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own invoices" ON invoices
    FOR SELECT USING (client_id IN (SELECT get_user_client_ids()));

-- ── SUPPORT_TICKETS ──
CREATE POLICY "Admins manage all tickets" ON support_tickets
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users manage own tickets" ON support_tickets
    FOR ALL USING (client_id IN (SELECT get_user_client_ids()));

-- ── SUPPORT_MESSAGES ──
CREATE POLICY "Admins see all messages" ON support_messages
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own ticket messages" ON support_messages
    FOR SELECT USING (
        ticket_id IN (
            SELECT id FROM support_tickets 
            WHERE client_id IN (SELECT get_user_client_ids())
        )
    );
CREATE POLICY "Client users create messages on own tickets" ON support_messages
    FOR INSERT WITH CHECK (
        ticket_id IN (
            SELECT id FROM support_tickets 
            WHERE client_id IN (SELECT get_user_client_ids())
        )
    );

-- ── AUDIT_LOG ──
CREATE POLICY "Only admins see audit log" ON audit_log
    FOR ALL USING (get_user_role() = 'admin');

-- ── INTEGRATIONS ──
CREATE POLICY "Admins manage integrations" ON integrations
    FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Client users see own integrations" ON integrations
    FOR SELECT USING (client_id IN (SELECT get_user_client_ids()));


-- ══════════════════════════════════════════════════════════════
-- FUNCTIONS & TRIGGERS
-- ══════════════════════════════════════════════════════════════

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_users_updated      BEFORE UPDATE ON users      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_clients_updated    BEFORE UPDATE ON clients    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_agents_updated     BEFORE UPDATE ON agents     FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_tickets_updated    BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_integrations_updated BEFORE UPDATE ON integrations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update agent stats (total_actions, success_rate) after new action
CREATE OR REPLACE FUNCTION update_agent_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents SET
        total_actions = (SELECT COUNT(*) FROM agent_actions WHERE agent_id = NEW.agent_id),
        success_rate = (
            SELECT COALESCE(
                ROUND(100.0 * COUNT(*) FILTER (WHERE success = TRUE) / NULLIF(COUNT(*), 0), 2),
                0
            )
            FROM agent_actions WHERE agent_id = NEW.agent_id
        )
    WHERE id = NEW.agent_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_agent_action_stats
    AFTER INSERT ON agent_actions
    FOR EACH ROW EXECUTE FUNCTION update_agent_stats();

-- Update client api_kost_kr when costs change
CREATE OR REPLACE FUNCTION update_client_api_cost()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE clients SET
        api_kost_kr = (
            SELECT COALESCE(SUM(cost_nok), 0) 
            FROM api_costs 
            WHERE client_id = NEW.client_id
            AND date >= date_trunc('month', CURRENT_DATE)
        )
    WHERE id = NEW.client_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_api_cost_update
    AFTER INSERT OR UPDATE ON api_costs
    FOR EACH ROW EXECUTE FUNCTION update_client_api_cost();


-- ══════════════════════════════════════════════════════════════
-- VIEWS (for dashboard queries)
-- ══════════════════════════════════════════════════════════════

-- Admin dashboard overview
CREATE OR REPLACE VIEW v_admin_dashboard AS
SELECT
    (SELECT COUNT(*) FROM clients WHERE status = 'aktiv') AS active_clients,
    (SELECT COUNT(*) FROM agents WHERE status = 'aktiv') AS active_agents,
    (SELECT COALESCE(SUM(avtale_kr), 0) FROM clients WHERE status = 'aktiv') AS total_mrr,
    (SELECT COALESCE(SUM(besparing_kr), 0) FROM clients WHERE status = 'aktiv') AS total_besparing,
    (SELECT COUNT(*) FROM agent_actions WHERE created_at >= CURRENT_DATE) AS actions_today,
    (SELECT COUNT(*) FROM agent_actions WHERE created_at >= CURRENT_DATE AND action_type = 'lead_captured') AS leads_today,
    (SELECT COALESCE(SUM(api_kost_kr), 0) FROM clients) AS total_api_cost;

-- Client summary (for clients table)
CREATE OR REPLACE VIEW v_client_summary AS
SELECT
    c.id,
    c.name,
    c.bransje,
    c.tier_id,
    t.name AS tier_name,
    t.max_agents,
    c.status,
    c.contact_name,
    c.contact_email,
    c.avtale_kr,
    c.besparing_kr,
    c.api_kost_kr,
    c.api_grense_kr,
    c.avatar_letter,
    c.avatar_color,
    c.created_at,
    (SELECT COUNT(*) FROM agents a WHERE a.client_id = c.id AND a.status = 'aktiv') AS agent_count,
    (SELECT COALESCE(SUM(a.total_actions), 0) FROM agents a WHERE a.client_id = c.id) AS total_actions,
    CASE
        WHEN c.avtale_kr > 0 THEN ROUND(c.besparing_kr::NUMERIC / c.avtale_kr, 1)
        ELSE 0
    END AS roi
FROM clients c
JOIN tiers t ON t.id = c.tier_id;

-- Agent overview with client info
CREATE OR REPLACE VIEW v_agent_overview AS
SELECT
    a.*,
    c.name AS client_name,
    c.avatar_color AS client_color
FROM agents a
JOIN clients c ON c.id = a.client_id;


-- ══════════════════════════════════════════════════════════════
-- SEED DATA (demo clients, agents, actions)
-- ══════════════════════════════════════════════════════════════

-- Demo clients
INSERT INTO clients (name, bransje, tier_id, status, contact_name, contact_email, avtale_kr, besparing_kr, api_kost_kr, api_grense_kr, voice_provider, avatar_letter, avatar_color) VALUES
    ('Regnskap AS',    'Regnskap',      2, 'aktiv', 'Kari Holm',    'kari@regnskap.no',      11900,  52000,  1840, 2500, 'VAPI',        'R', '#2f8bff'),
    ('Eiendom Nord',   'Eiendom',       1, 'aktiv', 'Lars Berg',    'lars@eiendomnord.no',   8500,   31000,  3120, 2500, 'ElevenLabs',  'E', '#00e5a0'),
    ('Tech Solutions', 'Teknologi',     3, 'aktiv', 'Hege Larsen',  'hege@techsolutions.no', 34000,  198000, 8950, 9500, 'VAPI',        'T', '#f59e0b'),
    ('Handel Butikk',  'Detaljhandel',  1, 'aktiv', 'Per Olsen',    'per@handel.no',         7200,   24000,  680,  1500, 'VAPI',        'H', '#ff6b35'),
    ('Juss Partners',  'Juridisk',      2, 'aktiv', 'Anne Moe',     'anne@juss.no',          18500,  74000,  2100, 3000, 'VAPI',        'J', '#9d60fb'),
    ('Klinikk Vest',   'Helse',         1, 'aktiv', 'Dr. Strand',   'post@klinikkvest.no',   6800,   19500,  920,  1500, 'VAPI',        'K', '#00e5a0'),
    ('Finans Nord',    'Finans',        2, 'aktiv', 'Tor Bakke',    'tor@finansnord.no',     22000,  89000,  4200, 4000, 'VAPI',        'F', '#2f8bff'),
    ('Logistikk AS',   'Transport',     1, 'aktiv', 'Eva Dahl',     'eva@logistikk.no',      5500,   14000,  440,  1000, 'VAPI',        'L', '#ff6b35'),
    ('Media Group',    'Media',         2, 'aktiv', 'Nils Vik',     'nils@mediagroup.no',    15000,  55000,  1750, 2500, 'VAPI',        'M', '#9d60fb'),
    ('Hotell Nord',    'Reiseliv',      1, 'aktiv', 'Ida Fjeld',    'ida@hotellnord.no',     9200,   27000,  1100, 2000, 'VAPI',        'H', '#f59e0b'),
    ('Startup Lab',    'Teknologi',     1, 'aktiv', 'Kim Lie',      'kim@startuplab.no',     4800,   12000,  310,  800,  'VAPI',        'S', '#00e5a0'),
    ('Bygg Sør AS',    'Bygg',          2, 'aktiv', 'Ole Sund',     'ole@byggsor.no',        9900,   32000,  850,  2000, 'VAPI',        'B', '#ff6b35');

-- Demo agents (referencing clients by name — use subqueries)
INSERT INTO agents (client_id, name, emoji, bg_color, channels, status, tone, greeting, voice_name, total_actions, success_rate) VALUES
    ((SELECT id FROM clients WHERE name='Regnskap AS'),    'Email Support',  '📬', 'rgba(0,229,160,0.1)',  'Gmail · HubSpot',     'aktiv', 'Profesjonell', '',                                        'Sofia', 412,  96.00),
    ((SELECT id FROM clients WHERE name='Eiendom Nord'),   'Voice Agent',    '📞', 'rgba(47,139,255,0.1)', 'VAPI · HubSpot',      'aktiv', 'Vennlig',      'Hei! Du har ringt Eiendom Nord.',         'Sofia', 58,   91.00),
    ((SELECT id FROM clients WHERE name='Regnskap AS'),    'Lead Capture',   '🎯', 'rgba(255,107,53,0.1)', 'Email · CRM',         'aktiv', 'Profesjonell', '',                                        'Sofia', 777,  88.00),
    ((SELECT id FROM clients WHERE name='Eiendom Nord'),   'Booking Bot',    '📅', 'rgba(157,96,251,0.1)', 'Website · Email',     'aktiv', 'Vennlig',      '',                                        'Sofia', 22,   93.00),
    ((SELECT id FROM clients WHERE name='Eiendom Nord'),   'Social Agent',   '📱', 'rgba(245,158,11,0.1)', 'Instagram · FB',      'aktiv', 'Uformell',     '',                                        'Sofia', 14,   85.00),
    ((SELECT id FROM clients WHERE name='Eiendom Nord'),   'CRM Sync',       '🏢', 'rgba(0,229,160,0.1)',  'HubSpot',             'aktiv', 'Teknisk',      '',                                        'Sofia', 31,   99.00),
    ((SELECT id FROM clients WHERE name='Eiendom Nord'),   'Review Bot',     '⭐', 'rgba(47,139,255,0.1)', 'Google · Trustpilot', 'aktiv', 'Vennlig',      '',                                        'Sofia', 7,    100.00),
    ((SELECT id FROM clients WHERE name='Tech Solutions'), 'Enterprise AI',  '⚡', 'rgba(245,158,11,0.1)', 'Multi-kanal',         'aktiv', 'Profesjonell', '',                                        'Sofia', 1842, 97.00),
    ((SELECT id FROM clients WHERE name='Tech Solutions'), 'API Agent',      '🔗', 'rgba(157,96,251,0.1)', 'REST · Webhook',      'aktiv', 'Teknisk',      '',                                        'Sofia', 621,  99.00),
    ((SELECT id FROM clients WHERE name='Tech Solutions'), 'Data Enricher',  '📊', 'rgba(255,107,53,0.1)', 'CRM · DB',            'aktiv', 'Profesjonell', '',                                        'Sofia', 312,  95.00);


-- ══════════════════════════════════════════════════════════════
-- DONE! 
-- Tables: 14 | Views: 3 | Functions: 5 | Triggers: 7
-- RLS policies: 18 | Indexes: 11
-- ══════════════════════════════════════════════════════════════
