
-- Additional Database Setup for iScore

-- ===============================
-- 📊 Create Additional Tables
-- ===============================

-- Payments Table (optional - for better payment tracking)
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_information(id),
  exam_id UUID REFERENCES icup_exam_metadata(exam_id),
  amount NUMERIC NOT NULL,
  payment_method TEXT DEFAULT 'bkash',
  transaction_id TEXT,
  payment_number TEXT,
  sender_number TEXT,
  status TEXT CHECK (status IN ('pending', 'completed', 'failed', 'refunded')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  notes TEXT
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_information(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT CHECK (type IN ('info', 'success', 'warning', 'error')) DEFAULT 'info',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,
  action_url TEXT
);

-- System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value JSONB,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ===============================
-- 🔐 Additional RLS Policies
-- ===============================

-- Enable RLS on new tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Payment policies
CREATE POLICY "Users can view own payments" ON payments
  FOR SELECT USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can create own payments" ON payments
  FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

-- Notification policies
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid()::uuid = user_id);

-- System settings policies (admin only)
CREATE POLICY "Admins can manage system settings" ON system_settings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE id = auth.uid()::uuid AND role = 'admin'
    )
  );

-- ===============================
-- 📈 Create Indexes for Performance
-- ===============================

-- User information indexes
CREATE INDEX IF NOT EXISTS idx_user_information_role ON user_information(role);
CREATE INDEX IF NOT EXISTS idx_user_information_email ON user_information(email);
CREATE INDEX IF NOT EXISTS idx_user_information_username ON user_information(username);

-- Exam metadata indexes
CREATE INDEX IF NOT EXISTS idx_icup_exam_week_number ON icup_exam_metadata(week_number);
CREATE INDEX IF NOT EXISTS idx_icup_exam_scheduled_at ON icup_exam_metadata(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_icup_exam_archived ON icup_exam_metadata(is_archived);

-- Answer sets indexes
CREATE INDEX IF NOT EXISTS idx_answer_sets_student_id ON answer_sets(student_id);
CREATE INDEX IF NOT EXISTS idx_answer_sets_proctor_id ON answer_sets(proctor_id);

-- Enrollment indexes
CREATE INDEX IF NOT EXISTS idx_student_enrollment_user_week ON student_enrollment(user_id, week_number);

-- Evaluation indexes
CREATE INDEX IF NOT EXISTS idx_evaluation_allocation_evaluator ON evaluation_allocation(evaluator_id);
CREATE INDEX IF NOT EXISTS idx_evaluation_allocation_answer_set ON evaluation_allocation(answer_set_id);

-- Payment indexes
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_exam_id ON payments(exam_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- Notification indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- ===============================
-- 🔧 Create Useful Functions
-- ===============================

-- Function to get user's full profile including role-specific data
CREATE OR REPLACE FUNCTION get_user_full_profile(user_uuid UUID)
RETURNS JSONB AS $$
DECLARE
  user_data JSONB;
  role_data JSONB;
  user_role TEXT;
BEGIN
  -- Get basic user information
  SELECT to_jsonb(ui.*) INTO user_data
  FROM user_information ui
  WHERE ui.id = user_uuid;
  
  IF user_data IS NULL THEN
    RETURN NULL;
  END IF;
  
  user_role := user_data->>'role';
  
  -- Get role-specific data
  CASE user_role
    WHEN 'student' THEN
      SELECT to_jsonb(sai.*) INTO role_data
      FROM student_additional_info sai
      WHERE sai.user_id = user_uuid;
    WHEN 'tutor' THEN
      SELECT to_jsonb(tai.*) INTO role_data
      FROM tutor_additional_info tai
      WHERE tai.user_id = user_uuid;
    WHEN 'parent' THEN
      SELECT to_jsonb(pai.*) INTO role_data
      FROM parent_additional_info pai
      WHERE pai.user_id = user_uuid;
    ELSE
      role_data := '{}'::JSONB;
  END CASE;
  
  -- Combine user data with role-specific data
  RETURN user_data || COALESCE(role_data, '{}'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get leaderboard with ranking
CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS VOID AS $$
BEGIN
  -- Clear existing leaderboard
  DELETE FROM leaderboard;
  
  -- Insert new leaderboard data with proper ranking
  INSERT INTO leaderboard (rank, student_id, student_full_name, total_marks)
  SELECT 
    ROW_NUMBER() OVER (ORDER BY fm.total_marks DESC) as rank,
    fm.student_id,
    fm.student_full_name,
    fm.total_marks
  FROM final_marks fm
  ORDER BY fm.total_marks DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===============================
-- 🧪 Insert Sample System Settings
-- ===============================

INSERT INTO system_settings (key, value, description) VALUES
('app_name', '"iScore"', 'Application name'),
('current_week', '7', 'Current iCup week number'),
('registration_open', 'true', 'Whether registration is open'),
('exam_registration_deadline', '"2024-02-15"', 'Deadline for exam registration'),
('bkash_payment_number', '"01700111222"', 'Default bKash payment number'),
('max_file_upload_size', '52428800', 'Maximum file upload size in bytes (50MB)'),
('allowed_file_types', '["image/jpeg", "image/png", "image/jpg", "application/pdf"]', 'Allowed file MIME types'),
('evaluation_deadline_days', '5', 'Days after exam for evaluation deadline')
ON CONFLICT (key) DO NOTHING;

-- Insert sample notifications
INSERT INTO notifications (user_id, title, message, type) 
SELECT 
  id,
  'Welcome to iScore!',
  'Thank you for joining iScore. Complete your profile to get started.',
  'info'
FROM user_information 
WHERE role = 'student'
ON CONFLICT DO NOTHING;
