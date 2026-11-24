-- PostgreSQL 16 Core Schema (CRM Leads + Autonomous DAG Task Queue)

CREATE TABLE IF NOT EXISTS leads (
    id SERIAL PRIMARY KEY,
    external_id TEXT UNIQUE,
    channel TEXT NOT NULL, -- whatsapp, telegram, fiverr, linkedin
    contact_name TEXT,
    company TEXT,
    service_interest TEXT,
    estimated_budget_usd INTEGER,
    status TEXT NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS agent_jobs (
    job_id TEXT PRIMARY KEY,
    owner_agent TEXT NOT NULL, -- e.g. hermes-orchestrator, claude-executor
    dedupe_key TEXT UNIQUE,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued', -- queued, running, needs_review, completed, blocked, dead
    priority INTEGER NOT NULL DEFAULT 5,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    depends_on TEXT REFERENCES agent_jobs(job_id),
    lease_until TIMESTAMPTZ,
    result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_jobs_status_priority
    ON agent_jobs (status, priority DESC, created_at ASC);
