
-- Add parents column to tutor_additional_info table if it doesn't exist

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tutor_additional_info' 
        AND column_name = 'parents'
    ) THEN
        ALTER TABLE tutor_additional_info 
        ADD COLUMN parents UUID[] DEFAULT '{}';
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_tutor_additional_info_parents 
ON tutor_additional_info USING GIN (parents);
