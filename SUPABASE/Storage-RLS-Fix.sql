
-- Create storage bucket if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('uploads', 'uploads', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy to allow authenticated users to upload
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT WITH CHECK (
  auth.role() = 'authenticated' AND 
  bucket_id = 'uploads'
);

-- Policy to allow public read access
CREATE POLICY "Allow public read access" ON storage.objects
FOR SELECT USING (bucket_id = 'uploads');

-- Policy to allow users to update their own uploads
CREATE POLICY "Allow users to update own uploads" ON storage.objects
FOR UPDATE USING (
  auth.uid()::text = (storage.foldername(name))[1] AND
  bucket_id = 'uploads'
);

-- Policy to allow users to delete their own uploads
CREATE POLICY "Allow users to delete own uploads" ON storage.objects
FOR DELETE USING (
  auth.uid()::text = (storage.foldername(name))[1] AND
  bucket_id = 'uploads'
);
