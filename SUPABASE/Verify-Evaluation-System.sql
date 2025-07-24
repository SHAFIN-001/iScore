-- ===============================================
-- 🔍 Evaluation System Verification Script
-- ===============================================

-- Check if all required tables exist
DO $$
BEGIN
    RAISE NOTICE '=== CHECKING REQUIRED TABLES ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'answer_evaluation') THEN
        RAISE NOTICE '✅ answer_evaluation table exists';
    ELSE
        RAISE NOTICE '❌ answer_evaluation table missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'answer_sets') THEN
        RAISE NOTICE '✅ answer_sets table exists';
    ELSE
        RAISE NOTICE '❌ answer_sets table missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'evaluator_eligibility') THEN
        RAISE NOTICE '✅ evaluator_eligibility table exists';
    ELSE
        RAISE NOTICE '❌ evaluator_eligibility table missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'evaluator_allocation') THEN
        RAISE NOTICE '✅ evaluator_allocation table exists';
    ELSE
        RAISE NOTICE '❌ evaluator_allocation table missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_information') THEN
        RAISE NOTICE '✅ user_information table exists';
    ELSE
        RAISE NOTICE '❌ user_information table missing';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'icup_exam_metadata') THEN
        RAISE NOTICE '✅ icup_exam_metadata table exists';
    ELSE
        RAISE NOTICE '❌ icup_exam_metadata table missing';
    END IF;
END $$;

-- Check answer_evaluation table structure
DO $$
DECLARE
    col_exists BOOLEAN;
    column_list TEXT;
BEGIN
    RAISE NOTICE '=== CHECKING ANSWER_EVALUATION TABLE STRUCTURE ===';
    
    -- Get all columns
    SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) INTO column_list
    FROM information_schema.columns 
    WHERE table_name = 'answer_evaluation';
    
    RAISE NOTICE 'Columns in answer_evaluation: %', COALESCE(column_list, 'TABLE NOT FOUND');
    
    -- Check specific required columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'answer_evaluation' AND column_name = 'evaluator_id'
    ) INTO col_exists;
    
    IF col_exists THEN
        RAISE NOTICE '✅ evaluator_id column exists';
    ELSE
        RAISE NOTICE '❌ evaluator_id column missing';
    END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'answer_evaluation' AND column_name = 'answer_set_id'
    ) INTO col_exists;
    
    IF col_exists THEN
        RAISE NOTICE '✅ answer_set_id column exists';
    ELSE
        RAISE NOTICE '❌ answer_set_id column missing';
    END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'answer_evaluation' AND column_name = 'student_id'
    ) INTO col_exists;
    
    IF col_exists THEN
        RAISE NOTICE '✅ student_id column exists';
    ELSE
        RAISE NOTICE '❌ student_id column missing';
    END IF;
END $$;

-- Check if current_week_leaderboard view exists
DO $$
BEGIN
    RAISE NOTICE '=== CHECKING VIEWS ===';
    
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'current_week_leaderboard') THEN
        RAISE NOTICE '✅ current_week_leaderboard view exists';
    ELSE
        RAISE NOTICE '❌ current_week_leaderboard view missing';
    END IF;
END $$;

-- Check data availability
DO $$
DECLARE
    user_count INTEGER;
    exam_count INTEGER;
    answer_set_count INTEGER;
    evaluation_count INTEGER;
    evaluator_count INTEGER;
BEGIN
    RAISE NOTICE '=== CHECKING DATA AVAILABILITY ===';
    
    -- Count users
    SELECT COUNT(*) INTO user_count FROM user_information WHERE 1=1;
    RAISE NOTICE 'Users in system: %', user_count;
    
    -- Count exams
    SELECT COUNT(*) INTO exam_count FROM icup_exam_metadata WHERE is_archived = false;
    RAISE NOTICE 'Active exams: %', exam_count;
    
    -- Count answer sets
    SELECT COUNT(*) INTO answer_set_count FROM answer_sets WHERE 1=1;
    RAISE NOTICE 'Answer sets: %', answer_set_count;
    
    -- Count evaluations
    SELECT COUNT(*) INTO evaluation_count FROM answer_evaluation WHERE 1=1;
    RAISE NOTICE 'Evaluations: %', evaluation_count;
    
    -- Count eligible evaluators
    SELECT COUNT(*) INTO evaluator_count FROM evaluator_eligibility WHERE enabled = true;
    RAISE NOTICE 'Eligible evaluators: %', evaluator_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error checking data: %', SQLERRM;
END $$;

-- Test leaderboard view
DO $$
DECLARE
    leaderboard_count INTEGER;
    sample_record RECORD;
BEGIN
    RAISE NOTICE '=== TESTING LEADERBOARD VIEW ===';
    
    BEGIN
        SELECT COUNT(*) INTO leaderboard_count FROM current_week_leaderboard;
        RAISE NOTICE 'Leaderboard entries: %', leaderboard_count;
        
        IF leaderboard_count > 0 THEN
            SELECT * INTO sample_record FROM current_week_leaderboard LIMIT 1;
            RAISE NOTICE 'Sample leaderboard entry: Student: %, Score: %, Class: %', 
                sample_record.full_name, sample_record.total_score, sample_record.class_level;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error accessing leaderboard view: %', SQLERRM;
    END;
END $$;

-- Check RLS policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    RAISE NOTICE '=== CHECKING RLS POLICIES ===';
    
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'answer_evaluation';
    
    RAISE NOTICE 'RLS policies on answer_evaluation: %', policy_count;
    
    IF policy_count = 0 THEN
        RAISE NOTICE '⚠️  No RLS policies found - this might cause access issues';
    END IF;
    
END $$;

-- Test sample query that the application might use
DO $$
DECLARE
    test_user_id UUID;
    test_exam_id UUID;
BEGIN
    RAISE NOTICE '=== TESTING SAMPLE QUERIES ===';
    
    -- Get a test user
    SELECT user_id INTO test_user_id FROM user_information WHERE role = 'tutor' LIMIT 1;
    
    -- Get a test exam
    SELECT exam_id INTO test_exam_id FROM icup_exam_metadata WHERE is_archived = false LIMIT 1;
    
    IF test_user_id IS NOT NULL AND test_exam_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with User ID: %, Exam ID: %', test_user_id, test_exam_id;
        
        -- Test evaluator eligibility query
        BEGIN
            PERFORM * FROM evaluator_eligibility WHERE tutor_id = test_user_id AND enabled = true;
            RAISE NOTICE '✅ Evaluator eligibility query works';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '❌ Evaluator eligibility query failed: %', SQLERRM;
        END;
        
    ELSE
        RAISE NOTICE '⚠️  Cannot run sample queries - missing test data';
    END IF;
    
END $$;

RAISE NOTICE '=== VERIFICATION COMPLETE ===';

-- Create a simple function to test the leaderboard
CREATE OR REPLACE FUNCTION test_leaderboard()
RETURNS TABLE (
    message TEXT,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'Current week leaderboard entries' as message,
        COUNT(*) as count
    FROM current_week_leaderboard;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY
        SELECT 
            'Error: ' || SQLERRM as message,
            0::BIGINT as count;
END;
$$ LANGUAGE plpgsql;

-- Grant permission to test function
GRANT EXECUTE ON FUNCTION test_leaderboard() TO authenticated;