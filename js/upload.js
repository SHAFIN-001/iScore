
// Image upload utility
class ImageUploader {
  constructor() {
    this.supabase = null;
    this.initSupabase();
  }

  async initSupabase() {
    // Wait for either SUPABASE_CONFIG or supabaseClient to be available
    while (!window.SUPABASE_CONFIG?.getClient() && !window.supabaseClient) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    this.supabase = window.SUPABASE_CONFIG?.getClient() || window.supabaseClient;
  }

  // Ensure supabase is initialized before any operation
  async ensureInitialized() {
    if (!this.supabase) {
      await this.initSupabase();
    }
    if (!this.supabase) {
      throw new Error('Supabase client not available');
    }
  }

  // Upload image to Supabase storage
  async uploadImage(file, bucketName, folder = '') {
    try {
      if (!file) throw new Error('No file provided');

      // Ensure supabase is initialized
      await this.ensureInitialized();

      // Generate unique filename
      const fileExt = file.name.split('.').pop();
      const fileName = `${Date.now()}_${Math.random().toString(36).substring(2)}.${fileExt}`;
      const filePath = folder ? `${folder}/${fileName}` : fileName;

      // Upload file to Supabase storage
      const { data, error } = await this.supabase.storage
        .from(bucketName)
        .upload(filePath, file);

      if (error) throw error;

      // Get public URL
      const { data: { publicUrl } } = this.supabase.storage
        .from(bucketName)
        .getPublicUrl(filePath);

      return publicUrl;
    } catch (error) {
      console.error('Upload error:', error);
      throw error;
    }
  }

  // Delete image from Supabase storage
  async deleteImage(bucketName, filePath) {
    try {
      // Ensure supabase is initialized
      await this.ensureInitialized();

      const { error } = await this.supabase.storage
        .from(bucketName)
        .remove([filePath]);

      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Delete error:', error);
      return { success: false, error: error.message };
    }
  }
}

// Global upload function for backward compatibility
async function uploadImage(file, bucketName, folder = '') {
  const uploader = new ImageUploader();
  return await uploader.uploadImage(file, bucketName, folder);
}

// Initialize uploader
window.imageUploader = new ImageUploader();
