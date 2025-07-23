-- Check if student_enrollment table exists and has the old structure
DO $$
BEGIN
    -- Check if the table exists with old structure (user_id, week_number, enrolled)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'student_enrollment' 
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) THEN
        -- Add missing columns to existing table (skip id if user_id is already primary key)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'id'
            AND table_schema = 'public'
        ) THEN
            -- Only add id column if user_id is not the primary key
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
                WHERE tc.table_name = 'student_enrollment' 
                AND tc.constraint_type = 'PRIMARY KEY'
                AND kcu.column_name = 'user_id'
                AND tc.table_schema = 'public'
            ) THEN
                ALTER TABLE student_enrollment ADD COLUMN id UUID DEFAULT gen_random_uuid() PRIMARY KEY;
            ELSE
                -- user_id is already primary key, just add id as regular column
                ALTER TABLE student_enrollment ADD COLUMN id UUID DEFAULT gen_random_uuid();
            END IF;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'exam_id'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN exam_id UUID;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'enrolled_at'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'payment_status'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed'));
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'enrollment_status'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN enrollment_status TEXT DEFAULT 'active' CHECK (enrollment_status IN ('active', 'inactive', 'cancelled'));
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'created_at'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'student_enrollment' 
            AND column_name = 'updated_at'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;

        -- Add foreign key constraint if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE table_name = 'student_enrollment' 
            AND constraint_name = 'student_enrollment_user_id_fkey'
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE student_enrollment ADD CONSTRAINT student_enrollment_user_id_fkey 
            FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        END IF;

        RAISE NOTICE 'Updated existing student_enrollment table with new columns';
    ELSE
        -- Create new table with proper structure
        CREATE TABLE IF NOT EXISTS student_enrollment (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            exam_id UUID NOT NULL,
            week_number INTEGER NOT NULL,
            enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed')),
            enrollment_status TEXT DEFAULT 'active' CHECK (enrollment_status IN ('active', 'inactive', 'cancelled')),
            enrolled BOOLEAN DEFAULT true,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        RAISE NOTICE 'Created new student_enrollment table';
    END IF;
END $$;

-- Create indexes for better performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_student_enrollment_user_id ON student_enrollment(user_id);
CREATE INDEX IF NOT EXISTS idx_student_enrollment_exam_id ON student_enrollment(exam_id);
CREATE INDEX IF NOT EXISTS idx_student_enrollment_week_number ON student_enrollment(week_number);

-- Enable RLS
ALTER TABLE student_enrollment ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Students can view their own enrollments" ON student_enrollment;
DROP POLICY IF EXISTS "Admins can view all enrollments" ON student_enrollment;
DROP POLICY IF EXISTS "Admins can insert enrollments" ON student_enrollment;
DROP POLICY IF EXISTS "Admins can update enrollments" ON student_enrollment;

-- Create policies using user_id (which exists in your table)
CREATE POLICY "Students can view their own enrollments" ON student_enrollment
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all enrollments" ON student_enrollment
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_information
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can insert enrollments" ON student_enrollment
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_information
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update enrollments" ON student_enrollment
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_information
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Add update trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_student_enrollment_updated_at ON student_enrollment;
CREATE TRIGGER update_student_enrollment_updated_at
    BEFORE UPDATE ON student_enrollment
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create enrollment_requests table
CREATE TABLE IF NOT EXISTS enrollment_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_full_name TEXT NOT NULL,
    student_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_id TEXT NOT NULL,
    bkash_number TEXT NOT NULL,
    screenshot_url TEXT,
    additional_information TEXT,
    exam_name TEXT NOT NULL,
    exam_id UUID NOT NULL,
    week_number INTEGER NOT NULL,
    fee INTEGER NOT NULL,
    pay_number TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES auth.users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejected_by UUID REFERENCES auth.users(id),
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for enrollment_requests
CREATE INDEX IF NOT EXISTS idx_enrollment_requests_student_id ON enrollment_requests(student_user_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_requests_exam_id ON enrollment_requests(exam_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_requests_status ON enrollment_requests(status);

-- Temporarily disable Row Level Security for debugging
ALTER TABLE enrollment_requests DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies to avoid any conflicts
DROP POLICY IF EXISTS "Students can view their own enrollment requests" ON enrollment_requests;
DROP POLICY IF EXISTS "Students can insert their own enrollment requests" ON enrollment_requests;
DROP POLICY IF EXISTS "Allow all authenticated users to insert enrollment requests" ON enrollment_requests;
DROP POLICY IF EXISTS "Admins can view all enrollment requests" ON enrollment_requests;
DROP POLICY IF EXISTS "Admins can update enrollment requests" ON enrollment_requests;
DROP POLICY IF EXISTS "Tutors can view enrollment requests for their students" ON enrollment_requests;
DROP POLICY IF EXISTS "Parents can view enrollment requests for their children" ON enrollment_requests;

-- Note: RLS is disabled for debugging purposes
-- Will be re-enabled once the insertion issue is resolved

CREATE POLICY "Admins can view all enrollment requests" ON enrollment_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_information
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Add update trigger for enrollment_requests
DROP TRIGGER IF EXISTS update_enrollment_requests_updated_at ON enrollment_requests;
CREATE TRIGGER update_enrollment_requests_updated_at
    BEFORE UPDATE ON enrollment_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();