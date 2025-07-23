// Exam API Functions
class ExamAPI {
  constructor() {
    this.supabase = null;
    this.initSupabase();
  }

  async initSupabase() {
    while (!window.supabaseClient) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    this.supabase = window.supabaseClient;
  }

  // Create new iCup exam
  async createExam(examData) {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .insert(examData)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get all exams
  async getAllExams() {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .select('*')
        .eq('is_archived', false)
        .order('scheduled_at', { ascending: true });

      if (error) throw error;
      return { success: true, data: data || [] };
    } catch (error) {
      console.error('getAllExams error:', error);
      return { success: false, error: error.message };
    }
  }

  // Get exam by ID
  async getExamById(examId) {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .select('*')
        .eq('exam_id', examId)
        .single();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get exams by week
  async getExamsByWeek(weekNumber) {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .select('*')
        .eq('week_number', weekNumber)
        .eq('is_archived', false);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Enroll student in exam
  async enrollStudent(userId, weekNumber) {
    try {
      const { data, error } = await this.supabase
        .from('student_enrollment')
        .upsert({
          user_id: userId,
          week_number: weekNumber,
          enrolled: true
        });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Check if student is enrolled in the latest exam
  async isStudentEnrolled(userId, weekNumber = null) {
    try {
      // If no week number provided, get the latest exam's week number
      if (!weekNumber) {
        const latestExam = await this.getCurrentExam();
        if (!latestExam.success || !latestExam.data) {
          return false;
        }
        weekNumber = latestExam.data.week_number;
      }

      // Check ONLY in student_enrollment table
      const { data: enrollmentData, error: enrollmentError } = await this.supabase
        .from('student_enrollment')
        .select('enrolled')
        .eq('user_id', userId)
        .eq('week_number', weekNumber)
        .eq('enrolled', true);

      if (enrollmentError) {
        console.error('Error checking student enrollment:', enrollmentError);
        return false;
      }

      return enrollmentData && enrollmentData.length > 0;
    } catch (error) {
      console.error('Error checking student enrollment:', error);
      return false;
    }
  }

  // Get enrolled students for a week
  async getEnrolledStudents(weekNumber) {
    try {
      const { data, error } = await this.supabase
        .from('student_enrollment')
        .select(`
          user_id,
          user_information (
            full_name,
            email,
            phone,
            district,
            city
          )
        `)
        .eq('week_number', weekNumber)
        .eq('enrolled', true);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Update exam
  async updateExam(examId, updates) {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .update(updates)
        .eq('exam_id', examId)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Archive exam
  async archiveExam(examId) {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .update({ is_archived: true })
        .eq('exam_id', examId);

      if (error) throw error;
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Direct enrollment method for tutors to enroll students
  async enrollStudentDirectly(studentUserId, tutorUserId, examId = null) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Get current exam if no examId provided
      let currentExam;
      if (!examId) {
        const examResult = await this.getCurrentExam();
        if (!examResult.success || !examResult.data) {
          throw new Error('No current exam available');
        }
        currentExam = examResult.data;
        examId = currentExam.exam_id;
      } else {
        const examResult = await this.getExamById(examId);
        if (!examResult.success) {
          throw new Error('Exam not found');
        }
        currentExam = examResult.data;
      }

      console.log('Enrolling student directly:', { studentUserId, examId, weekNumber: currentExam.week_number });

      // Insert into student_enrollment table
      const { error: enrollmentError } = await this.supabase
        .from('student_enrollment')
        .upsert({
          user_id: studentUserId,
          week_number: currentExam.week_number,
          enrolled: true,
          enrolled_at: new Date().toISOString()
        });

      if (enrollmentError) {
        console.error('Error inserting into student_enrollment:', enrollmentError);
      }

      // Also create an approved enrollment request record
      const { data: studentData } = await this.supabase
        .from('user_information')
        .select('full_name, email')
        .eq('user_id', studentUserId)
        .single();

      const { error: requestError } = await this.supabase
        .from('enrollment_requests')
        .upsert({
          student_user_id: studentUserId,
          student_full_name: studentData?.full_name || 'Unknown Student',
          student_email: studentData?.email || '',
          tutor_user_id: tutorUserId,
          exam_id: examId,
          week_number: currentExam.week_number,
          status: 'approved',
          payment_method: 'tutor_sponsored',
          payment_amount: currentExam.fee || 0,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

      if (requestError) {
        console.error('Error inserting enrollment request:', requestError);
      }

      // Send notification to student
      const { data: tutorData } = await this.supabase
        .from('user_information')
        .select('full_name')
        .eq('user_id', tutorUserId)
        .single();

      const tutorName = tutorData?.full_name || 'Your tutor';

      await this.supabase
        .from('notifications')
        .insert({
          user_id: studentUserId,
          title: 'Enrollment Confirmed',
          message: `${tutorName} has enrolled you in iCup Week ${currentExam.week_number}. You can now participate in the exam.`,
          type: 'enrollment_approved',
          created_at: new Date().toISOString()
        });

      return { success: true, data: { examId, weekNumber: currentExam.week_number } };
    } catch (error) {
      console.error('Error in direct enrollment:', error);
      return { success: false, error: error.message };
    }
  }

  // Get upcoming exams
  async getUpcomingExams() {
    try {
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .select('*')
        .gte('scheduled_at', new Date().toISOString())
        .eq('is_archived', false)
        .order('scheduled_at', { ascending: true });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get current exam (exam with highest week number)
  async getCurrentExam() {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      console.log('Getting current exam - checking database...');

      // Get all non-archived exams, ordered by week number descending
      const { data, error } = await this.supabase
        .from('icup_exam_metadata')
        .select('*')
        .eq('is_archived', false)
        .order('week_number', { ascending: false })
        .limit(1);

      if (error) {
        console.error('Database error in getCurrentExam:', error);
        throw error;
      }

      console.log('getCurrentExam raw query result:', data);

      if (!data || data.length === 0) {
        console.log('No active exams found in database');
        return { success: true, data: null };
      }

      const latestExam = data[0];
      console.log('getCurrentExam found latest exam:', {
        exam_id: latestExam.exam_id,
        title: latestExam.title,
        week_number: latestExam.week_number,
        is_archived: latestExam.is_archived
      });

      return { success: true, data: latestExam };
    } catch (error) {
      console.error('getCurrentExam error:', error);
      return { success: false, error: error.message };
    }
  }

  // Check if student is enrolled in the latest exam specifically
  async isStudentEnrolledInLatestExam(userId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Get the latest exam
      const latestExamResult = await this.getCurrentExam();
      if (!latestExamResult.success || !latestExamResult.data) {
        return false;
      }

      const latestWeekNumber = latestExamResult.data.week_number;

      // Check ONLY in student_enrollment table
      const { data: enrollmentData, error: enrollmentError } = await this.supabase
        .from('student_enrollment')
        .select('enrolled')
        .eq('user_id', userId)
        .eq('week_number', latestWeekNumber)
        .eq('enrolled', true);

      if (enrollmentError) {
        console.error('Error checking student enrollment:', enrollmentError);
        return false;
      }

      return enrollmentData && enrollmentData.length > 0;
    } catch (error) {
      console.error('Error checking latest exam enrollment:', error);
      return false;
    }
  }

  // Get current exam for payment (same as getCurrentExam but with explicit name for payment flow)
  async getCurrentExamForPayment() {
    try {
      console.log('getCurrentExamForPayment called...');
      
      // First try the regular getCurrentExam
      const result = await this.getCurrentExam();
      
      if (result.success && result.data) {
        console.log('getCurrentExamForPayment success:', result.data);
        return result;
      }
      
      // If no current exam, try getting all exams as fallback
      console.log('No current exam found, trying getAllExams fallback...');
      const allExamsResult = await this.getAllExams();
      
      if (allExamsResult.success && allExamsResult.data && allExamsResult.data.length > 0) {
        // Sort by week number descending and take the latest
        const sortedExams = allExamsResult.data
          .filter(exam => !exam.is_archived)
          .sort((a, b) => b.week_number - a.week_number);
        
        if (sortedExams.length > 0) {
          console.log('Found latest exam via fallback:', sortedExams[0]);
          return { success: true, data: sortedExams[0] };
        }
      }
      
      console.log('No active exams found via any method');
      return { success: true, data: null };
    } catch (error) {
      console.error('getCurrentExamForPayment error:', error);
      return { success: false, error: error.message };
    }
  }
}

// Initialize and export exam API
window.examAPI = new ExamAPI();