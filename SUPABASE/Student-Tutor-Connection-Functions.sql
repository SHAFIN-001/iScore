
-- RPC Functions for Student-Tutor Connections

-- Function to insert student additional info and handle tutor connections
CREATE OR REPLACE FUNCTION insert_student_additional_info(student_data JSONB)
RETURNS TABLE(user_id UUID, tutors UUID[], parents UUID[])
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    tutor_ids UUID[];
    parent_ids UUID[];
    student_user_id UUID;
BEGIN
    -- Extract data from JSON
    student_user_id := (student_data->>'user_id')::UUID;
    tutor_ids := ARRAY(SELECT jsonb_array_elements_text(student_data->'tutors'))::UUID[];
    parent_ids := ARRAY(SELECT jsonb_array_elements_text(student_data->'parents'))::UUID[];

    -- Insert student additional info
    INSERT INTO student_additional_info (
        user_id,
        institution,
        class,
        student_id,
        tutors,
        parents,
        preferred_subjects,
        current_address,
        permanent_address,
        emergency_contact,
        guardian_contact,
        guardian_relationship,
        payment_number,
        special_requirements,
        additional_notes
    ) VALUES (
        student_user_id,
        student_data->>'institution',
        student_data->>'class',
        student_data->>'student_id',
        tutor_ids,
        parent_ids,
        ARRAY(SELECT jsonb_array_elements_text(student_data->'preferred_subjects')),
        student_data->>'current_address',
        student_data->>'permanent_address',
        student_data->>'emergency_contact',
        student_data->>'guardian_contact',
        student_data->>'guardian_relationship',
        student_data->>'payment_number',
        student_data->>'special_requirements',
        student_data->>'additional_notes'
    );

    -- Update tutor additional info to include this student
    IF tutor_ids IS NOT NULL AND array_length(tutor_ids, 1) > 0 THEN
        UPDATE tutor_additional_info 
        SET students = array_append(COALESCE(students, ARRAY[]::UUID[]), student_user_id)
        WHERE user_id = ANY(tutor_ids);
    END IF;

    -- Return the inserted data
    RETURN QUERY 
    SELECT s.user_id, s.tutors, s.parents 
    FROM student_additional_info s 
    WHERE s.user_id = student_user_id;
END;
$$;

-- Function to connect a student to a tutor
CREATE OR REPLACE FUNCTION connect_student_to_tutor(student_id UUID, tutor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Add tutor to student's tutors array
    UPDATE student_additional_info 
    SET tutors = array_append(COALESCE(tutors, ARRAY[]::UUID[]), tutor_id)
    WHERE user_id = student_id
    AND NOT (tutor_id = ANY(COALESCE(tutors, ARRAY[]::UUID[])));

    -- Add student to tutor's students array
    UPDATE tutor_additional_info 
    SET students = array_append(COALESCE(students, ARRAY[]::UUID[]), student_id)
    WHERE user_id = tutor_id
    AND NOT (student_id = ANY(COALESCE(students, ARRAY[]::UUID[])));

    RETURN TRUE;
END;
$$;

-- Function to get available students (not connected to any tutor)
CREATE OR REPLACE FUNCTION get_available_students()
RETURNS TABLE(
    user_id UUID,
    full_name TEXT,
    email TEXT,
    institution TEXT,
    class TEXT,
    preferred_subjects TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ui.user_id,
        ui.full_name,
        ui.email,
        sai.institution,
        sai.class,
        sai.preferred_subjects
    FROM user_information ui
    JOIN student_additional_info sai ON ui.user_id = sai.user_id
    WHERE ui.role = 'student'
    AND (sai.tutors IS NULL OR array_length(sai.tutors, 1) = 0);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION insert_student_additional_info(JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION connect_student_to_tutor(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_available_students() TO authenticated, service_role;
