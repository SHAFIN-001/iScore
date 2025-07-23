
-- Add hidden column to notifications table
ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS hidden BOOLEAN DEFAULT FALSE;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_hidden ON notifications(user_id, hidden);

-- Update existing notifications to set hidden = false
UPDATE notifications SET hidden = FALSE WHERE hidden IS NULL;
