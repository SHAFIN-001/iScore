# 📄 1_create_tables.sql

-- ===============================
-- 🌐 Create All Tables
-- ===============================

-- 1. User Info
create table if not exists user_information (
  id uuid primary key default gen_random_uuid(),
  username text unique,
  email text unique,
  phone text unique,
  full_name text,
  nick_name text,
  role text check (role in ('student', 'tutor', 'parent', 'admin')),
  profile_picture text,
  password text,
  dob date,
  gender text,
  district text,
  city text,
  bio text,
  bkash_number text
);

-- 2. Student Additional Info
create table if not exists student_additional_info (
  user_id uuid primary key references user_information(id),
  latest_icup_position text,
  tutors uuid[],
  parents uuid[],
  institution text,
  ssc_batch text,
  location_qr text
);

-- 3. Tutor Additional Info
create table if not exists tutor_additional_info (
  user_id uuid primary key references user_information(id),
  students uuid[],
  institution text,
  subject text,
  batch text,
  offered_subjects text[],
  class_levels text[],
  version text,
  preferred_times text,
  tuition_type text,
  home_tutoring_available boolean,
  preferred_locations text[],
  hsc text,
  ssc text,
  jsc text,
  college text,
  school text,
  experience_years int,
  students_taught int,
  experience_info text,
  intro text,
  methodology text[],
  achievements text,
  success_stories text,
  fee_jsc numeric,
  fee_ssc numeric,
  fee_hsc numeric,
  hide_fee boolean,
  linkedin text,
  facebook text,
  youtube text,
  whatsapp text,
  telegram text,
  instagram text,
  discord text,
  reddit text,
  pinterest text,
  x_handle text
);

-- 4. Parent Additional Info
create table if not exists parent_additional_info (
  user_id uuid primary key references user_information(id),
  students uuid[],
  tutors uuid[]
);

-- 5. Student Enrollment
create table if not exists student_enrollment (
  user_id uuid references user_information(id),
  week_number int,
  enrolled boolean,
  primary key (user_id, week_number)
);

-- 6. iCup Exam Metadata
create table if not exists icup_exam_metadata (
  exam_id uuid primary key default gen_random_uuid(),
  title text,
  slug text,
  week_number int,
  category text,
  subject text[],
  syllabus text,
  grade_level text,
  exam_type text,
  duration_minutes int,
  total_marks int,
  difficulty_level text,
  language text,
  question_count int,
  fee numeric,
  pay_number text,
  scheduled_at timestamp,
  available_from timestamp,
  available_until timestamp,
  allow_late_submission boolean,
  submit_deadline timestamp,
  answer_all_pdf_url text,
  evaluation_type text,
  marking_deadline timestamp,
  allow_partial_marks boolean,
  question_marks jsonb,
  notes text,
  tags text[],
  is_archived boolean
);

-- 7. Answer Sets
create table if not exists answer_sets (
  id text primary key,
  student_id uuid references user_information(id),
  proctor_id uuid references user_information(id),
  answer_images text[]
);

-- 8. Proctor Allocation
create table if not exists proctor_allocation (
  sl_no serial primary key,
  student_full_name text,
  student_id uuid,
  address_qr text,
  proctor_full_name text,
  proctor_id uuid
);

-- 9. Evaluation Allocation
create table if not exists evaluation_allocation (
  sl_no serial primary key,
  evaluator_name text,
  evaluator_id uuid,
  answer_set_id text references answer_sets(id)
);

-- 10. Answer Evaluation
create table if not exists answer_evaluation (
  answer_set_id text primary key references answer_sets(id),
  evaluated_pictures text[],
  detailed_marks numeric[],
  total_marks numeric
);

-- 11. Final Marks
create table if not exists final_marks (
  rank int,
  answer_set_id text references answer_sets(id),
  student_id uuid references user_information(id),
  student_full_name text,
  total_marks numeric
);

-- 12. Leaderboard
create table if not exists leaderboard (
  rank int,
  student_id uuid references user_information(id),
  student_full_name text,
  total_marks numeric
);
# 📄 2_rls_and_policies.sql

-- ===============================
-- 🔐 Enable Row-Level Security
-- ===============================

alter table user_information enable row level security;
alter table student_additional_info enable row level security;
alter table tutor_additional_info enable row level security;
alter table parent_additional_info enable row level security;
alter table student_enrollment enable row level security;
alter table icup_exam_metadata enable row level security;
alter table answer_sets enable row level security;
alter table proctor_allocation enable row level security;
alter table evaluation_allocation enable row level security;
alter table answer_evaluation enable row level security;
alter table final_marks enable row level security;
alter table leaderboard enable row level security;

-- ===============================
-- 🔐 Basic Policies (Sample)
-- ===============================

-- Example: allow users to view their own profile
create policy "Students can read own profile"
  on user_information
  for select
  using (auth.uid()::uuid = id);

create policy "Students can update own profile"
  on user_information
  for update
  using (auth.uid()::uuid = id);

-- You can replicate similar policies for other tables depending on role
# 📄 3_insert_seed_data.sql

-- ===============================
-- 🧪 Sample Seed Data
-- ===============================

-- Sample Users
insert into user_information (username, email, phone, full_name, role, password, dob, gender, district, city, bio, bkash_number)
values
  ('shafin99', 'shafin@example.com', '01700111222', 'Sakib Shafin', 'student', 'pass1234', '2007-05-12', 'Male', 'Dhaka', 'Uttara', 'SSC 2025 Candidate', '01700111222'),
  ('sohel_tutor', 'sohel@example.com', '01700333444', 'Sohel Rana', 'tutor', 'tutorpass', '1995-03-20', 'Male', 'Dhaka', 'Mohakhali', 'Physics mentor', '01700333444'),
  ('sam_parent', 'sam@example.com', '01700555666', 'Samiha Akter', 'parent', 'parentpass', '1980-11-10', 'Female', 'Chittagong', 'Pahartali', 'Mother of SSC student', '01700555666');

-- Student Additional Info
insert into student_additional_info (user_id, tutors, institution, ssc_batch)
values (
  (select id from user_information where username = 'shafin99'),
  array[(select id from user_information where username = 'sohel_tutor')],
  'Ideal School and College',
  '2025'
);

-- Tutor Additional Info
insert into tutor_additional_info (
  user_id, institution, subject, batch,
  offered_subjects, class_levels, version,
  tuition_type, home_tutoring_available, preferred_locations
)
values (
  (select id from user_information where username = 'sohel_tutor'),
  'BUET', 'Physics', '2017',
  array['Physics', 'Math'],
  array['Class 9', 'SSC'],
  'Bangla',
  'Online',
  true,
  array['Uttara', 'Mohakhali']
);

-- Parent Additional Info
insert into parent_additional_info (user_id, students)
values (
  (select id from user_information where username = 'sam_parent'),
  array[(select id from user_information where username = 'shafin99')]
);

-- Enrollment Sample
insert into student_enrollment (user_id, week_number, enrolled)
values (
  (select id from user_information where username = 'shafin99'),
  7,
  true
);

-- Sample iCup Exam Metadata
insert into icup_exam_metadata (
  title, slug, week_number, category, subject, syllabus,
  grade_level, exam_type, duration_minutes, total_marks,
  difficulty_level, language, question_count, fee, pay_number,
  scheduled_at, available_from, available_until, allow_late_submission,
  submit_deadline, answer_all_pdf_url, evaluation_type, marking_deadline,
  allow_partial_marks, question_marks, notes, tags, is_archived
)
values (
  'iCup Week 7', 'icup-week-7', 7, 'iCup',
  array['Physics', 'Math'],
  'Algebra + Newtonian Motion',
  'SSC', 'Written', 90, 100,
  'Medium', 'Bangla', 10, 100, '01700111222',
  now() + interval '3 days',
  now() + interval '2 days',
  now() + interval '4 days',
  false,
  now() + interval '4 days',
  'https://example.com/answers-week7.pdf',
  'manual',
  now() + interval '5 days',
  true,
  '{"1": 10, "2": 10, "3": 10, "4": 10, "5": 10, "6": 10, "7": 10, "8": 10, "9": 10, "10": 10}'::jsonb,
  'Week 7 special edition',
  array['Science Group', 'Scholarship'],
  false
);

INSERT INTO notifications (user_id, title, message, type) 
SELECT 
  id,
  'Welcome to iScore!',
  'Thank you for joining iScore. Complete your profile to get started.',
  'info'
FROM user_information 
WHERE role = 'student'
ON CONFLICT DO NOTHING;

# 📄 4_storage_setup.sql

-- ===============================
-- 📦 Storage Bucket Policies
-- ===============================

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload files" ON storage.objects
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow public read access to uploads
CREATE POLICY "Public read access to uploads" ON storage.objects
FOR SELECT USING (bucket_id = 'uploads');

-- Allow users to update their own files
CREATE POLICY "Users can update own files" ON storage.objects
FOR UPDATE USING (auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files" ON storage.objects
FOR DELETE USING (auth.uid()::text = (storage.foldername(name))[1]);

# 📄 5_additional_setup.sql

-- ===============================
-- 📊 Additional Tables & Indexes
-- ===============================

-- Payments Table
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

-- Enable RLS on new tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own payments" ON payments
  FOR SELECT USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can create own payments" ON payments
  FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid()::uuid = user_id);

CREATE POLICY "Admins can manage system settings" ON system_settings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_information 
      WHERE id = auth.uid()::uuid AND role = 'admin'
    )
  );

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_user_information_role ON user_information(role);
CREATE INDEX IF NOT EXISTS idx_user_information_email ON user_information(email);
CREATE INDEX IF NOT EXISTS idx_user_information_username ON user_information(username);
CREATE INDEX IF NOT EXISTS idx_icup_exam_week_number ON icup_exam_metadata(week_number);
CREATE INDEX IF NOT EXISTS idx_icup_exam_scheduled_at ON icup_exam_metadata(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_icup_exam_archived ON icup_exam_metadata(is_archived);
CREATE INDEX IF NOT EXISTS idx_answer_sets_student_id ON answer_sets(student_id);
CREATE INDEX IF NOT EXISTS idx_answer_sets_proctor_id ON answer_sets(proctor_id);
CREATE INDEX IF NOT EXISTS idx_student_enrollment_user_week ON student_enrollment(user_id, week_number);
CREATE INDEX IF NOT EXISTS idx_evaluation_allocation_evaluator ON evaluation_allocation(evaluator_id);
CREATE INDEX IF NOT EXISTS idx_evaluation_allocation_answer_set ON evaluation_allocation(answer_set_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_exam_id ON payments(exam_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- Utility Functions
CREATE OR REPLACE FUNCTION get_user_full_profile(user_uuid UUID)
RETURNS JSONB AS $$
DECLARE
  user_data JSONB;
  role_data JSONB;
  user_role TEXT;
BEGIN
  SELECT to_jsonb(ui.*) INTO user_data
  FROM user_information ui
  WHERE ui.id = user_uuid;

  IF user_data IS NULL THEN
    RETURN NULL;
  END IF;

  user_role := user_data->>'role';

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

  RETURN user_data || COALESCE(role_data, '{}'::JSONB);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS VOID AS $$
BEGIN
  DELETE FROM leaderboard;

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

-- Sample System Settings
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