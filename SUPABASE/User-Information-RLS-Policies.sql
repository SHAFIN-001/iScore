-- Enable RLS on user_information table
ALTER TABLE user_information ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies to prevent conflicts
DROP POLICY IF EXISTS "Admins can view all users" ON user_information;
DROP POLICY IF EXISTS "Users can view own information" ON user_information;
DROP POLICY IF EXISTS "Tutors can view other tutors" ON user_information;
DROP POLICY IF EXISTS "Students can view tutors" ON user_information;
DROP POLICY IF EXISTS "Users can insert own information" ON user_information;
DROP POLICY IF EXISTS "Users can update own information" ON user_information;
DROP POLICY IF EXISTS "Admins can insert any user" ON user_information;
DROP POLICY IF EXISTS "Admins can update any user" ON user_information;
DROP POLICY IF EXISTS "Users can view own info" ON user_information;
DROP POLICY IF EXISTS "Admin access" ON user_information;
DROP POLICY IF EXISTS "Students view tutors" ON user_information;
DROP POLICY IF EXISTS "Tutors view others" ON user_information;
DROP POLICY IF EXISTS "Registration inserts" ON user_information;
DROP POLICY IF EXISTS "Own profile access" ON user_information;
DROP POLICY IF EXISTS "Registration insert" ON user_information;
DROP POLICY IF EXISTS "Own profile update" ON user_information;
DROP POLICY IF EXISTS "Students see tutors" ON user_information;
DROP POLICY IF EXISTS "Tutors see students" ON user_information;
DROP POLICY IF EXISTS "Admin full access" ON user_information;

-- SIMPLE NON-RECURSIVE POLICIES

-- Policy 1: Allow users to view their own profile
CREATE POLICY "View own profile" ON user_information
  FOR SELECT 
  TO authenticated
  USING (user_id = auth.uid());

-- Policy 2: Allow users to insert during registration
CREATE POLICY "Insert own profile" ON user_information
  FOR INSERT 
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policy 3: Allow users to update their own profile
CREATE POLICY "Update own profile" ON user_information
  FOR UPDATE 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy 4: Allow public read access to all profiles (no role restrictions)
-- This eliminates the need for role-checking queries that cause recursion
CREATE POLICY "Public profile view" ON user_information
  FOR SELECT 
  TO authenticated
  USING (true);

-- Policy 5: Allow anonymous users to insert during registration (for email verification)
CREATE POLICY "Anonymous registration" ON user_information
  FOR INSERT 
  TO anon
  WITH CHECK (true);