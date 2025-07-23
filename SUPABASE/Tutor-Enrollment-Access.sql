
-- Allow tutors to see enrollment status of their connected students
CREATE POLICY "Tutors can view their students' enrollment status" ON student_enrollment
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tutor_additional_info tai
            WHERE tai.user_id = auth.uid() 
            AND student_enrollment.user_id = ANY(tai.students)
        )
    );

-- Also allow tutors to enroll their students (for direct enrollment)
CREATE POLICY "Tutors can enroll their students" ON student_enrollment
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM tutor_additional_info tai
            WHERE tai.user_id = auth.uid() 
            AND student_enrollment.user_id = ANY(tai.students)
        )
    );

-- Allow tutors to update enrollment status for their students
CREATE POLICY "Tutors can update their students' enrollment" ON student_enrollment
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM tutor_additional_info tai
            WHERE tai.user_id = auth.uid() 
            AND student_enrollment.user_id = ANY(tai.students)
        )
    );
