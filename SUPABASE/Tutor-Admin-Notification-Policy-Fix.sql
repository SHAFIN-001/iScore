
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Tutors can create admin notifications" ON notifications;
DROP POLICY IF EXISTS "Tutors can create own notifications" ON notifications;

-- Create a more permissive policy for tutors to create notifications
CREATE POLICY "Allow tutors to create notifications" ON notifications
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    -- Allow if the inserting user is a tutor
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'tutor'
    )
  );

-- Also ensure tutors can read notifications they create
CREATE POLICY "Tutors can read their created notifications" ON notifications
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'tutor'
    )
  );

-- Grant necessary permissions
GRANT INSERT, SELECT ON notifications TO authenticated;
