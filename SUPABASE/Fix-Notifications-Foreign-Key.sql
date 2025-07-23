
-- Fix notifications table foreign key relationship
-- Drop policies first, then alter column type, then recreate policies and foreign key

-- Step 1: Drop existing RLS policies that depend on user_id column
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
DROP POLICY IF EXISTS "Admins can view all notifications" ON notifications;
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Admins can update notifications" ON notifications;
DROP POLICY IF EXISTS "Admins can delete notifications" ON notifications;

-- Step 2: Alter the column type
ALTER TABLE notifications 
ALTER COLUMN user_id TYPE UUID USING user_id::UUID;

-- Step 3: Add the foreign key constraint
ALTER TABLE notifications 
ADD CONSTRAINT fk_notifications_user_id 
FOREIGN KEY (user_id) REFERENCES user_information(user_id)
ON DELETE CASCADE;

-- Step 4: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Step 5: Recreate RLS policies
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT 
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own notifications" ON notifications
  FOR INSERT 
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE 
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE 
  TO authenticated
  USING (user_id = auth.uid());

-- Admin policies for notifications
CREATE POLICY "Admins can view all notifications" ON notifications
  FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update notifications" ON notifications
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

CREATE POLICY "Admins can delete notifications" ON notifications
  FOR DELETE 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Step 6: Force schema cache reload
NOTIFY pgrst, 'reload schema';

-- Step 7: Verify the constraint was added
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name='notifications';
