
-- Drop existing table and all dependencies
DROP TABLE IF EXISTS answer_sets CASCADE;

-- Create answer_sets table for storing uploaded answer papers grouped by subjects
CREATE TABLE answer_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES icup_exam_metadata(exam_id),
    student_id UUID NOT NULL REFERENCES user_information(user_id),
    proctor_id UUID NOT NULL REFERENCES user_information(user_id),
    week_number INTEGER NOT NULL,
    
    -- Subject-wise answer images storage (URLs as text arrays)
    physics_images TEXT[] DEFAULT '{}',
    chemistry_images TEXT[] DEFAULT '{}',
    math_images TEXT[] DEFAULT '{}',
    biology_images TEXT[] DEFAULT '{}',
    
    -- Metadata
    upload_status TEXT DEFAULT 'pending' CHECK (upload_status IN ('pending', 'uploading', 'completed', 'failed')),
    total_images_count INTEGER DEFAULT 0,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_answer_sets_exam_id ON answer_sets(exam_id);
CREATE INDEX idx_answer_sets_student_id ON answer_sets(student_id);
CREATE INDEX idx_answer_sets_proctor_id ON answer_sets(proctor_id);
CREATE INDEX idx_answer_sets_week_number ON answer_sets(week_number);

-- Enable RLS
ALTER TABLE answer_sets ENABLE ROW LEVEL SECURITY;

-- RLS Policy 1: Allow proctors to insert answer sets for their assigned students
CREATE POLICY "proctors_can_upload_answer_sets" ON answer_sets
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        proctor_id = auth.uid()
    );

-- RLS Policy 2: Allow proctors to view and update their uploaded answer sets
CREATE POLICY "proctors_can_manage_answer_sets" ON answer_sets
    FOR ALL 
    TO authenticated
    USING (proctor_id = auth.uid())
    WITH CHECK (proctor_id = auth.uid());

-- RLS Policy 3: Allow students to view their own answer sets
CREATE POLICY "students_can_view_own_answer_sets" ON answer_sets
    FOR SELECT 
    TO authenticated
    USING (student_id = auth.uid());

-- RLS Policy 4: Allow tutors to view answer sets for evaluation
CREATE POLICY "tutors_can_view_for_evaluation" ON answer_sets
    FOR SELECT 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'tutor'
        )
    );

-- RLS Policy 5: Allow admins full access
CREATE POLICY "admins_full_access" ON answer_sets
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
