-- RLS Policies for Student-Tutor Connections

-- Enable RLS on additional info tables
ALTER TABLE student_additional_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE tutor_additional_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_additional_info ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies to prevent conflicts
DROP POLICY IF EXISTS "Students can manage own info" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can read connected students" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can manage own info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Students can read connected tutors" ON tutor_additional_info;
DROP POLICY IF EXISTS "Parents can manage own info" ON parent_additional_info;
DROP POLICY IF EXISTS "Service role can modify student info" ON student_additional_info;
DROP POLICY IF EXISTS "Service role can modify tutor info" ON tutor_additional_info;
DROP POLICY IF EXISTS "Service role can modify parent info" ON parent_additional_info;
DROP POLICY IF EXISTS "Tutors can update student connections during registration" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can create student info during registration" ON student_additional_info;
DROP POLICY IF EXISTS "Students can read connected tutors" ON tutor_additional_info;

-- SIMPLE NON-RECURSIVE POLICIES

-- Student additional info policies
CREATE POLICY "Students can manage own info" ON student_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow service role full access (for RPC functions)
CREATE POLICY "Service role can modify student info" ON student_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Tutor additional info policies  
CREATE POLICY "Tutors can manage own info" ON tutor_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow service role full access (for RPC functions)
CREATE POLICY "Service role can modify tutor info" ON tutor_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Parent additional info policies
CREATE POLICY "Parents can manage own info" ON parent_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow service role full access (for RPC functions)
CREATE POLICY "Service role can modify parent info" ON parent_additional_info
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