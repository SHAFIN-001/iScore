-- Admin access policies for evaluator eligibility and evaluation allocation

-- Enable RLS on evaluation_allocation table if not already enabled
ALTER TABLE evaluation_allocation ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can manage evaluation allocation" ON evaluation_allocation;
DROP POLICY IF EXISTS "Admins can view all evaluator eligibility" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Admins can insert evaluator eligibility" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Admins can update evaluator eligibility" ON evaluator_eligibility;
DROP POLICY IF EXISTS "Admins can delete evaluator eligibility" ON evaluator_eligibility;

-- Allow admins full access to evaluation_allocation table
CREATE POLICY "Admins can manage evaluation allocation" ON evaluation_allocation
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

-- Allow admins to view all evaluator eligibility records
CREATE POLICY "Admins can view all evaluator eligibility" ON evaluator_eligibility
    FOR SELECT 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow admins to insert evaluator eligibility records
CREATE POLICY "Admins can insert evaluator eligibility" ON evaluator_eligibility
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow admins to update evaluator eligibility records
CREATE POLICY "Admins can update evaluator eligibility" ON evaluator_eligibility
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

-- Allow admins to delete evaluator eligibility records
CREATE POLICY "Admins can delete evaluator eligibility" ON evaluator_eligibility
    FOR DELETE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Grant necessary permissions to authenticated users (admins)
GRANT ALL ON evaluation_allocation TO authenticated;
GRANT ALL ON evaluator_eligibility TO authenticated;

-- Admin Evaluator Access Policies for Evaluation Allocation

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "admin_can_view_all_tutors" ON user_information;
DROP POLICY IF EXISTS "admin_can_view_tutors_for_evaluation" ON user_information;
DROP POLICY IF EXISTS "admin_can_manage_evaluation_allocation" ON evaluation_allocation;

-- Allow admins to view all users including tutors for evaluation allocation
CREATE POLICY "admin_can_view_tutors_for_evaluation" ON user_information
    FOR SELECT
    TO authenticated
    USING (
        -- Admin can see all users
        EXISTS (
            SELECT 1 FROM user_information admin_check
            WHERE admin_check.user_id = auth.uid() 
            AND admin_check.role = 'admin'
        )
        OR 
        -- Or user can see their own record
        user_id = auth.uid()
    );