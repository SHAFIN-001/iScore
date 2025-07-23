
-- Enable RLS on storage buckets and objects
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow proctors to upload answer papers
CREATE POLICY "Proctors can upload answer papers" ON storage.objects
  FOR INSERT 
  TO authenticated
  WITH CHECK (
    bucket_id = 'uploads' AND
    (path_tokens)[1] = 'answer-papers' AND
    EXISTS (
      SELECT 1 FROM proctor_allocation 
      WHERE proctor_id = auth.uid()
    )
  );

-- Allow proctors to read uploaded answer papers
CREATE POLICY "Proctors can read answer papers" ON storage.objects
  FOR SELECT 
  TO authenticated
  USING (
    bucket_id = 'uploads' AND
    (path_tokens)[1] = 'answer-papers' AND
    EXISTS (
      SELECT 1 FROM proctor_allocation 
      WHERE proctor_id = auth.uid()
    )
  );

-- Allow anyone to read from uploads bucket (for public URLs to work)
CREATE POLICY "Public read access for uploads" ON storage.objects
  FOR SELECT 
  TO public
  USING (bucket_id = 'uploads');

-- Note: Create the 'uploads' bucket manually through Supabase Dashboard
-- Go to Dashboard → Storage → Create Bucket → Name: 'uploads' → Public: true
