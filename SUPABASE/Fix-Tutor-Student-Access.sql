
-- Fix Tutor Access to Student Information
-- This allows tutors to read information of their assigned students

-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "tutor_student_access" ON user_information;
DROP POLICY IF EXISTS "tutor_student_additional_access" ON student_additional_info;

-- Allow tutors to access their students' basic information
CREATE POLICY "tutor_student_access" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    auth.role() = 'service_role' OR
    -- Allow tutors to read their students' information
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND user_information.user_id = ANY(students)
    ) OR
    -- Allow students to read their tutors' information  
    EXISTS (
      SELECT 1 FROM student_additional_info
      WHERE user_id = auth.uid()
      AND user_information.user_id = ANY(tutors)
    ) OR
    -- Allow parents to read their children's information
    EXISTS (
      SELECT 1 FROM parent_additional_info
      WHERE user_id = auth.uid()
      AND user_information.user_id = ANY(students)
    ) OR
    -- Allow basic read for proctoring assignments
    EXISTS (
      SELECT 1 FROM proctor_allocation
      WHERE proctor_id = auth.uid()
      AND student_id = user_information.user_id
    )
  );

-- Grant necessary permissions
GRANT SELECT ON user_information TO authenticated;
