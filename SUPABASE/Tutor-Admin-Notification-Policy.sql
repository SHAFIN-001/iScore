
-- Allow tutors to create notifications for admins
CREATE POLICY "Tutors can create admin notifications" ON notifications
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    -- Allow if the inserting user is a tutor
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'tutor'
    )
    AND
    -- And the notification is being created for an admin
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_information.user_id = notifications.user_id AND role = 'admin'
    )
  );

-- Also allow tutors to create notifications for themselves
CREATE POLICY "Tutors can create own notifications" ON notifications
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'tutor'
    )
    AND user_id = auth.uid()
  );
