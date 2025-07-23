
-- Enable RLS on notifications table if not already enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing parent notification policies if they exist
DROP POLICY IF EXISTS "Parents can create notifications" ON notifications;
DROP POLICY IF EXISTS "Parents can view their notifications" ON notifications;
DROP POLICY IF EXISTS "Parents can update their notifications" ON notifications;

-- Allow parents to create notifications (for payment submissions)
CREATE POLICY "Parents can create notifications" ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    )
  );

-- Allow parents to view their own notifications
CREATE POLICY "Parents can view their notifications" ON notifications
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    )
  );

-- Allow parents to update their own notifications (mark as read, hide, etc.)
CREATE POLICY "Parents can update their notifications" ON notifications
  FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    )
  );

-- Grant necessary permissions to authenticated users
GRANT INSERT, SELECT, UPDATE ON notifications TO authenticated;

-- Allow parents to insert into enrollment_requests table
DROP POLICY IF EXISTS "Parents can create enrollment requests" ON enrollment_requests;

CREATE POLICY "Parents can create enrollment requests" ON enrollment_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    )
  );

-- Allow parents to view enrollment requests for their children
DROP POLICY IF EXISTS "Parents can view children enrollment requests" ON enrollment_requests;

CREATE POLICY "Parents can view children enrollment requests" ON enrollment_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM parent_additional_info 
      WHERE user_id = auth.uid() 
      AND enrollment_requests.student_user_id = ANY(students)
    )
  );

-- Grant necessary permissions for enrollment_requests
GRANT INSERT, SELECT ON enrollment_requests TO authenticated;

-- Allow parents to insert into icup_enrollment_requests table if it exists
DO $$ 
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'icup_enrollment_requests') THEN
    -- Drop existing policies
    DROP POLICY IF EXISTS "Parents can create icup enrollment requests" ON icup_enrollment_requests;
    DROP POLICY IF EXISTS "Parents can view children icup enrollment requests" ON icup_enrollment_requests;
    
    -- Create new policies
    CREATE POLICY "Parents can create icup enrollment requests" ON icup_enrollment_requests
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM user_information 
          WHERE user_id = auth.uid() 
          AND role = 'parent'
        )
      );

    CREATE POLICY "Parents can view children icup enrollment requests" ON icup_enrollment_requests
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM parent_additional_info 
          WHERE user_id = auth.uid() 
          AND icup_enrollment_requests.student_user_id = ANY(students)
        )
      );

    -- Grant permissions
    GRANT INSERT, SELECT ON icup_enrollment_requests TO authenticated;
  END IF;
END $$;
