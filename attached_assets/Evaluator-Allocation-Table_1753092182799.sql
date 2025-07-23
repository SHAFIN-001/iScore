-- ===============================
-- 📊 Evaluator Allocation Table (Per Exam)
-- ===============================

-- Drop existing tables if they exist
DROP TABLE IF EXISTS evaluator_allocation CASCADE;
DROP TABLE IF EXISTS unassigned_answer_sets CASCADE;

-- Create evaluator_allocation table (per exam)
CREATE TABLE IF NOT EXISTS evaluator_allocation (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exam_id UUID NOT NULL REFERENCES icup_exam_metadata(exam_id),
    subject VARCHAR(50) NOT NULL,
    evaluator_id UUID NOT NULL REFERENCES user_information(user_id),
    assigned_answer_sets UUID[] DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'pending', -- pending, in_progress, completed
    has_own_student BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,

    UNIQUE(exam_id, subject, evaluator_id)
);

-- Create unassigned_answer_sets table for tracking unassigned papers per exam
CREATE TABLE IF NOT EXISTS unassigned_answer_sets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exam_id UUID NOT NULL REFERENCES icup_exam_metadata(exam_id),
    subject VARCHAR(50) NOT NULL,
    answer_set_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,

    UNIQUE(exam_id, subject)
);

-- Enable RLS
ALTER TABLE evaluator_allocation ENABLE ROW LEVEL SECURITY;
ALTER TABLE unassigned_answer_sets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for evaluator_allocation
CREATE POLICY "Admins can manage evaluator allocation" ON evaluator_allocation
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Evaluators can view their allocations" ON evaluator_allocation
    FOR SELECT USING (evaluator_id = auth.uid());

-- RLS Policies for unassigned_answer_sets
CREATE POLICY "Admins can manage unassigned answer sets" ON unassigned_answer_sets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_information 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_evaluator_allocation_exam_subject ON evaluator_allocation(exam_id, subject);
CREATE INDEX IF NOT EXISTS idx_evaluator_allocation_evaluator ON evaluator_allocation(evaluator_id);
CREATE INDEX IF NOT EXISTS idx_unassigned_answer_sets_exam_subject ON unassigned_answer_sets(exam_id, subject);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_evaluator_allocation_updated_at 
    BEFORE UPDATE ON evaluator_allocation 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_unassigned_answer_sets_updated_at 
    BEFORE UPDATE ON unassigned_answer_sets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();