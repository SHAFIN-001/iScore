
-- Fix enrollment_requests table to include paid_by_user_id column

-- Add the missing paid_by_user_id column
ALTER TABLE enrollment_requests 
ADD COLUMN IF NOT EXISTS paid_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add the missing paid_by column (referenced in tutor payment)
ALTER TABLE enrollment_requests 
ADD COLUMN IF NOT EXISTS paid_by TEXT;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_enrollment_requests_paid_by_user_id ON enrollment_requests(paid_by_user_id);

-- Update existing records to set paid_by_user_id from student_user_id if paid_by_user_id is null
-- This is a fallback for existing records where the student paid for themselves
UPDATE enrollment_requests 
SET paid_by_user_id = student_user_id 
WHERE paid_by_user_id IS NULL;

-- Verify the schema
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'enrollment_requests' 
AND table_schema = 'public'
ORDER BY ordinal_position;
