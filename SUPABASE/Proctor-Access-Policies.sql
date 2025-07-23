

-- RLS Policies for Proctor Access to Student Information

-- Enable RLS on relevant tables
ALTER TABLE user_information ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_additional_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE proctor_allocation ENABLE ROW LEVEL SECURITY;

-- Drop existing conflicting policies if they exist
DROP POLICY IF EXISTS "Proctors can view assigned students info" ON user_information;
DROP POLICY IF EXISTS "Proctors can view assigned students additional info" ON student_additional_info;
DROP POLICY IF EXISTS "Tutors can view proctor assignments" ON proctor_allocation;

-- Allow proctors to view basic information of students they are assigned to proctor
CREATE POLICY "Proctors can view assigned students info" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM proctor_allocation 
      WHERE proctor_id = auth.uid() 
      AND student_id = user_information.user_id
    ) OR
    EXISTS (
      SELECT 1 FROM student_additional_info 
      WHERE user_id = user_information.user_id 
      AND auth.uid() = ANY(tutors)
    ) OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND user_information.user_id = ANY(students)
    ) OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND user_information.user_id = ANY(students)
    )
  );

-- Allow proctors to view additional info of students they are assigned to proctor
CREATE POLICY "Proctors can view assigned students additional info" ON student_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM proctor_allocation 
      WHERE proctor_id = auth.uid() 
      AND student_id = student_additional_info.user_id
    ) OR
    auth.uid() = ANY(tutors) OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(students)
    )
  );

-- Allow tutors to view their proctor assignments
CREATE POLICY "Tutors can view proctor assignments" ON proctor_allocation
  FOR SELECT 
  TO authenticated
  USING (
    proctor_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND student_id = ANY(students)
    )
  );

-- Grant necessary permissions
GRANT SELECT ON user_information TO authenticated;
GRANT SELECT ON student_additional_info TO authenticated;
GRANT SELECT ON proctor_allocation TO authenticated;

