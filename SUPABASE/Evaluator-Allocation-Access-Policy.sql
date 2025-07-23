
-- Enable RLS on evaluator_allocation table
ALTER TABLE evaluator_allocation ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Tutors can view their evaluator allocations" ON evaluator_allocation;
DROP POLICY IF EXISTS "Admins can manage evaluator allocations" ON evaluator_allocation;

-- Allow tutors to view their own evaluator allocations
CREATE POLICY "Tutors can view their evaluator allocations" ON evaluator_allocation
    FOR SELECT
    TO authenticated
    USING (evaluator_id = auth.uid());

-- Allow admins to manage all evaluator allocations
CREATE POLICY "Admins can manage evaluator allocations" ON evaluator_allocation
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_information
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Grant necessary permissions
GRANT SELECT ON evaluator_allocation TO authenticated;
GRANT ALL ON evaluator_allocation TO service_role;
