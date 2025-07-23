// Evaluation API Functions
class EvaluationAPI {
  constructor() {
    this.supabase = null;
    this.initSupabase();
  }

  async initSupabase() {
    while (!window.SUPABASE_CONFIG?.getClient()) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    this.supabase = window.SUPABASE_CONFIG.getClient();
  }

  // Allocate answer set for evaluation
  async allocateForEvaluation(allocationData) {
    try {
      const { data, error } = await this.supabase
        .from('evaluation_allocation')
        .insert(allocationData)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation allocations
  async getEvaluationAllocations() {
    try {
      const { data, error } = await this.supabase
        .from('evaluation_allocation')
        .select(`
          *,
          answer_sets (
            *,
            user_information!answer_sets_student_id_fkey (
              full_name,
              email
            )
          )
        `)
        .order('sl_no', { ascending: true });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get allocations by evaluator
  async getAllocationsByEvaluator(evaluatorId) {
    try {
      const { data, error } = await this.supabase
        .from('evaluation_allocation')
        .select(`
          *,
          answer_sets (
            *,
            user_information!answer_sets_student_id_fkey (
              full_name,
              email
            )
          )
        `)
        .eq('evaluator_id', evaluatorId);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Submit evaluation
  async submitEvaluation(evaluationData) {
    try {
      const { data, error } = await this.supabase
        .from('answer_evaluation')
        .upsert(evaluationData)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation by answer set ID
  async getEvaluationByAnswerSet(answerSetId) {
    try {
      const { data, error } = await this.supabase
        .from('answer_evaluation')
        .select('*')
        .eq('answer_set_id', answerSetId)
        .single();

      if (error && error.code !== 'PGRST116') throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Update final marks
  async updateFinalMarks(marksData) {
    try {
      const { data, error } = await this.supabase
        .from('final_marks')
        .upsert(marksData)
        .select();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get final marks
  async getFinalMarks() {
    try {
      const { data, error } = await this.supabase
        .from('final_marks')
        .select(`
          *,
          user_information (
            full_name,
            email,
            district,
            city
          )
        `)
        .order('rank', { ascending: true });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Update leaderboard
  async updateLeaderboard(leaderboardData) {
    try {
      // Clear existing leaderboard
      await this.supabase.from('leaderboard').delete().neq('rank', 0);

      // Insert new leaderboard data
      const { data, error } = await this.supabase
        .from('leaderboard')
        .insert(leaderboardData)
        .select();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get leaderboard
  async getLeaderboard(limit = 100) {
    try {
      const { data, error } = await this.supabase
        .from('leaderboard')
        .select(`
          *,
          user_information (
            full_name,
            district,
            city,
            profile_picture
          )
        `)
        .order('rank', { ascending: true })
        .limit(limit);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation statistics
  async getEvaluationStats() {
    try {
      const [totalAllocations, completedEvaluations, pendingEvaluations] = await Promise.all([
        this.supabase.from('evaluation_allocation').select('*', { count: 'exact' }),
        this.supabase.from('answer_evaluation').select('*', { count: 'exact' }),
        this.supabase.from('evaluation_allocation').select('*', { count: 'exact' })
          .not('answer_set_id', 'in', 
            `(${await this.supabase.from('answer_evaluation').select('answer_set_id').then(r => r.data?.map(d => `'${d.answer_set_id}'`).join(',') || "''")})`)
      ]);

      return {
        success: true,
        data: {
          total: totalAllocations.count || 0,
          completed: completedEvaluations.count || 0,
          pending: pendingEvaluations.count || 0
        }
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluator allocations for an exam
  async getEvaluatorAllocations(examId, subject = null) {
    try {
      let query = this.supabase
        .from('evaluator_allocation')
        .select(`
          *,
          user_information (
            full_name,
            profile_picture
          )
        `)
        .eq('exam_id', examId);

      if (subject) {
        query = query.eq('subject', subject);
      }

      const { data, error } = await query.order('subject', { ascending: true });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get unassigned answer sets for an exam
  async getUnassignedAnswerSets(examId, subject = null) {
    try {
      let query = this.supabase
        .from('unassigned_answer_sets')
        .select('*')
        .eq('exam_id', examId);

      if (subject) {
        query = query.eq('subject', subject);
      }

      const { data, error } = await query;

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Save evaluator allocations
  async saveEvaluatorAllocations(allocations) {
    try {
      const { data, error } = await this.supabase
        .from('evaluator_allocation')
        .upsert(allocations, {
          onConflict: 'exam_id,subject,evaluator_id'
        })
        .select();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Save unassigned answer sets
  async saveUnassignedAnswerSets(examId, subject, answerSetIds) {
    try {
      const { data, error } = await this.supabase
        .from('unassigned_answer_sets')
        .upsert({
          exam_id: examId,
          subject: subject,
          answer_set_ids: answerSetIds
        }, {
          onConflict: 'exam_id,subject'
        })
        .select();

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get eligible evaluators for subjects
  async getEligibleEvaluators(subjects = null) {
    try {
      let query = this.supabase
        .from('evaluator_eligibility')
        .select(`
          *,
          user_information (
            user_id,
            full_name,
            profile_picture
          )
        `)
        .eq('is_eligible', true);

      if (subjects && subjects.length > 0) {
        query = query.or(
          subjects.map(subject => `eligible_subjects.cs.{"${subject}"}`).join(',')
        );
      }

      const { data, error } = await query;

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluator eligibility
  async getEvaluatorEligibility(tutorId = null) {
    try {
      let query = this.supabase
        .from('evaluator_eligibility')
        .select(`
          *,
          user_information!evaluator_eligibility_tutor_id_fkey (
            full_name,
            email
          )
        `);

      if (tutorId) {
        query = query.eq('tutor_id', tutorId);
      }

      const { data, error } = await query;

      if (error) throw error;
      return { success: true, data: tutorId ? data[0] : data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Add or update evaluator
  async upsertEvaluator(evaluatorData) {
    try {
      const { data, error } = await this.supabase
        .from('evaluator_eligibility')
        .upsert(evaluatorData)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Remove evaluator (set enabled to false)
  async removeEvaluator(evaluatorId) {
    try {
      const { data, error } = await this.supabase
        .from('evaluator_eligibility')
        .update({ enabled: false })
        .eq('id', evaluatorId)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation requests (pending)
  async getEvaluationRequests() {
    try {
      const { data, error } = await this.supabase
        .from('evaluator_eligibility')
        .select(`
          *,
          user_information!evaluator_eligibility_tutor_id_fkey (
            full_name,
            email
          )
        `)
        .eq('enabled', false)
        .not('request_message', 'is', null)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation assignments for a tutor
  async getTutorEvaluationAssignments(tutorId, examId = null) {
    try {
      let query = this.supabase
        .from('evaluation_allocation')
        .select(`
          *,
          answer_sets!evaluation_allocation_answer_set_id_fkey (
            student_id,
            subject,
            submission_timestamp
          )
        `)
        .eq('evaluator_id', tutorId);

      if (examId) {
        query = query.eq('exam_id', examId);
      }

      const { data, error } = await query.order('assigned_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Update evaluation status
  async updateEvaluationStatus(allocationId, status) {
    try {
      const updateData = { evaluation_status: status };
      if (status === 'completed') {
        updateData.evaluated_at = new Date().toISOString();
      }

      const { data, error } = await this.supabase
        .from('evaluation_allocation')
        .update(updateData)
        .eq('id', allocationId)
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get evaluation assignment statistics
  async getEvaluationStats(examId) {
    try {
      const { data, error } = await this.supabase
        .from('evaluation_allocation')
        .select('evaluation_status, subject')
        .eq('exam_id', examId);

      if (error) throw error;

      const stats = {
        total: data.length,
        pending: data.filter(a => a.evaluation_status === 'pending').length,
        in_progress: data.filter(a => a.evaluation_status === 'in_progress').length,
        completed: data.filter(a => a.evaluation_status === 'completed').length,
        by_subject: {}
      };

      // Group by subject
      data.forEach(assignment => {
        if (!stats.by_subject[assignment.subject]) {
          stats.by_subject[assignment.subject] = {
            total: 0,
            pending: 0,
            in_progress: 0,
            completed: 0
          };
        }
        stats.by_subject[assignment.subject].total++;
        stats.by_subject[assignment.subject][assignment.evaluation_status]++;
      });

      return { success: true, data: stats };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

// Initialize and export evaluation API
window.evaluationAPI = new EvaluationAPI();