-- Fix RLS policies for parent registration
-- Allow authenticated users to update student and tutor info during parent registration

-- Drop all existing policies to prevent duplicates
DROP POLICY IF EXISTS "Students can manage own info" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can manage own info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Parents can manage own info" ON parent_additional_info;
DROP POLICY IF EXISTS "Users can manage own student info" ON student_additional_info;
DROP POLICY IF EXISTS "Users can manage own tutor info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Users can manage own parent info" ON parent_additional_info;
DROP POLICY IF EXISTS "Allow parent registration updates to students" ON student_additional_info;
DROP POLICY IF EXISTS "Allow parent registration updates to tutors" ON tutor_additional_info;
DROP POLICY IF EXISTS "Allow upsert into student info" ON student_additional_info;
DROP POLICY IF EXISTS "Service role full access student" ON student_additional_info;
DROP POLICY IF EXISTS "Service role full access tutor" ON tutor_additional_info;
DROP POLICY IF EXISTS "Service role full access parent" ON parent_additional_info;
DROP POLICY IF EXISTS "Allow authenticated users to update student info" ON student_additional_info;
DROP POLICY IF EXISTS "Allow authenticated users to update tutor info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Allow authenticated users to insert student info" ON student_additional_info;
DROP POLICY IF EXISTS "Allow authenticated users to insert tutor info" ON tutor_additional_info;

-- Create comprehensive policies for all operations
CREATE POLICY "Allow authenticated users to manage student info" ON student_additional_info
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to manage tutor info" ON tutor_additional_info
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to manage parent info" ON parent_additional_info
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Service role policies for RPC functions
CREATE POLICY "Service role full access student" ON student_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role full access tutor" ON tutor_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role full access parent" ON parent_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Grant necessary permissions
GRANT ALL ON student_additional_info TO authenticated;
GRANT ALL ON tutor_additional_info TO authenticated;
GRANT ALL ON parent_additional_info TO authenticated;
GRANT ALL ON student_additional_info TO service_role;
GRANT ALL ON tutor_additional_info TO service_role;
GRANT ALL ON parent_additional_info TO service_role;