
-- RLS Policies for Parent Access to Enrollment Data

-- Allow parents to view enrollment status of their children
CREATE POLICY "Parents can view their children's enrollment status" ON student_enrollment
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM parent_additional_info pai
            WHERE pai.user_id = auth.uid() 
            AND student_enrollment.user_id = ANY(pai.students)
        )
    );

-- Allow parents to enroll their children via enrollment requests
CREATE POLICY "Parents can create enrollment requests for their children" ON enrollment_requests
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM parent_additional_info pai
            WHERE pai.user_id = auth.uid() 
            AND enrollment_requests.student_user_id = ANY(pai.students)
        )
    );

-- Allow parents to view their enrollment requests
CREATE POLICY "Parents can view their enrollment requests" ON enrollment_requests
    FOR SELECT USING (
        paid_by_user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM parent_additional_info pai
            WHERE pai.user_id = auth.uid() 
            AND enrollment_requests.student_user_id = ANY(pai.students)
        )
    );

-- Allow parents to view exam metadata (needed for payment pages)
CREATE POLICY "Parents can view exam metadata" ON icup_exam_metadata
    FOR SELECT USING (true);

-- Grant necessary permissions
GRANT SELECT ON student_enrollment TO authenticated;
GRANT SELECT, INSERT ON enrollment_requests TO authenticated;
GRANT SELECT ON icup_exam_metadata TO authenticated;
