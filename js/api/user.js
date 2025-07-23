// User API Functions
class UserAPI {
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

  // Register new user
  async registerUser(userData) {
    try {
      // Check if user already exists in user_information table
      const { data: existingUser } = await this.supabase
        .from('user_information')
        .select('user_id')
        .eq('email', userData.email)
        .single();

      if (existingUser) {
        throw new Error('User already exists with this email');
      }

      // Sign up user first
      const { data: authData, error: authError } = await this.supabase.auth.signUp({
        email: userData.email,
        password: userData.password
      });

      if (authError) {
        console.error('Auth error:', authError);
        throw authError;
      }

      console.log('Auth successful:', authData);

      // Wait a moment for auth to settle
      await new Promise(resolve => setTimeout(resolve, 500));

      // Prepare user information with explicit column mapping using user_id
      const userInfo = {
        user_id: authData.user.id,
        username: userData.username,
        email: userData.email,
        phone: userData.phone || null,
        full_name: userData.fullName || userData.full_name,
        nick_name: userData.nickName || userData.nick_name || null,
        role: userData.role,
        dob: userData.dob || null,
        gender: userData.gender || null,
        district: userData.district || null,
        city: userData.city || null,
        bio: userData.bio || null,
        bkash_number: userData.bkashNumber || userData.bkash_number || null,
        profile_picture: userData.profile_picture || null
      };

      // Test schema cache first
      const { data: schemaTest, error: schemaError } = await this.supabase.rpc('test_schema_cache');
      console.log('Schema cache test:', schemaTest);

      let insertSuccess = false;

      // Try direct SQL insert via RPC first
      const { data: insertResult, error: insertError } = await this.supabase.rpc('insert_user_info', {
        user_data: userInfo
      });

      if (!insertError && insertResult?.success) {
        console.log('RPC insert successful');
        insertSuccess = true;
      } else {
        console.error('RPC insert error:', insertError);

        // Try regular insert as fallback
        const { error: fallbackError } = await this.supabase
          .from('user_information')
          .insert(userInfo);

        if (!fallbackError) {
          console.log('Fallback insert successful');
          insertSuccess = true;
        } else {
          console.error('Fallback insert failed:', fallbackError);
          throw fallbackError;
        }
      }

      if (!insertSuccess) {
        throw new Error('Failed to insert user information');
      }

      // Insert role-specific information
      console.log('Inserting role-specific information for role:', userData.role);

      if (userData.role === 'student') {
        const studentInfo = userData.studentInfo || {};
        if (userData.location_qr) {
          studentInfo.location_qr = userData.location_qr;
        }
        console.log('Inserting student info...');
        await this.insertStudentInfo(authData.user.id, studentInfo);
        console.log('Student info inserted successfully');
      } else if (userData.role === 'tutor' && userData.tutorInfo) {
        console.log('Inserting tutor info...');
        await this.insertTutorInfo(authData.user.id, userData.tutorInfo);
        console.log('Tutor info inserted successfully');
      } else if (userData.role === 'parent') {
        console.log('Inserting parent info...');
        userData.parentInfo = {
          students: userData.parentInfo?.students || [],
          tutors: [] // Will be populated automatically based on children's tutors
        };
        await this.insertUserAdditionalInfo(authData.user.id, userData);
        console.log('Parent info inserted successfully');
      }

      // Get the created profile
      const profile = await this.getUserProfile(authData.user.id);

      return { success: true, user: authData.user, profile };
    } catch (error) {
      console.error('Registration error details:', error);
      return { success: false, error: error.message };
    }
  }

  // Login user
  async loginUser(email, password) {
    try {
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      // Get user profile
      const profile = await this.getUserProfile(data.user.id);

      return { success: true, user: data.user, profile };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get user profile
  async getUserProfile(userId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      const { data, error } = await this.supabase
        .from('user_information')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error fetching user profile:', error);
      return null;
    }
  }

  // Update user profile
  async updateUserProfile(userId, updates) {
    try {
      const { data, error } = await this.supabase
        .from('user_information')
        .update(updates)
        .eq('user_id', userId);

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

    // Method to connect student to tutor
  async connectStudentToTutor(studentId, tutorId) {
    try {
      console.log('Connecting student to tutor:', { studentId, tutorId });

      const { data, error } = await this.supabase
        .rpc('connect_student_to_tutor', {
          student_id: studentId,
          tutor_id: tutorId
        });

      if (error) {
        console.error('Error connecting student to tutor:', error);
        throw error;
      }

      console.log('Student connected to tutor successfully:', data);
      return data;
    } catch (error) {
      console.error('Connect student to tutor failed:', error);
      throw error;
    }
  }

  // Insert student additional info
  async insertStudentInfo(userId, studentInfo) {
    try {
      const studentData = {
        user_id: userId,
        tutors: studentInfo.tutors || [],
        parents: studentInfo.parents || [],
        institution: studentInfo.institution || null,
        ssc_batch: studentInfo.ssc_batch || null,
        location_qr: studentInfo.location_qr || null
      };

      console.log('Inserting student data with location_qr:', studentData.location_qr);

      const { error } = await this.supabase
        .from('student_additional_info')
        .insert(studentData);

      if (error) throw error;

      console.log('Student info inserted successfully with location_qr');

      // Send notifications to connected tutors
      if (studentInfo.tutors && studentInfo.tutors.length > 0) {
        await this.sendStudentConnectionNotifications(userId, studentInfo.tutors);
      }
    } catch (error) {
      console.error('Error inserting student info:', error);
      throw error;
    }
  }

  // Insert tutor additional info
  async insertTutorInfo(userId, tutorInfo) {
    try {
      const studentIds = tutorInfo.students || [];

      // First, check if any of the selected students already have tutors
      if (studentIds.length > 0) {
        const { data: existingStudents, error: checkError } = await this.supabase
          .from('student_additional_info')
          .select('user_id, tutors')
          .in('user_id', studentIds);

        if (checkError && checkError.code !== 'PGRST116') {
          throw checkError;
        }

        // Check for students who already have tutors
        const studentsWithTutors = existingStudents?.filter(student => 
          student.tutors && student.tutors.length > 0
        ) || [];

        if (studentsWithTutors.length > 0) {
          // Get student names for better error message
          const { data: studentNames } = await this.supabase
            .from('user_information')
            .select('user_id, full_name')
            .in('user_id', studentsWithTutors.map(s => s.user_id));

          const names = studentNames?.map(s => s.full_name).join(', ') || 'Some students';
          throw new Error(`${names} already have tutors connected. Each student can only have one tutor.`);
        }
      }

      const tutorData = {
        user_id: userId,
        students: studentIds,
        institution: tutorInfo.institution || null,
        subject: tutorInfo.subject || null,
        batch: tutorInfo.batch || null,
        offered_subjects: tutorInfo.offered_subjects || [],
        class_levels: tutorInfo.class_levels || [],
        experience_years: tutorInfo.experience_years || 0
      };

      const { error } = await this.supabase
        .from('tutor_additional_info')
        .insert(tutorData);

      if (error) throw error;

      // Now update each student to include this tutor in their tutors list
      for (const studentId of studentIds) {
        try {
          // Get existing student info or create new record
          const { data: existingStudentInfo, error: fetchError } = await this.supabase
            .from('student_additional_info')
            .select('*')
            .eq('user_id', studentId)
            .single();

          if (fetchError && fetchError.code === 'PGRST116') {
            // Create new student record with this tutor
            const { error: insertError } = await this.supabase
              .from('student_additional_info')
              .insert({
                user_id: studentId,
                tutors: [userId],
                parents: [],
                institution: null,
                ssc_batch: null,
                location_qr: null
              });

            if (insertError) {
              console.error('Error creating student record:', insertError);
              continue;
            }
          } else if (fetchError) {
            console.error('Error fetching student info:', fetchError);
            continue;
          } else {
            // Update existing student record
            const currentTutors = existingStudentInfo.tutors || [];
            if (!currentTutors.includes(userId)) {
              const updatedTutors = [...currentTutors, userId];

              const { error: updateError } = await this.supabase
                .from('student_additional_info')
                .update({ tutors: updatedTutors })
                .eq('user_id', studentId);

              if (updateError) {
                console.error('Error updating student tutors:', updateError);
                continue;
              }
            }
          }

          console.log(`Successfully added tutor ${userId} to student ${studentId}`);
        } catch (error) {
          console.error(`Error processing student ${studentId}:`, error);
          continue;
        }
      }
    } catch (error) {
      console.error('Error inserting tutor info:', error);
      throw error;
    }
  }

  // Insert parent additional info
  async insertParentInfo(userId, parentInfo) {
    try {
      console.log('Inserting parent info for user:', userId);
      console.log('Parent info data:', parentInfo);

      const parentData = {
        user_id: userId,
        students: parentInfo.students || [],
        tutors: parentInfo.tutors || []
      };

      console.log('Prepared parent data for insertion:', parentData);

      const { data, error } = await this.supabase
        .from('parent_additional_info')
        .insert(parentData)
        .select();

      if (error) {
        console.error('Parent info insertion error:', error);
        throw error;
      }

      console.log('Parent info inserted successfully:', data);
    } catch (error) {
      console.error('Error inserting parent info:', error);
      throw error;
    }
  }

    // Insert student additional info
  async insertStudentAdditionalInfo(studentData) {
    try {
      console.log('Inserting student info...');

      // Use RPC function to bypass RLS for student-tutor connections
      const { data, error } = await this.supabase
        .rpc('insert_student_additional_info', {
          student_data: studentData
        });

      if (error) {
        console.error('Error inserting student info:', error);
        throw error;
      }

      console.log('Student additional info inserted:', data);
      return data;
    } catch (error) {
      console.error('Insert student additional info failed:', error);
      throw error;
    }
  }


  // Logout user
  async logoutUser() {
    try {
      const { error } = await this.supabase.auth.signOut();
      if (error) throw error;
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get current user
  async getCurrentUser() {
    try {
      // First check if we have a valid session
      const { data: { session }, error: sessionError } = await this.supabase.auth.getSession();
      
      if (sessionError) {
        console.error('Session error:', sessionError);
        return null;
      }

      if (!session || !session.user) {
        console.log('No active session found');
        return null;
      }

      const user = session.user;
      const profile = await this.getUserProfile(user.id);
      
      if (!profile) {
        console.error('User profile not found for user:', user.id);
        return null;
      }

      return { user, profile };
    } catch (error) {
      console.error('Error getting current user:', error);
      return null;
    }
  }

  // Reset password
  async resetPassword(email) {
    try {
      const { error } = await this.supabase.auth.resetPasswordForEmail(email);
      if (error) throw error;
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Send notification to tutors when student connects
  async sendStudentConnectionNotifications(studentId, tutorIds) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Get student name
      const { data: studentData } = await this.supabase
        .from('user_information')
        .select('full_name')
        .eq('user_id', studentId)
        .single();

      const studentName = studentData?.full_name || 'A student';

      // Insert notifications for each tutor
      const notifications = tutorIds.map(tutorId => ({
        user_id: tutorId,
        title: 'Student Connection Request',
        message: `${studentName} sent you a connection request during registration.`,
        type: 'student_connection',
        related_user_id: studentId,
        created_at: new Date().toISOString()
      }));

      const { error } = await this.supabase
        .from('notifications')
        .insert(notifications);

      if (error) {
        console.warn('Failed to send tutor notifications:', error);
      } else {
        console.log('Tutor notifications sent successfully');
      }
    } catch (error) {
      console.warn('Error sending tutor notifications:', error);
    }
  }

  // Get all users (admin function)
  async getAllUsers() {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      const { data, error } = await this.supabase
        .from('user_information')
        .select('*')
        .order('full_name', { ascending: true });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching all users:', error);
      return { success: false, error: error.message };
    }
  }

  // Force schema reload using alternative method
  async forceSchemaReload() {
    try {
      const { error } = await this.supabase.rpc('force_schema_reload');
      if (error) console.warn('Schema reload failed:', error);
      else console.log('Schema reload initiated');
    } catch (error) {
      console.warn('Schema reload error:', error);
    }
  }

  // Get connected students for a tutor
  async getConnectedStudents(tutorId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Get tutor's students list
      const { data: tutorInfo, error: tutorError } = await this.supabase
        .from('tutor_additional_info')
        .select('students')
        .eq('user_id', tutorId)
        .single();

      if (tutorError && tutorError.code !== 'PGRST116') {
        throw tutorError;
      }

      const studentIds = tutorInfo?.students || [];

      if (studentIds.length === 0) {
        return [];
      }

      // Get student details
      const { data: students, error: studentsError } = await this.supabase
        .from('user_information')
        .select('user_id, full_name, email, profile_picture')
        .in('user_id', studentIds);

      if (studentsError) throw studentsError;

      return students || [];
    } catch (error) {
      console.error('Error fetching connected students:', error);
      return [];
    }
  }

  // Get connected tutors for a student
  async getConnectedTutors(studentId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Get student's tutors list
      const { data: studentInfo, error: studentError } = await this.supabase
        .from('student_additional_info')
        .select('tutors')
        .eq('user_id', studentId)
        .single();

      if (studentError && studentError.code !== 'PGRST116') {
        throw studentError;
      }

      const tutorIds = studentInfo?.tutors || [];

      if (tutorIds.length === 0) {
        return [];
      }

      // Get tutor details
      const { data: tutors, error: tutorsError } = await this.supabase
        .from('user_information')
        .select('user_id, full_name, email, profile_picture')
        .in('user_id', tutorIds);

      if (tutorsError) throw tutorsError;

      return tutors || [];
    } catch (error) {
      console.error('Error fetching connected tutors:', error);
      return [];
    }
  }

  // Accept student connection request
  async acceptStudentRequest(studentId, tutorId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Use RPC function to handle the connection
      const { data, error } = await this.supabase.rpc('accept_student_connection', {
        student_id: studentId,
        tutor_id: tutorId
      });

      if (error) {
        console.error('RPC error:', error);
        throw error;
      }

      // Mark the notification as read
      await this.supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', tutorId)
        .eq('related_user_id', studentId)
        .eq('type', 'student_connection');

      return { success: true };
    } catch (error) {
      console.error('Error accepting student request:', error);
      return { success: false, error: error.message };
    }
  }

  // Reject student connection request
  async rejectStudentRequest(studentId, tutorId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      // Mark the notification as read
      await this.supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', tutorId)
        .eq('related_user_id', studentId)
        .eq('type', 'student_connection');

      return { success: true };
    } catch (error) {
      console.error('Error rejecting student request:', error);
      return { success: false, error: error.message };
    }
  }

  // Get user notifications
  async getUserNotifications(userId) {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      const { data, error } = await this.supabase
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching notifications:', error);
      return [];
    }
  }

  // Get available students (students without tutors) for tutor selection
  async getAvailableStudents() {
    try {
      // Ensure supabase is initialized
      if (!this.supabase) {
        await this.initSupabase();
      }

      console.log('Fetching available students (no tutors)...');

      // Get all students first
      const { data: allStudents, error: allStudentsError } = await this.supabase
        .from('user_information')
        .select('user_id, full_name, email')
        .eq('role', 'student');

      if (allStudentsError) throw allStudentsError;

      if (!allStudents || allStudents.length === 0) {
        console.log('No students found in user_information');
        return [];
      }

      console.log('Total students in system:', allStudents.length);

      // Get ALL student records from student_additional_info with their tutors
      // Add cache-busting to ensure fresh data
      const { data: allStudentRecords, error: recordsError } = await this.supabase
        .from('student_additional_info')
        .select('user_id, tutors')
        .order('user_id');

      if (recordsError && recordsError.code !== 'PGRST116') {
        throw recordsError;
      }

      console.log('Student records from additional_info:', allStudentRecords);

      // Create a map of student_id -> tutors for easier lookup
      const studentTutorsMap = new Map();
      if (allStudentRecords) {
        allStudentRecords.forEach(record => {
          studentTutorsMap.set(record.user_id, record.tutors);
        });
      }

      // Filter available students
      const availableStudents = allStudents.filter(student => {
        const tutors = studentTutorsMap.get(student.user_id);
        
        // Student is available if:
        // 1. No record in student_additional_info (newly registered student)
        // 2. Record exists but tutors is null, undefined, or empty array
        const hasNoRecord = !studentTutorsMap.has(student.user_id);
        const hasEmptyTutors = tutors === null || tutors === undefined || (Array.isArray(tutors) && tutors.length === 0);
        
        const isAvailable = hasNoRecord || hasEmptyTutors;
        
        console.log(`🔍 Student Analysis: ${student.full_name} (ID: ${student.user_id})`);
        console.log(`   - Has record in additional_info: ${!hasNoRecord}`);
        console.log(`   - Tutors data: ${JSON.stringify(tutors)}`);
        console.log(`   - Tutors array type: ${Array.isArray(tutors) ? 'array' : typeof tutors}`);
        console.log(`   - Tutors length: ${Array.isArray(tutors) ? tutors.length : 'N/A'}`);
        console.log(`   - Has empty tutors: ${hasEmptyTutors}`);
        console.log(`   - Is available: ${isAvailable}`);
        console.log('---');
        
        return isAvailable;
      });

      console.log('Available students found:', availableStudents.length);
      console.log('Available students:', availableStudents.map(s => `${s.full_name} (${s.user_id})`));

      return availableStudents;
    } catch (error) {
      console.error('Error fetching available students:', error);
      return [];
    }
  }

  // Helper method to get user's additional info based on role
  async getUserAdditionalInfo(userId, role) {
    try {
      let tableName = '';
      switch (role) {
        case 'student':
          tableName = 'student_additional_info';
          break;
        case 'tutor':
          tableName = 'tutor_additional_info';
          break;
        case 'parent':
          tableName = 'parent_additional_info';
          break;
        default:
          throw new Error('Invalid role');
      }

      const { data, error } = await this.supabase
        .from(tableName)
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') {
        throw error;
      }

      return data;
    } catch (error) {
      console.error('Error getting user additional info:', error);
      throw error;
    }
  }

  async insertUserAdditionalInfo(userId, userData) {
            let additionalInfo = {};

            if (userData.role === 'student') {
                additionalInfo = {
                    user_id: userId,
                    institution: userData.studentInfo?.institution || null,
                    ssc_batch: userData.studentInfo?.ssc_batch || null,
                    tutors: userData.studentInfo?.tutors || [],
                    parents: userData.studentInfo?.parents || [],
                    location_qr: userData.studentInfo?.location_qr || null
                };

                console.log('Inserting student additional info with location_qr:', additionalInfo.location_qr);

                const { error } = await this.supabase
                    .from('student_additional_info')
                    .insert(additionalInfo);

                if (error) throw error;

                console.log('Student additional info inserted successfully with location_qr');

            } else if (userData.role === 'tutor') {
                additionalInfo = {
                    user_id: userId,
                    institution: userData.tutorInfo?.institution || null,
                    subject: userData.tutorInfo?.subject || null,
                    batch: userData.tutorInfo?.batch || null,
                    offered_subjects: userData.tutorInfo?.offered_subjects || [],
                    class_levels: userData.tutorInfo?.class_levels || [],
                    experience_years: userData.tutorInfo?.experience_years || 0,
                    students: userData.tutorInfo?.students || []
                };

                const { error } = await this.supabase
                    .from('tutor_additional_info')
                    .insert(additionalInfo);

                if (error) throw error;

            } else if (userData.role === 'parent') {
                const studentIds = userData.parentInfo?.students || [];
                console.log('Processing parent registration for students:', studentIds);

                // First, collect all tutors connected to the selected children
                const connectedTutors = new Set();

                // Process each student and update their parent list
                for (const studentId of studentIds) {
                    console.log('Processing student:', studentId);

                    try {
                        // Get current student info - try to get existing record first
                        const { data: existingStudentInfo, error: fetchError } = await this.supabase
                            .from('student_additional_info')
                            .select('*')
                            .eq('user_id', studentId)
                            .single();

                        let studentInfo = existingStudentInfo;

                        // If no existing record, create one
                        if (fetchError && fetchError.code === 'PGRST116') {
                            console.log('Creating new student record for:', studentId);
                            const { data: newStudentInfo, error: insertError } = await this.supabase
                                .from('student_additional_info')
                                .insert({
                                    user_id: studentId,
                                    tutors: [],
                                    parents: [userId],
                                    institution: null,
                                    ssc_batch: null,
                                    location_qr: null
                                })
                                .select()
                                .single();

                            if (insertError) {
                                console.error('Error creating student record:', insertError);
                                continue;
                            }
                            studentInfo = newStudentInfo;
                        } else if (fetchError) {
                            console.error('Error fetching student info:', fetchError);
                            continue;
                        } else {
                            // Check if student already has a parent - reject if they do
                            const currentParents = studentInfo?.parents || [];
                            if (currentParents.length > 0 && !currentParents.includes(userId)) {
                                console.error('Student already has a parent connected:', studentId);
                                throw new Error(`Student ${studentId} already has a parent connected. Each student can only have one parent.`);
                            } else if (!currentParents.includes(userId)) {
                                // Add this parent as the first/only parent
                                const updatedParents = [userId];
                                console.log('Setting student parent to:', updatedParents);

                                const { error: updateError } = await this.supabase
                                    .from('student_additional_info')
                                    .update({ parents: updatedParents })
                                    .eq('user_id', studentId);

                                if (updateError) {
                                    console.error('Error updating student parents:', updateError);
                                    continue;
                                } else {
                                    console.log('Successfully set student parent for:', studentId);
                                    studentInfo.parents = updatedParents;
                                }
                            }
                        }

                        // Collect tutors from this student
                        if (studentInfo && studentInfo.tutors && studentInfo.tutors.length > 0) {
                            console.log('Found tutors for student:', studentInfo.tutors);
                            studentInfo.tutors.forEach(tutorId => connectedTutors.add(tutorId));
                        }

                    } catch (error) {
                        console.error('Error processing student:', studentId, error);
                        continue;
                    }
                }

                // Create parent additional info with connected tutors
                const tutorArray = Array.from(connectedTutors);
                console.log('Creating parent info with tutors:', tutorArray);

                additionalInfo = {
                    user_id: userId,
                    students: studentIds,
                    tutors: tutorArray
                };

                const { error } = await this.supabase
                    .from('parent_additional_info')
                    .insert(additionalInfo);

                if (error) {
                    console.error('Error inserting parent info:', error);
                    throw error;
                }

                console.log('Successfully created parent info');

                // Update tutors to include this parent in their parents array
                for (const tutorId of connectedTutors) {
                    console.log('Updating tutor:', tutorId);

                    try {
                        // Get current tutor info
                        const { data: currentTutorInfo, error: tutorError } = await this.supabase
                            .from('tutor_additional_info')
                            .select('parents')
                            .eq('user_id', tutorId)
                            .single();

                        if (tutorError && tutorError.code !== 'PGRST116') {
                            console.error('Error fetching tutor info:', tutorError);
                            continue;
                        }

                        // Handle both existing and non-existing tutor records
                        if (tutorError && tutorError.code === 'PGRST116') {
                            // Create new tutor record with this parent
                            console.log('Creating tutor record with parent:', userId);
                            await this.supabase
                                .from('tutor_additional_info')
                                .insert({
                                    user_id: tutorId,
                                    parents: [userId],
                                    students: [],
                                    institution: null,
                                    subject: null,
                                    batch: null,
                                    offered_subjects: [],
                                    class_levels: [],
                                    experience_years: 0
                                });
                        } else {
                            // Update existing tutor record - allow multiple parents
                            const currentTutorParents = currentTutorInfo?.parents || [];
                            if (!currentTutorParents.includes(userId)) {
                                const updatedTutorParents = [...currentTutorParents, userId];
                                console.log('Updating tutor parents to:', updatedTutorParents);

                                const { error: updateTutorError } = await this.supabase
                                    .from('tutor_additional_info')
                                    .update({ parents: updatedTutorParents })
                                    .eq('user_id', tutorId);

                                if (updateTutorError) {
                                    console.error('Error updating tutor parents:', updateTutorError);
                                } else {
                                    console.log('Successfully updated tutor parents for:', tutorId);
                                }
                            }
                        }
                    } catch (error) {
                        console.error('Error processing tutor:', tutorId, error);
                        continue;
                    }
                }
            }
        }
}


// Initialize and export user API
window.userAPI = new UserAPI();