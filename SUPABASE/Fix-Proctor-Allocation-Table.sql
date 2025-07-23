
-- Fix Proctor Allocation Table Structure and RLS Policies
-- This addresses the "Error loading proctor information" issue

-- Drop all existing RLS policies for proctor_allocation table
DROP POLICY IF EXISTS "Admins can insert proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Admins can select proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Admins can update proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Admins can delete proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Tutors can view proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Tutors can insert proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Tutors can update proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Tutors can view own proctor allocation" ON proctor_allocation;
DROP POLICY IF EXISTS "Admin can manage proctor allocations" ON proctor_allocation;
DROP POLICY IF EXISTS "Tutors can view their proctor assignments" ON proctor_allocation;
DROP POLICY IF EXISTS "Students can view their proctor assignments" ON proctor_allocation;

-- Drop the existing table if it exists
DROP TABLE IF EXISTS proctor_allocation CASCADE;

-- Drop the update trigger function if it exists
DROP FUNCTION IF EXISTS update_proctor_allocation_updated_at() CASCADE;

-- Create the proctor_allocation table with correct structure
CREATE TABLE proctor_allocation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_number INTEGER NOT NULL,
    student_id UUID NOT NULL REFERENCES user_information(user_id) ON DELETE CASCADE,
    student_full_name TEXT NOT NULL,
    student_phone TEXT,
    student_location TEXT,
    proctor_id UUID NOT NULL REFERENCES user_information(user_id) ON DELETE CASCADE,
    proctor_full_name TEXT NOT NULL,
    address_qr TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on the table
ALTER TABLE proctor_allocation ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_week_number ON proctor_allocation(week_number);
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_student_id ON proctor_allocation(student_id);
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_proctor_id ON proctor_allocation(proctor_id);

-- Create RLS policies for proctor_allocation

-- Allow admins to manage all proctor allocations
CREATE POLICY "Admin can manage all proctor allocations" ON proctor_allocation
    FOR ALL 
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

-- Allow students to view their own proctor assignments
CREATE POLICY "Students can view their proctor assignments" ON proctor_allocation
    FOR SELECT 
    TO authenticated
    USING (
        student_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow tutors to view their proctor assignments
CREATE POLICY "Tutors can view their proctor assignments" ON proctor_allocation
    FOR SELECT 
    TO authenticated
    USING (
        proctor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow tutors to update their own assignments (for status updates)
CREATE POLICY "Tutors can update their proctor assignments" ON proctor_allocation
    FOR UPDATE 
    TO authenticated
    USING (
        proctor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        proctor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_proctor_allocation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_proctor_allocation_updated_at
    BEFORE UPDATE ON proctor_allocation
    FOR EACH ROW EXECUTE FUNCTION update_proctor_allocation_updated_at();

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON proctor_allocation TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Force schema cache refresh
NOTIFY pgrst, 'reload schema';
