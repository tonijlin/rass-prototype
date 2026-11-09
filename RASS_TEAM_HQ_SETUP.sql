-- RASS! Team HQ: read-only private hazard feed.
-- Run in Supabase SQL Editor as project administrator.
-- Does not modify existing hazard data, publication status, or guest policies.

CREATE OR REPLACE FUNCTION public.rass_team_review_hazards()
RETURNS TABLE (
  id uuid,
  latitude double precision,
  longitude double precision,
  hazard_type text,
  classification text,
  status text,
  created_at timestamptz,
  excluded_from_publication boolean,
  report_count bigint,
  gps_accuracy_m double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR NOT (SELECT public.rass_is_team_member()) THEN
    RAISE EXCEPTION 'RASS Team authorization required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT h.id,
         h.latitude::double precision,
         h.longitude::double precision,
         h.hazard_type::text,
         h.classification::text,
         h.status::text,
         h.created_at::timestamptz,
         COALESCE(h.excluded_from_publication, false),
         (SELECT count(*) FROM public.rass_reports r WHERE r.hazard_id = h.id),
         (SELECT r.gps_accuracy_m::double precision
          FROM public.rass_reports r
          WHERE r.hazard_id = h.id
          ORDER BY r.created_at DESC, r.id DESC
          LIMIT 1)
  FROM public.rass_hazards h
  ORDER BY h.created_at DESC
  LIMIT 2000;
END;
$function$;

REVOKE ALL ON FUNCTION public.rass_team_review_hazards() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rass_team_review_hazards() FROM anon;
GRANT EXECUTE ON FUNCTION public.rass_team_review_hazards() TO authenticated;

-- Verification (read-only):
SELECT pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef AS security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
WHERE p.oid = 'public.rass_team_review_hazards()'::regprocedure;
