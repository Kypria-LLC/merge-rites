
-- Complete database schema for the automated Patreon social media funnel
-- Run this in your Supabase SQL editor

-- Create extensions schema and required extensions
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA extensions;

-- Social campaigns table (main content tracking)
CREATE TABLE IF NOT EXISTS public.social_campaigns (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  campaign_name text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('facebook', 'instagram', 'youtube', 'twitter')),
  post_content text NOT NULL,
  utm_params jsonb DEFAULT '{}',
  scheduled_date timestamp with time zone NOT NULL,
  posted_date timestamp with time zone,
  engagement_metrics jsonb DEFAULT '{}',
  short_link text,
  status text DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'posted', 'failed', 'cancelled')),
  optimal_score numeric(10,4) DEFAULT 0.0000,
  created_at timestamp with time zone DEFAULT now()
);

-- Automation logs table
CREATE TABLE IF NOT EXISTS public.automation_logs (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  log_uuid uuid DEFAULT extensions.uuid_generate_v4(),
  function_name text NOT NULL,
  execution_date timestamp with time zone NOT NULL,
  posts_scheduled integer DEFAULT 0,
  posts_failed integer DEFAULT 0,
  details jsonb DEFAULT '{}',
  created_at timestamp with time zone DEFAULT now()
);

-- Patron milestones table for milestone automation
CREATE TABLE IF NOT EXISTS public.patron_milestones (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  milestone_type text CHECK (milestone_type IN ('patron_count', 'revenue', 'technical')),
  threshold integer NOT NULL,
  current_value integer DEFAULT 0,
  achieved_date timestamp with time zone,
  auto_posted boolean DEFAULT false,
  platforms jsonb DEFAULT '["facebook","instagram","youtube","twitter"]',
  created_at timestamp with time zone DEFAULT now()
);

-- CTA variants for A/B testing
CREATE TABLE IF NOT EXISTS public.cta_variants (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  variant_text text NOT NULL UNIQUE,
  usage_count integer DEFAULT 0,
  conversion_rate numeric(5,4) DEFAULT 0.0000,
  created_at timestamp with time zone DEFAULT now()
);

-- Scheduled jobs table for cron integration
CREATE TABLE IF NOT EXISTS public.scheduled_jobs (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  job_name text NOT NULL,
  payload jsonb DEFAULT '{}',
  scheduled_at timestamp with time zone NOT NULL,
  executed_at timestamp with time zone,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  result jsonb,
  created_at timestamp with time zone DEFAULT now()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_social_campaigns_platform ON public.social_campaigns(platform);
CREATE INDEX IF NOT EXISTS idx_social_campaigns_scheduled_date ON public.social_campaigns(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_social_campaigns_status ON public.social_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_social_campaigns_engagement ON public.social_campaigns USING GIN (engagement_metrics);
CREATE INDEX IF NOT EXISTS idx_automation_logs_function_date ON public.automation_logs(function_name, execution_date);
CREATE INDEX IF NOT EXISTS idx_automation_logs_execution_date ON public.automation_logs(execution_date);
CREATE INDEX IF NOT EXISTS idx_patron_milestones_threshold ON public.patron_milestones(threshold);
CREATE INDEX IF NOT EXISTS idx_patron_milestones_posted ON public.patron_milestones(auto_posted);
CREATE INDEX IF NOT EXISTS idx_scheduled_jobs_status ON public.scheduled_jobs(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_jobs_scheduled_at ON public.scheduled_jobs(scheduled_at);

-- Insert default data
INSERT INTO public.cta_variants (variant_text) VALUES
  ('Join the Sacred Circle'),
  ('Enter the Shrine'),
  ('Unlock the Mysteries'),
  ('Access Sacred Knowledge'),
  ('Begin the Convergence')
ON CONFLICT (variant_text) DO NOTHING;

INSERT INTO public.patron_milestones (milestone_type, threshold) VALUES 
  ('patron_count', 10),
  ('patron_count', 25),
  ('patron_count', 50),
  ('patron_count', 100),
  ('patron_count', 250),
  ('patron_count', 500),
  ('patron_count', 1000)
ON CONFLICT DO NOTHING;

-- Enable Row Level Security
ALTER TABLE public.social_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patron_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cta_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_jobs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for service role access
CREATE POLICY "Service role full access" ON public.social_campaigns
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON public.automation_logs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON public.patron_milestones
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON public.cta_variants
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON public.scheduled_jobs
  FOR ALL USING (auth.role() = 'service_role');
