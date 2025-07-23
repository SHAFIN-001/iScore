
-- Add missing status column to evaluator_eligibility table if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'evaluator_eligibility' 
                   AND column_name = 'status') THEN
        ALTER TABLE evaluator_eligibility ADD COLUMN status VARCHAR(20) DEFAULT 'pending';
    END IF;
END $$;

-- Add missing exam_name column to icup_exam_metadata table if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'icup_exam_metadata' 
                   AND column_name = 'exam_name') THEN
        ALTER TABLE icup_exam_metadata ADD COLUMN exam_name VARCHAR(255);
        -- Update existing rows with a default name based on exam_type
        UPDATE icup_exam_metadata SET exam_name = COALESCE(exam_type, 'ICUP Exam') WHERE exam_name IS NULL;
    END IF;
END $$;
