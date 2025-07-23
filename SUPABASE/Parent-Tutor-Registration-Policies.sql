
-- RLS Policies for Parent Registration with Single Parent per Student

-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Parents can update tutors during registration" ON tutor_additional_info;
DROP POLICY IF EXISTS "Parents can insert tutor info during registration" ON tutor_additional_info;
DROP POLICY IF EXISTS "Students and single parent can update student info" ON student_additional_info;
DROP POLICY IF EXISTS "Parents can insert student info for parentless students" ON student_additional_info;

-- Allow parents to update tutor_additional_info during registration
CREATE POLICY "Parents can update tutors during registration" ON tutor_additional_info
  FOR UPDATE 
  TO authenticated
  USING (
    -- Allow if the parent is connected to students who have this tutor
    EXISTS (
      SELECT 1 FROM parent_additional_info p
      JOIN unnest(p.students) AS student_id ON true
      JOIN student_additional_info s ON s.user_id = student_id
      WHERE p.user_id = auth.uid() 
      AND tutor_additional_info.user_id = ANY(s.tutors)
    )
  )
  WITH CHECK (
    -- Same check for WITH CHECK
    EXISTS (
      SELECT 1 FROM parent_additional_info p
      JOIN unnest(p.students) AS student_id ON true
      JOIN student_additional_info s ON s.user_id = student_id
      WHERE p.user_id = auth.uid() 
      AND tutor_additional_info.user_id = ANY(s.tutors)
    )
  );

-- Allow parents to insert tutor_additional_info if tutor doesn't exist
CREATE POLICY "Parents can insert tutor info during registration" ON tutor_additional_info
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    -- Allow if the parent is trying to connect to a tutor through their students
    user_id IN (
      SELECT DISTINCT unnest(s.tutors) 
      FROM parent_additional_info p
      JOIN unnest(p.students) AS student_id ON true
      JOIN student_additional_info s ON s.user_id = student_id
      WHERE p.user_id = auth.uid()
    )
  );

-- Update student_additional_info policy to prevent multiple parents
DROP POLICY IF EXISTS "Students can update their own info" ON student_additional_info;
DROP POLICY IF EXISTS "Students and parents can update student info" ON student_additional_info;
CREATE POLICY "Students and single parent can update student info" ON student_additional_info
  FOR UPDATE 
  TO authenticated
  USING (
    user_id = auth.uid() OR
    (auth.uid() = ANY(parents) AND cardinality(parents) = 1) OR
    -- Allow during parent registration ONLY if student has no parents yet
    (EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    ) AND (parents IS NULL OR cardinality(parents) = 0))
  )
  WITH CHECK (
    user_id = auth.uid() OR
    (auth.uid() = ANY(parents) AND cardinality(parents) = 1) OR
    -- Allow during parent registration ONLY if student has no parents yet
    (EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    ) AND (parents IS NULL OR cardinality(parents) = 0))
  );

-- Allow parents to insert student info ONLY if student has no parents
CREATE POLICY "Parents can insert student info for parentless students" ON student_additional_info
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    -- Allow if the user is a parent and student has no existing parents
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE user_id = auth.uid() 
      AND role = 'parent'
    ) AND 
    auth.uid() = ANY(parents) AND 
    cardinality(parents) = 1 AND
    -- Ensure no existing record for this student with parents
    NOT EXISTS (
      SELECT 1 FROM student_additional_info existing
      WHERE existing.user_id = student_additional_info.user_id
      AND existing.parents IS NOT NULL 
      AND cardinality(existing.parents) > 0
    )
  );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON tutor_additional_info TO authenticated;
GRANT SELECT, INSERT, UPDATE ON student_additional_info TO authenticated;
GRANT SELECT, INSERT, UPDATE ON parent_additional_info TO authenticated;
