
-- Function to refresh PostgREST schema cache
CREATE OR REPLACE FUNCTION refresh_schema_cache()
RETURNS text AS $$
BEGIN
  -- Notify PostgREST to reload the schema
  NOTIFY pgrst, 'reload schema';
  RETURN 'Schema cache refresh initiated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to anon and authenticated roles
GRANT EXECUTE ON FUNCTION refresh_schema_cache() TO anon;
GRANT EXECUTE ON FUNCTION refresh_schema_cache() TO authenticated;

-- Alternative approach: Create a simple function that forces schema reload
CREATE OR REPLACE FUNCTION force_schema_reload()
RETURNS boolean AS $$
BEGIN
  -- This is a workaround that forces PostgREST to re-examine the schema
  -- by creating and dropping a temporary function
  EXECUTE 'CREATE OR REPLACE FUNCTION temp_schema_refresh_' || extract(epoch from now())::text || '() RETURNS void AS $f$ BEGIN NULL; END; $f$ LANGUAGE plpgsql;';
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION force_schema_reload() TO anon;
GRANT EXECUTE ON FUNCTION force_schema_reload() TO authenticated;
