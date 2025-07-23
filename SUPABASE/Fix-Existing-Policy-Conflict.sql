
-- Fix policy conflict - Drop existing policies before creating new ones
-- This handles the case where policies already exist

-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "own_profile_access" ON user_information;
DROP POLICY IF EXISTS "tutor_student_access" ON user_information;
DROP POLICY IF EXISTS "public_profile_view" ON user_information;
DROP POLICY IF EXISTS "view_own_profile" ON user_information;
DROP POLICY IF EXISTS "insert_own_profile" ON user_information;
DROP POLICY IF EXISTS "update_own_profile" ON user_information;

-- Create clean policies for user_information
CREATE POLICY "users_own_profile_access" ON user_information
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow tutors to access their students' basic information
CREATE POLICY "tutors_student_access" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    auth.role() = 'service_role' OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND user_information.user_id = ANY(students)
    ) OR
    EXISTS (
      SELECT 1 FROM student_additional_info
      WHERE user_id = auth.uid()
      AND user_information.user_id = ANY(tutors)
    ) OR
    EXISTS (
      SELECT 1 FROM parent_additional_info
      WHERE user_id = auth.uid()
      AND user_information.user_id = ANY(students)
    ) OR
    EXISTS (
      SELECT 1 FROM proctor_allocation
      WHERE proctor_id = auth.uid()
      AND student_id = user_information.user_id
    )
  );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON user_information TO authenticated;
