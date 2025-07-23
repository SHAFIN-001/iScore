
# Supabase Storage Setup

## Required Storage Buckets

You need to create the following storage buckets in your Supabase project:

### 1. `uploads` bucket
- **Purpose**: Store answer sheets, profile pictures, and other user uploads
- **Access**: Public read, authenticated write
- **File types**: Images (PNG, JPG, JPEG, PDF)

### 2. `answer-sheets` bucket (optional, can use folders in uploads)
- **Purpose**: Specifically for answer sheet images
- **Access**: Restricted to tutors and admins
- **File types**: Images only

## Storage Policies

Add these RLS policies to your storage buckets:

```sql
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
```

## Folder Structure

Recommended folder structure in the `uploads` bucket:
```
uploads/
├── profile-pictures/
├── answer-sheets/
├── evaluation-sheets/
├── documents/
└── temp/
```

## Setup Instructions

1. Go to your Supabase Dashboard
2. Navigate to Storage section
3. Create the `uploads` bucket
4. Set it to Public
5. Add the RLS policies above
6. Test upload functionality

## File Upload Limits

- Maximum file size: 50MB per file
- Supported formats: PNG, JPG, JPEG, PDF
- Multiple files supported for answer sheets
