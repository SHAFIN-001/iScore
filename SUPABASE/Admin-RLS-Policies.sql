-- Add RLS policies for admin access to icup_exam_metadata table ONLY

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can insert exam metadata" ON icup_exam_metadata;
DROP POLICY IF EXISTS "Admins can select exam metadata" ON icup_exam_metadata;
DROP POLICY IF EXISTS "Admins can update exam metadata" ON icup_exam_metadata;
DROP POLICY IF EXISTS "Students can view exam metadata" ON icup_exam_metadata;
DROP POLICY IF EXISTS "Tutors can view exam metadata" ON icup_exam_metadata;

-- Policy to allow admins to insert exam metadata
CREATE POLICY "Admins can insert exam metadata" ON icup_exam_metadata
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Policy to allow admins to select exam metadata
CREATE POLICY "Admins can select exam metadata" ON icup_exam_metadata
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Policy to allow admins to update exam metadata
CREATE POLICY "Admins can update exam metadata" ON icup_exam_metadata
  FOR UPDATE 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Policy to allow students to view exam metadata
CREATE POLICY "Students can view exam metadata" ON icup_exam_metadata
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'student'
    )
  );

-- Policy to allow tutors to view exam metadata
CREATE POLICY "Tutors can view exam metadata" ON icup_exam_metadata
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'tutor'
    )
  );