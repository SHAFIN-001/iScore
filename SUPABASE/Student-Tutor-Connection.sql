
-- Function to accept student connection requests
CREATE OR REPLACE FUNCTION accept_student_connection(
  student_id UUID,
  tutor_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  student_tutors UUID[];
  tutor_students UUID[];
BEGIN
  -- Get current student's tutors list
  SELECT tutors INTO student_tutors 
  FROM student_additional_info 
  WHERE user_id = student_id;
  
  -- If student doesn't have additional info, create it
  IF student_tutors IS NULL THEN
    INSERT INTO student_additional_info (
      user_id, tutors, class_level, subject_preference, 
      location_qr, private_days, gender, birth_date
    )
    VALUES (
      student_id, ARRAY[tutor_id], NULL, ARRAY[]::TEXT[], 
      NULL, NULL, NULL, NULL
    );
  ELSE
    -- Add tutor to student's tutors list if not already present
    IF NOT (tutor_id = ANY(student_tutors)) THEN
      UPDATE student_additional_info 
      SET tutors = array_append(tutors, tutor_id)
      WHERE user_id = student_id;
    END IF;
  END IF;

  -- Get current tutor's students list
  SELECT students INTO tutor_students 
  FROM tutor_additional_info 
  WHERE user_id = tutor_id;
  
  -- If tutor doesn't have additional info, create it
  IF tutor_students IS NULL THEN
    INSERT INTO tutor_additional_info (
      user_id, students, institution, subject, batch, 
      offered_subjects, class_levels, experience_years
    )
    VALUES (
      tutor_id, ARRAY[student_id], NULL, NULL, NULL, 
      ARRAY[]::TEXT[], ARRAY[]::TEXT[], 0
    );
  ELSE
    -- Add student to tutor's students list if not already present
    IF NOT (student_id = ANY(tutor_students)) THEN
      UPDATE tutor_additional_info 
      SET students = array_append(students, student_id)
      WHERE user_id = tutor_id;
    END IF;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Connection established successfully');
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accept_student_connection(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION accept_student_connection(UUID, UUID) TO service_role;
