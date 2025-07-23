
-- Fix infinite recursion in additional info tables

-- Disable RLS temporarily
ALTER TABLE student_additional_info DISABLE ROW LEVEL SECURITY;
ALTER TABLE tutor_additional_info DISABLE ROW LEVEL SECURITY;
ALTER TABLE parent_additional_info DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Students can manage own info" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can manage own info" ON tutor_additional_info;  
DROP POLICY IF EXISTS "Parents can manage own info" ON parent_additional_info;
DROP POLICY IF EXISTS "Service role can modify student info" ON student_additional_info;
DROP POLICY IF EXISTS "Service role can modify tutor info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Service role can modify parent info" ON parent_additional_info;
DROP POLICY IF EXISTS "Parents can view children student info" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can view students info" ON student_additional_info;
DROP POLICY IF EXISTS "Parents can view their children's tutors" ON tutor_additional_info;

-- Re-enable RLS
ALTER TABLE student_additional_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE tutor_additional_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_additional_info ENABLE ROW LEVEL SECURITY;

-- Create simple, non-recursive policies for student_additional_info
CREATE POLICY "student_own_info" ON student_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "student_service_access" ON student_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create simple, non-recursive policies for tutor_additional_info
CREATE POLICY "tutor_own_info" ON tutor_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "tutor_service_access" ON tutor_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create simple, non-recursive policies for parent_additional_info
CREATE POLICY "parent_own_info" ON parent_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "parent_service_access" ON parent_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant permissions
GRANT ALL ON student_additional_info TO authenticated, service_role;
GRANT ALL ON tutor_additional_info TO authenticated, service_role;
GRANT ALL ON parent_additional_info TO authenticated, service_role;
