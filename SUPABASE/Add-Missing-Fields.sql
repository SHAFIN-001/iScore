
-- Add missing fields to icup_exam_metadata table

-- Update question_pdf_url to JSONB for storing multiple question sets
ALTER TABLE icup_exam_metadata 
ALTER COLUMN question_pdf_url TYPE JSONB USING 
  CASE 
    WHEN question_pdf_url IS NULL THEN NULL
    WHEN question_pdf_url = '' THEN NULL
    ELSE json_build_object('1', question_pdf_url)
  END;

-- Add comment for clarity
COMMENT ON COLUMN icup_exam_metadata.question_pdf_url IS 'JSON object containing URLs for multiple question sets (e.g., {"1": "url1", "2": "url2"})';
COMMENT ON COLUMN icup_exam_metadata.question_marks IS 'JSON object containing marks for each question (e.g., {"1": 10, "2": 15, "3": 20})';
COMMENT ON COLUMN icup_exam_metadata.answer_all_pdf_url IS 'URL to the answer sheet PDF containing all correct answers';
