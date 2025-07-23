-- Create evaluator eligibility table
CREATE TABLE IF NOT EXISTS evaluator_eligibility (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tutor_id UUID REFERENCES user_information(user_id) ON DELETE CASCADE,
    tutor_full_name TEXT NOT NULL,
    preferred_subjects TEXT[] NOT NULL,
    enabled BOOLEAN DEFAULT false,
    status VARCHAR(20) DEFAULT 'pending',
    request_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(tutor_id)
);

-- Create updated_at trigger for evaluator_eligibility
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_evaluator_eligibility_updated_at ON evaluator_eligibility;
CREATE TRIGGER update_evaluator_eligibility_updated_at
    BEFORE UPDATE ON evaluator_eligibility
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies for evaluator_eligibility
ALTER TABLE evaluator_eligibility ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can manage evaluator eligibility" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Tutors can view their own eligibility" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Tutors can insert their own request" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Tutors can update their own request" ON evaluator_eligibility;

-- Allow admins full access to evaluator eligibility
CREATE POLICY "Admins can manage evaluator eligibility" ON evaluator_eligibility
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

-- Allow tutors to view their own evaluator eligibility status
CREATE POLICY "Tutors can view their own eligibility" ON evaluator_eligibility
    FOR SELECT 
    TO authenticated
    USING (tutor_id = auth.uid());

-- Allow tutors to insert their own evaluator request
CREATE POLICY "Tutors can insert their own request" ON evaluator_eligibility
    FOR INSERT 
    TO authenticated
    WITH CHECK (tutor_id = auth.uid());

-- Allow tutors to update their own evaluator request (but not enabled status)
CREATE POLICY "Tutors can update their own request" ON evaluator_eligibility
    FOR UPDATE 
    TO authenticated
    USING (tutor_id = auth.uid())
    WITH CHECK (tutor_id = auth.uid());