-- ===============================================
-- 📊 Evaluation System Supporting Functions
-- ===============================================

-- Function to get evaluation progress for an evaluator
CREATE OR REPLACE FUNCTION get_evaluator_progress(evaluator_uuid UUID, exam_uuid UUID)
RETURNS TABLE (
    subject VARCHAR(50),
    total_assigned INTEGER,
    completed_evaluations INTEGER,
    in_progress_evaluations INTEGER,
    pending_evaluations INTEGER,
    completion_percentage DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH assignment_stats AS (
        SELECT 
            ea.subject,
            ARRAY_LENGTH(ea.assigned_answer_sets, 1) as total_assigned
        FROM evaluator_allocation ea
        WHERE ea.evaluator_id = evaluator_uuid
        AND ea.exam_id = exam_uuid
    ),
    evaluation_stats AS (
        SELECT 
            ae.subject,
            COUNT(*) FILTER (WHERE ae.status = 'completed') as completed,
            COUNT(*) FILTER (WHERE ae.status = 'in_progress') as in_progress
        FROM answer_evaluation ae
        WHERE ae.evaluator_id = evaluator_uuid
        AND ae.exam_id = exam_uuid
        GROUP BY ae.subject
    )
    SELECT 
        ast.subject,
        COALESCE(ast.total_assigned, 0) as total_assigned,
        COALESCE(es.completed, 0) as completed_evaluations,
        COALESCE(es.in_progress, 0) as in_progress_evaluations,
        COALESCE(ast.total_assigned, 0) - COALESCE(es.completed, 0) - COALESCE(es.in_progress, 0) as pending_evaluations,
        CASE 
            WHEN COALESCE(ast.total_assigned, 0) = 0 THEN 0
            ELSE ROUND((COALESCE(es.completed, 0)::DECIMAL / ast.total_assigned) * 100, 2)
        END as completion_percentage
    FROM assignment_stats ast
    LEFT JOIN evaluation_stats es ON ast.subject = es.subject;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically allocate answer sets to evaluators
CREATE OR REPLACE FUNCTION allocate_answer_sets_to_evaluators(exam_uuid UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
    allocation_summary TEXT := '';
    subject_record RECORD;
    evaluator_record RECORD;
    available_sets UUID[];
    sets_per_evaluator INTEGER;
    remaining_sets INTEGER;
    allocation_count INTEGER := 0;
BEGIN
    -- Loop through each subject
    FOR subject_record IN 
        SELECT DISTINCT unnest(preferred_subjects) as subject
        FROM evaluator_eligibility 
        WHERE enabled = true
    LOOP
        -- Get all answer sets for this subject and exam
        SELECT ARRAY_AGG(ans.id) INTO available_sets
        FROM answer_sets ans
        WHERE ans.exam_id = exam_uuid
        AND ARRAY_LENGTH(ans[subject_record.subject || '_images'], 1) > 0;

        -- Skip if no answer sets available
        IF available_sets IS NULL OR ARRAY_LENGTH(available_sets, 1) = 0 THEN
            CONTINUE;
        END IF;

        -- Get eligible evaluators for this subject
        sets_per_evaluator := ARRAY_LENGTH(available_sets, 1) / (
            SELECT COUNT(*)
            FROM evaluator_eligibility ee
            WHERE ee.enabled = true
            AND subject_record.subject = ANY(ee.preferred_subjects)
        );

        -- Ensure at least 1 set per evaluator
        IF sets_per_evaluator < 1 THEN
            sets_per_evaluator := 1;
        END IF;

        remaining_sets := ARRAY_LENGTH(available_sets, 1);

        -- Allocate to each evaluator
        FOR evaluator_record IN
            SELECT ee.tutor_id, ee.tutor_full_name
            FROM evaluator_eligibility ee
            WHERE ee.enabled = true
            AND subject_record.subject = ANY(ee.preferred_subjects)
            ORDER BY ee.created_at
        LOOP
            IF remaining_sets <= 0 THEN
                EXIT;
            END IF;

            -- Calculate how many sets to allocate to this evaluator
            allocation_count := LEAST(sets_per_evaluator, remaining_sets);

            -- Insert or update evaluator allocation
            INSERT INTO evaluator_allocation (
                exam_id,
                subject,
                evaluator_id,
                assigned_answer_sets,
                status,
                has_own_student
            )
            VALUES (
                exam_uuid,
                subject_record.subject,
                evaluator_record.tutor_id,
                available_sets[1:allocation_count],
                'pending',
                false
            )
            ON CONFLICT (exam_id, subject, evaluator_id)
            DO UPDATE SET
                assigned_answer_sets = EXCLUDED.assigned_answer_sets,
                updated_at = NOW();

            -- Remove allocated sets from available sets
            available_sets := available_sets[(allocation_count + 1):];
            remaining_sets := remaining_sets - allocation_count;

            allocation_summary := allocation_summary || 
                format('Allocated %s sets of %s to %s. ', 
                       allocation_count, 
                       subject_record.subject, 
                       evaluator_record.tutor_full_name);
        END LOOP;

        -- Store any remaining unassigned sets
        IF remaining_sets > 0 THEN
            INSERT INTO unassigned_answer_sets (exam_id, subject, answer_set_ids)
            VALUES (exam_uuid, subject_record.subject, available_sets)
            ON CONFLICT (exam_id, subject)
            DO UPDATE SET
                answer_set_ids = EXCLUDED.answer_set_ids,
                updated_at = NOW();
        END IF;
    END LOOP;

    result := json_build_object(
        'success', true,
        'message', 'Answer sets allocated successfully',
        'details', allocation_summary
    );

    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student evaluation summary
CREATE OR REPLACE FUNCTION get_student_evaluation_summary(student_uuid UUID, exam_uuid UUID)
RETURNS TABLE (
    subject VARCHAR(50),
    total_marks DECIMAL(5,2),
    evaluator_name TEXT,
    evaluation_status VARCHAR(20),
    evaluated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ae.subject,
        ae.total_marks,
        ui.full_name as evaluator_name,
        ae.status as evaluation_status,
        ae.submitted_at as evaluated_at
    FROM answer_evaluation ae
    JOIN user_information ui ON ae.evaluator_id = ui.user_id
    WHERE ae.student_id = student_uuid
    AND ae.exam_id = exam_uuid
    ORDER BY ae.subject;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate overall exam statistics
CREATE OR REPLACE FUNCTION get_exam_evaluation_statistics(exam_uuid UUID)
RETURNS JSON AS $$
DECLARE
    total_students INTEGER;
    total_evaluations_needed INTEGER;
    completed_evaluations INTEGER;
    avg_score DECIMAL(10,2);
    subject_stats JSON;
    result JSON;
BEGIN
    -- Get total students enrolled for this exam
    SELECT COUNT(DISTINCT student_id) INTO total_students
    FROM answer_sets
    WHERE exam_id = exam_uuid;

    -- Get total evaluations needed (students × subjects)
    SELECT COUNT(*) INTO total_evaluations_needed
    FROM answer_sets ans
    CROSS JOIN (
        SELECT DISTINCT unnest(preferred_subjects) as subject
        FROM evaluator_eligibility 
        WHERE enabled = true
    ) subjects
    WHERE ans.exam_id = exam_uuid
    AND ARRAY_LENGTH(ans[subjects.subject || '_images'], 1) > 0;

    -- Get completed evaluations
    SELECT COUNT(*) INTO completed_evaluations
    FROM answer_evaluation
    WHERE exam_id = exam_uuid
    AND status = 'completed';

    -- Get average score
    SELECT ROUND(AVG(total_marks), 2) INTO avg_score
    FROM answer_evaluation
    WHERE exam_id = exam_uuid
    AND status = 'completed';

    -- Get subject-wise statistics
    SELECT json_agg(
        json_build_object(
            'subject', subject,
            'total_evaluations', total_evaluations,
            'completed_evaluations', completed_evaluations,
            'completion_percentage', completion_percentage,
            'average_score', average_score
        )
    ) INTO subject_stats
    FROM (
        SELECT 
            ae.subject,
            COUNT(*) as total_evaluations,
            COUNT(*) FILTER (WHERE ae.status = 'completed') as completed_evaluations,
            ROUND(
                (COUNT(*) FILTER (WHERE ae.status = 'completed')::DECIMAL / COUNT(*)) * 100, 
                2
            ) as completion_percentage,
            ROUND(AVG(ae.total_marks) FILTER (WHERE ae.status = 'completed'), 2) as average_score
        FROM answer_evaluation ae
        WHERE ae.exam_id = exam_uuid
        GROUP BY ae.subject
    ) subject_summary;

    result := json_build_object(
        'exam_id', exam_uuid,
        'total_students', total_students,
        'total_evaluations_needed', total_evaluations_needed,
        'completed_evaluations', completed_evaluations,
        'completion_percentage', 
            CASE 
                WHEN total_evaluations_needed = 0 THEN 0
                ELSE ROUND((completed_evaluations::DECIMAL / total_evaluations_needed) * 100, 2)
            END,
        'average_score', avg_score,
        'subject_statistics', subject_stats
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to ensure evaluator sees anonymous student data
CREATE OR REPLACE FUNCTION get_anonymous_answer_sets(evaluator_uuid UUID, exam_uuid UUID, subject_name VARCHAR(50))
RETURNS TABLE (
    anonymous_id TEXT,
    answer_set_id UUID,
    subject VARCHAR(50),
    images TEXT[],
    upload_status TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE,
    evaluation_status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'AS-' || SUBSTRING(ans.id::TEXT, 1, 8) as anonymous_id,
        ans.id as answer_set_id,
        subject_name as subject,
        CASE subject_name
            WHEN 'physics' THEN ans.physics_images
            WHEN 'chemistry' THEN ans.chemistry_images
            WHEN 'math' THEN ans.math_images
            WHEN 'biology' THEN ans.biology_images
            ELSE '{}'::TEXT[]
        END as images,
        ans.upload_status,
        ans.uploaded_at,
        COALESCE(ae.status, 'pending') as evaluation_status
    FROM answer_sets ans
    JOIN evaluator_allocation ea ON ans.id = ANY(ea.assigned_answer_sets)
    LEFT JOIN answer_evaluation ae ON ans.id = ae.answer_set_id 
        AND ae.subject = subject_name 
        AND ae.evaluator_id = evaluator_uuid
    WHERE ea.evaluator_id = evaluator_uuid
    AND ea.exam_id = exam_uuid
    AND ea.subject = subject_name
    AND ans.exam_id = exam_uuid
    ORDER BY ans.uploaded_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_evaluator_progress(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION allocate_answer_sets_to_evaluators(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_evaluation_summary(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_exam_evaluation_statistics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_anonymous_answer_sets(UUID, UUID, VARCHAR(50)) TO authenticated;

-- Create additional RLS policy for evaluator allocation access
CREATE POLICY "evaluators_can_view_own_allocations" ON evaluator_allocation
    FOR SELECT 
    TO authenticated
    USING (evaluator_id = auth.uid());

COMMENT ON FUNCTION get_evaluator_progress IS 'Returns evaluation progress statistics for a specific evaluator and exam';
COMMENT ON FUNCTION allocate_answer_sets_to_evaluators IS 'Automatically allocates answer sets to eligible evaluators for fair distribution';
COMMENT ON FUNCTION get_student_evaluation_summary IS 'Returns evaluation summary for a specific student and exam';
COMMENT ON FUNCTION get_exam_evaluation_statistics IS 'Returns comprehensive evaluation statistics for an exam';
COMMENT ON FUNCTION get_anonymous_answer_sets IS 'Returns answer sets with anonymous student identifiers for evaluators';