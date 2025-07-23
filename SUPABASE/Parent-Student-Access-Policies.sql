
-- RLS Policies for Parent Access to Student Data

-- Enable RLS on user_information if not already enabled
ALTER TABLE user_information ENABLE ROW LEVEL SECURITY;

-- Drop existing parent access policies if they exist
DROP POLICY IF EXISTS "Parents can view their children" ON user_information;
DROP POLICY IF EXISTS "Parents can view their children's info" ON student_additional_info;

-- Allow parents to view their children's basic information
CREATE POLICY "Parents can view their children" ON user_information
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND user_information.user_id = ANY(students)
    )
  );

-- Allow parents to view their children's additional student info
CREATE POLICY "Parents can view their children's info" ON student_additional_info
  FOR SELECT 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND student_additional_info.user_id = ANY(students)
    )
  );

-- Grant necessary permissions
GRANT SELECT ON user_information TO authenticated;
GRANT SELECT ON student_additional_info TO authenticated;
GRANT SELECT ON parent_additional_info TO authenticated;
