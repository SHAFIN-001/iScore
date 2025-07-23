-- Create answer_evaluation table for storing evaluation data
CREATE TABLE IF NOT EXISTS answer_evaluation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    answer_set_id UUID NOT NULL REFERENCES answer_sets(id) ON DELETE CASCADE,
    evaluator_id UUID NOT NULL REFERENCES user_information(user_id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES icup_exam_metadata(exam_id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES user_information(user_id) ON DELETE CASCADE,
    subject VARCHAR(50) NOT NULL,
    
    -- Evaluation data
    evaluated_pictures JSONB DEFAULT '{}', -- SVG annotations and overlay data
    detailed_marks TEXT, -- Comments and feedback
    total_marks DECIMAL(5,2) DEFAULT 0,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Constraints
    UNIQUE(answer_set_id, subject, evaluator_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_answer_evaluation_evaluator ON answer_evaluation(evaluator_id);
CREATE INDEX IF NOT EXISTS idx_answer_evaluation_answer_set ON answer_evaluation(answer_set_id);
CREATE INDEX IF NOT EXISTS idx_answer_evaluation_exam ON answer_evaluation(exam_id);
CREATE INDEX IF NOT EXISTS idx_answer_evaluation_status ON answer_evaluation(status);
CREATE INDEX IF NOT EXISTS idx_answer_evaluation_subject ON answer_evaluation(subject);

-- Enable RLS
ALTER TABLE answer_evaluation ENABLE ROW LEVEL SECURITY;

-- RLS Policy 1: Allow evaluators to manage their own evaluations
CREATE POLICY "evaluators_can_manage_own_evaluations" ON answer_evaluation
    FOR ALL 
    TO authenticated
    USING (evaluator_id = auth.uid())
    WITH CHECK (evaluator_id = auth.uid());

-- RLS Policy 2: Allow admins full access
CREATE POLICY "admins_full_access_evaluations" ON answer_evaluation
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

-- RLS Policy 3: Allow students to view their own evaluation results (read-only)
CREATE POLICY "students_can_view_own_evaluations" ON answer_evaluation
    FOR SELECT 
    TO authenticated
    USING (
        student_id = auth.uid() 
        AND status = 'completed'
    );

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_answer_evaluation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_answer_evaluation_updated_at
    BEFORE UPDATE ON answer_evaluation
    FOR EACH ROW
    EXECUTE FUNCTION update_answer_evaluation_updated_at();

-- Create leaderboard view for current week
CREATE OR REPLACE VIEW current_week_leaderboard AS
WITH student_totals AS (
    SELECT 
        ae.student_id,
        ae.exam_id,
        ui.full_name,
        ui.class_level,
        SUM(ae.total_marks) as total_score,
        COUNT(DISTINCT ae.subject) as subjects_evaluated,
        ARRAY_AGG(
            JSON_BUILD_OBJECT(
                'subject', ae.subject,
                'marks', ae.total_marks
            )
        ) as subject_scores
    FROM answer_evaluation ae
    JOIN user_information ui ON ae.student_id = ui.user_id
    JOIN icup_exam_metadata iem ON ae.exam_id = iem.exam_id
    WHERE ae.status = 'completed'
    AND iem.is_archived = false
    GROUP BY ae.student_id, ae.exam_id, ui.full_name, ui.class_level
)
SELECT 
    student_id,
    exam_id,
    full_name,
    class_level,
    total_score,
    subjects_evaluated,
    subject_scores,
    RANK() OVER (ORDER BY total_score DESC) as overall_rank,
    RANK() OVER (PARTITION BY class_level ORDER BY total_score DESC) as class_rank
FROM student_totals
ORDER BY total_score DESC;

-- Grant necessary permissions
GRANT SELECT ON current_week_leaderboard TO authenticated;
GRANT ALL ON answer_evaluation TO authenticated;

COMMENT ON TABLE answer_evaluation IS 'Stores evaluation data including annotations, marks, and feedback for student answer sets';
COMMENT ON COLUMN answer_evaluation.evaluated_pictures IS 'JSON object containing SVG annotations and overlay data for each image';
COMMENT ON COLUMN answer_evaluation.detailed_marks IS 'Comments and detailed feedback from the evaluator';
COMMENT ON COLUMN answer_evaluation.total_marks IS 'Total marks awarded for the subject evaluation';