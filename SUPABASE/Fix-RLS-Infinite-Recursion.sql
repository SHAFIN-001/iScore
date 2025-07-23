
-- Fix infinite recursion in RLS policies

-- Drop all problematic policies
DROP POLICY IF EXISTS "Parents can view their children's tutors" ON tutor_additional_info;
DROP POLICY IF EXISTS "Tutors can view their connected parents" ON parent_additional_info;
DROP POLICY IF EXISTS "Students can view their tutors and parents" ON student_additional_info;

-- Create simple, non-recursive policies for parent_additional_info
CREATE POLICY "Parents can manage own info only" ON parent_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Create simple, non-recursive policies for tutor_additional_info
CREATE POLICY "Tutors can manage own info only" ON tutor_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Create simple policy for student_additional_info
CREATE POLICY "Students can manage own info only" ON student_additional_info
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow parents to read their children's basic info (non-recursive)
CREATE POLICY "Parents can view children basic info" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info p
      WHERE p.user_id = auth.uid() 
      AND user_information.user_id = ANY(p.students)
    )
  );

-- Allow parents to read their children's student info (non-recursive)
CREATE POLICY "Parents can view children student info" ON student_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info p
      WHERE p.user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(p.students)
    )
  );

-- Allow tutors to read their students' basic info (non-recursive)
CREATE POLICY "Tutors can view students basic info" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info t
      WHERE t.user_id = auth.uid() 
      AND user_information.user_id = ANY(t.students)
    )
  );

-- Allow tutors to read their students' info (non-recursive)
CREATE POLICY "Tutors can view students info" ON student_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info t
      WHERE t.user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(t.students)
    )
  );

-- Service role policies (for RPC functions)
CREATE POLICY "Service role full access parent" ON parent_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role full access tutor" ON tutor_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role full access student" ON student_additional_info
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);
