
-- Create proctor_allocation table for managing student-tutor proctor assignments
CREATE TABLE IF NOT EXISTS proctor_allocation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_number INTEGER NOT NULL,
    student_id UUID NOT NULL REFERENCES user_information(user_id),
    student_full_name TEXT NOT NULL,
    proctor_id UUID NOT NULL REFERENCES user_information(user_id),
    proctor_full_name TEXT NOT NULL,
    address_qr TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_week_number ON proctor_allocation(week_number);
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_student_id ON proctor_allocation(student_id);
CREATE INDEX IF NOT EXISTS idx_proctor_allocation_proctor_id ON proctor_allocation(proctor_id);

-- Enable RLS
ALTER TABLE proctor_allocation ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Admin can manage proctor allocations" ON proctor_allocation
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Tutors can view their proctor assignments" ON proctor_allocation
    FOR SELECT USING (
        proctor_id = auth.uid()
    );

CREATE POLICY "Students can view their proctor assignments" ON proctor_allocation
    FOR SELECT USING (
        student_id = auth.uid()
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
