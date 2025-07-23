
-- Fix RLS policies for user_information table
-- Use user_id consistently instead of id

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "Users can read own profile" ON user_information;
DROP POLICY IF EXISTS "Users can update own profile" ON user_information;
DROP POLICY IF EXISTS "Users can insert own profile during registration" ON user_information;
DROP POLICY IF EXISTS "Students can read own profile" ON user_information;
DROP POLICY IF EXISTS "Students can update own profile" ON user_information;

-- Temporarily disable RLS to clean up
ALTER TABLE user_information DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE user_information ENABLE ROW LEVEL SECURITY;

-- Create fresh RLS policies using user_id with explicit type casting
-- Allow inserts for authenticated users during registration
CREATE POLICY "Users can insert own profile during registration"
ON user_information FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow anonymous users to insert during registration (for email confirmation flow)
CREATE POLICY "Anonymous users can insert during registration"
ON user_information FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "Users can read own profile"
ON user_information FOR SELECT
TO authenticated, anon
USING (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Users can update own profile"
ON user_information FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Force PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';

-- Verify table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'user_information' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Verify RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'user_information';

-- Create a simple test function to verify schema cache
CREATE OR REPLACE FUNCTION test_schema_cache()
RETURNS TABLE(table_name text, column_name text, data_type text) AS $$
BEGIN
    RETURN QUERY
    SELECT t.table_name::text, c.column_name::text, c.data_type::text
    FROM information_schema.tables t
    JOIN information_schema.columns c ON t.table_name = c.table_name
    WHERE t.table_name = 'user_information'
    AND t.table_schema = 'public'
    ORDER BY c.ordinal_position;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION test_schema_cache() TO anon;
GRANT EXECUTE ON FUNCTION test_schema_cache() TO authenticated;
