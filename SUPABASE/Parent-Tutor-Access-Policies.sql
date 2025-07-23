
-- RLS Policies for Parent-Tutor Access

-- Enable RLS on tutor_additional_info if not already enabled
ALTER TABLE tutor_additional_info ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Parents can view their children's tutors" ON tutor_additional_info;
DROP POLICY IF EXISTS "Tutors can view their connected parents" ON tutor_additional_info;

-- Allow parents to view their children's tutors information
CREATE POLICY "Parents can view their children's tutors" ON tutor_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND tutor_additional_info.user_id = ANY(tutors)
    )
  );

-- Allow tutors to view parents connected through students
CREATE POLICY "Tutors can view their connected parents" ON parent_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND parent_additional_info.user_id = ANY(parents)
    )
  );

-- Update existing student policies to include parent access
DROP POLICY IF EXISTS "Students can view their tutors and parents" ON student_additional_info;
CREATE POLICY "Students can view their tutors and parents" ON student_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(students)
    ) OR
    EXISTS (
      SELECT 1 FROM tutor_additional_info 
      WHERE user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(students)
    )
  );

-- Grant necessary permissions
GRANT SELECT ON tutor_additional_info TO authenticated;
GRANT SELECT ON parent_additional_info TO authenticated;
