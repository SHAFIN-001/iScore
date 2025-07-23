// Proctor API Functions
class ProctorAPI {
  constructor() {
    this.supabase = null;
    this.initSupabase();
  }

  async initSupabase() {
    // Wait for supabase to be loaded
    while (!window.supabaseClient) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    this.supabase = window.supabaseClient;
  }

  // Get proctor assignment for current tutor
  async getProctorAssignment(weekNumber) {
    try {
      const { data, error } = await this.supabase
        .from('proctor_allocation')
        .select(`
          *,
          student:user_information!student_id(full_name, email, phone)
        `)
        .eq('proctor_id', (await this.supabase.auth.getUser()).data.user.id)
        .eq('week_number', weekNumber);

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Upload subject-wise answer papers
  async uploadSubjectAnswers(examId, studentId, weekNumber, subject, files, onProgress) {
    try {
      const uploadPromises = files.map(async (file, index) => {
        const fileName = `${subject.toLowerCase()}_${examId}_${studentId}_${Date.now()}_${index}.${file.name.split('.').pop()}`;
        const { data, error } = await this.supabase.storage
          .from('uploads')
          .upload(`answer-papers/${fileName}`, file);

        if (error) {
          console.error('Storage upload error:', error);
          throw error;
        }
        
        // Update progress
        if (onProgress) {
          onProgress(index + 1, files.length, subject);
        }
        
        // Get the public URL for the uploaded file
        const { data: { publicUrl } } = this.supabase.storage
          .from('uploads')
          .getPublicUrl(`answer-papers/${fileName}`);
        
        return publicUrl;
      });

      const results = await Promise.all(uploadPromises);
      return { success: true, data: results };
    } catch (error) {
      console.error('Upload error:', error);
      return { success: false, error: error.message };
    }
  }

  // Save answer set to database
  async saveAnswerSet(examId, studentId, weekNumber, subjectImages) {
    try {
      // Check if answer set already exists
      const { data: existing } = await this.supabase
        .from('answer_sets')
        .select('id')
        .eq('exam_id', examId)
        .eq('student_id', studentId)
        .eq('week_number', weekNumber)
        .single();

      const answerSetData = {
        exam_id: examId,
        student_id: studentId,
        proctor_id: (await this.supabase.auth.getUser()).data.user.id,
        week_number: weekNumber,
        physics_images: subjectImages.physics || [],
        chemistry_images: subjectImages.chemistry || [],
        math_images: subjectImages.math || [],
        biology_images: subjectImages.biology || [],
        total_images_count: Object.values(subjectImages).flat().length,
        upload_status: 'completed'
      };

      let result;
      if (existing) {
        // Update existing answer set
        const { data, error } = await this.supabase
          .from('answer_sets')
          .update(answerSetData)
          .eq('id', existing.id)
          .select();
        result = { data, error };
      } else {
        // Insert new answer set
        const { data, error } = await this.supabase
          .from('answer_sets')
          .insert(answerSetData)
          .select();
        result = { data, error };
      }

      if (result.error) throw result.error;
      return { success: true, data: result.data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get uploaded answer sets for proctor
  async getUploadedAnswerSets(weekNumber) {
    try {
      const { data, error } = await this.supabase
        .from('answer_sets')
        .select(`
          *,
          student:user_information!student_id(full_name, email),
          exam:core_exam_metadata!exam_id(title, subject)
        `)
        .eq('proctor_id', (await this.supabase.auth.getUser()).data.user.id)
        .eq('week_number', weekNumber);

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Check upload window timing based on exam end time
  isUploadWindowOpen(examData) {
    if (!examData) return false;
    
    const now = new Date();
    const examStart = new Date(examData.scheduled_at);
    const examEnd = new Date(examStart.getTime() + (examData.duration_minutes * 60 * 1000));
    const uploadWindowEnd = new Date(examEnd.getTime() + (10 * 60 * 1000)); // 10 minutes after exam ends
    
    // Upload window: exam end time to exam end time + 10 minutes
    return (now >= examEnd && now <= uploadWindowEnd);
  }

  // Get time until upload window based on exam end time
  getTimeUntilUploadWindow(examData) {
    if (!examData) return 0;
    
    const now = new Date();
    const examStart = new Date(examData.scheduled_at);
    const examEnd = new Date(examStart.getTime() + (examData.duration_minutes * 60 * 1000));
    const uploadWindowStart = examEnd; // Upload window starts when exam ends
    
    if (now < uploadWindowStart) {
      return uploadWindowStart - now;
    }
    
    return 0; // Upload window is open or has passed
  }
}

// Initialize and export proctor API
window.proctorAPI = new ProctorAPI();