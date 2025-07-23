
-- Fix infinite recursion in user_information RLS policies
-- This file addresses the circular reference issue preventing tutor loading

-- Disable RLS temporarily to make changes
ALTER TABLE user_information DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies that might cause recursion
DROP POLICY IF EXISTS "Users can view their own information" ON user_information;
DROP POLICY IF EXISTS "admin_can_view_tutors_for_evaluation" ON user_information;
DROP POLICY IF EXISTS "Admins can view all users" ON user_information;
DROP POLICY IF EXISTS "Users can update their own information" ON user_information;
DROP POLICY IF EXISTS "Admins can manage all users" ON user_information;
DROP POLICY IF EXISTS "Allow authenticated users to read their own data" ON user_information;
DROP POLICY IF EXISTS "Allow users to read their own profile" ON user_information;

-- Re-enable RLS
ALTER TABLE user_information ENABLE ROW LEVEL SECURITY;

-- Create simple, non-recursive policies
-- Policy 1: Users can view their own record
CREATE POLICY "user_can_view_own_record" ON user_information
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Policy 2: Admin users can view all records (using direct auth.uid() check)
CREATE POLICY "admin_can_view_all_users" ON user_information
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
        OR user_id = auth.uid()
    );

-- Policy 3: Users can update their own record
CREATE POLICY "user_can_update_own_record" ON user_information
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Policy 4: Admin users can insert new records
CREATE POLICY "admin_can_insert_users" ON user_information
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Policy 5: Admin users can update all records
CREATE POLICY "admin_can_update_all_users" ON user_information
    FOR UPDATE
    TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Alternative approach: Create a function to check admin status without recursion
CREATE OR REPLACE FUNCTION is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_information 
        WHERE user_id = auth.uid() AND role = 'admin'
    );
$$;

-- Drop the recursive policies and create new ones using the function
DROP POLICY IF EXISTS "admin_can_view_all_users" ON user_information;
DROP POLICY IF EXISTS "admin_can_insert_users" ON user_information;
DROP POLICY IF EXISTS "admin_can_update_all_users" ON user_information;

-- Create new admin policies using the function
CREATE POLICY "admin_view_all_users" ON user_information
    FOR SELECT
    TO authenticated
    USING (is_admin_user() OR user_id = auth.uid());

CREATE POLICY "admin_insert_users" ON user_information
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin_user());

CREATE POLICY "admin_update_all_users" ON user_information
    FOR UPDATE
    TO authenticated
    USING (is_admin_user())
    WITH CHECK (is_admin_user());

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON user_information TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin_user TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
