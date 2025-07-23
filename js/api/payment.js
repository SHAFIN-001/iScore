// Payment API Functions
class PaymentAPI {
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

  // Process payment
  async processPayment(paymentData) {
    try {
      const { data, error } = await this.supabase
        .from('payments')
        .insert({
          user_id: paymentData.userId,
          exam_id: paymentData.examId,
          amount: paymentData.amount,
          payment_method: paymentData.method,
          transaction_id: paymentData.transactionId,
          status: 'pending'
        });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Get payment history
  async getPaymentHistory(userId) {
    try {
      const { data, error } = await this.supabase
        .from('payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return { success: true, data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Submit enrollment request with payment proof
  async submitEnrollmentRequest(enrollmentData) {
    try {
      console.log('📝 Submitting enrollment request with data:', {
        student_full_name: enrollmentData.student_full_name,
        student_user_id: enrollmentData.student_user_id,
        transaction_id: enrollmentData.transaction_id,
        bkash_number: enrollmentData.bkash_number,
        exam_name: enrollmentData.exam_name,
        exam_id: enrollmentData.exam_id,
        week_number: enrollmentData.week_number,
        fee: enrollmentData.fee,
        pay_number: enrollmentData.pay_number,
        additional_information: enrollmentData.additional_information,
        has_screenshot: !!enrollmentData.screenshot,
        screenshot_file_name: enrollmentData.screenshot?.name,
        screenshot_file_size: enrollmentData.screenshot?.size
      });

      // First, upload the screenshot if it exists
      let screenshotUrl = null;
      if (enrollmentData.screenshot) {
        try {
          // Use the main uploads bucket instead of payment_screenshots
          const fileExt = enrollmentData.screenshot.name?.split('.').pop() || 'jpg';
          const fileName = `payment_screenshots/${enrollmentData.student_user_id}_${Date.now()}.${fileExt}`;

          const { data: uploadData, error: uploadError } = await this.supabase.storage
            .from('uploads')
            .upload(fileName, enrollmentData.screenshot, {
              cacheControl: '3600',
              upsert: false
            });

          if (uploadError) {
            console.error('Upload error:', uploadError);
            throw new Error(`Failed to upload screenshot: ${uploadError.message}`);
          }

          // Get public URL for the uploaded screenshot
          const { data: urlData } = this.supabase.storage
            .from('uploads')
            .getPublicUrl(fileName);

          screenshotUrl = urlData.publicUrl;
          console.log('Screenshot uploaded successfully:', screenshotUrl);
        } catch (uploadError) {
          console.error('Screenshot upload failed:', uploadError);
          throw new Error(`Screenshot upload failed: ${uploadError.message}`);
        }
      }

      // Insert enrollment request
      const { data, error } = await this.supabase
        .from('enrollment_requests')
        .insert({
          student_full_name: enrollmentData.student_full_name,
          student_user_id: enrollmentData.student_user_id,
          transaction_id: enrollmentData.transaction_id,
          bkash_number: enrollmentData.bkash_number,
          screenshot_url: screenshotUrl,
          additional_information: enrollmentData.additional_information,
          exam_name: enrollmentData.exam_name,
          exam_id: enrollmentData.exam_id,
          week_number: enrollmentData.week_number,
          fee: enrollmentData.fee,
          pay_number: enrollmentData.pay_number,
          status: 'pending'
        })
        .select();

      if (error) throw error;

      console.log('✅ Enrollment request stored in database:', {
        id: data[0].id,
        student_full_name: data[0].student_full_name,
        student_user_id: data[0].student_user_id,
        transaction_id: data[0].transaction_id,
        bkash_number: data[0].bkash_number,
        exam_name: data[0].exam_name,
        week_number: data[0].week_number,
        fee: data[0].fee,
        screenshot_url: data[0].screenshot_url,
        status: data[0].status,
        created_at: data[0].created_at
      });

      // Create admin notification for new enrollment request
      try {
        console.log('🔔 Creating admin notifications for enrollment request...');

        // Get all admin users
        const { data: adminUsers, error: adminError } = await this.supabase
          .from('user_information')
          .select('user_id')
          .eq('role', 'admin');

        console.log('📋 Admin users found:', adminUsers);

        if (adminError) {
          console.error('Error fetching admin users:', adminError);
          throw adminError;
        }

        if (adminUsers && adminUsers.length > 0) {
          // Create notification for each admin
          const adminNotifications = adminUsers.map(admin => ({
            user_id: admin.user_id,
            title: 'New iCup Enrollment Request',
            message: `${enrollmentData.student_full_name} has submitted an enrollment request for ${enrollmentData.exam_name} (Week ${enrollmentData.week_number})`,
            type: 'enrollment_request',
            related_user_id: enrollmentData.student_user_id,
            created_at: new Date().toISOString(),
            read: false,
            hidden: false,
            data: {
              enrollment_request_id: data[0].id,
              student_user_id: enrollmentData.student_user_id,
              student_full_name: enrollmentData.student_full_name,
              transaction_id: enrollmentData.transaction_id,
              bkash_number: enrollmentData.bkash_number,
              exam_name: enrollmentData.exam_name,
              exam_id: enrollmentData.exam_id,
              week_number: enrollmentData.week_number,
              fee: enrollmentData.fee,
              pay_number: enrollmentData.pay_number,
              screenshot_url: screenshotUrl,
              additional_information: enrollmentData.additional_information,
              paid_by: enrollmentData.paid_by || enrollmentData.student_full_name,
              paid_by_user_id: enrollmentData.paid_by_user_id || enrollmentData.student_user_id,
              payment_type: enrollmentData.payment_type || 'student'
            }
          }));

          console.log('📤 Inserting admin notifications:', adminNotifications.length, 'notifications');

          const { data: notificationData, error: notificationError } = await this.supabase
            .from('notifications')
            .insert(adminNotifications)
            .select();

          if (notificationError) {
            console.error('Error inserting admin notifications:', notificationError);
            throw notificationError;
          }

          console.log('✅ Admin notifications created successfully:', notificationData);
        } else {
          console.warn('⚠️ No admin users found to notify');
        }
      } catch (notificationError) {
        console.error('❌ Failed to create admin notifications:', notificationError);
        // Don't throw here, as the enrollment was successful
      }

      return { success: true, data: data[0] };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

// Initialize and export payment API
window.paymentAPI = new PaymentAPI();

// Submit student payment (self-payment)
async function submitStudentPayment(paymentData, examData) {
    try {
        console.log('📝 Submitting student payment request with data:', paymentData);

        const currentUser = await getCurrentUser();
        if (!currentUser) {
            throw new Error('User not authenticated');
        }

        // Store enrollment request
        const { data: enrollmentData, error: enrollmentError } = await window.supabaseClient
            .from('icup_enrollment_requests')
            .insert({
                student_full_name: currentUser.full_name,
                student_user_id: currentUser.user_id || currentUser.id,
                transaction_id: paymentData.transaction_id,
                bkash_number: paymentData.bkash_number,
                exam_name: examData.title,
                week_number: examData.week_number,
                fee: examData.fee,
                screenshot_url: paymentData.screenshot_url,
                status: 'pending',
                additional_information: paymentData.additional_information || ''
            })
            .select()
            .single();

        if (enrollmentError) throw enrollmentError;

        console.log('✅ Enrollment request stored in database:', enrollmentData);

        // Create notification data
        const notificationData = {
            paid_by: currentUser.full_name,
            payment_type: 'student',
            exam_name: examData.title,
            exam_id: examData.exam_id,
            week_number: examData.week_number,
            fee: examData.fee,
            pay_number: examData.pay_number,
            student_full_name: currentUser.full_name,
            student_user_id: currentUser.user_id || currentUser.id,
            transaction_id: paymentData.transaction_id,
            bkash_number: paymentData.bkash_number,
            screenshot_url: paymentData.screenshot_url,
            enrollment_request_id: enrollmentData.id,
            paid_by_user_id: currentUser.user_id || currentUser.id,
            additional_information: paymentData.additional_information || ''
        };

        // Create admin notifications
        await createAdminNotifications(
            'New iCup Enrollment Request',
            `${currentUser.full_name} has submitted an enrollment request for ${examData.title} (Week ${examData.week_number})`,
            'enrollment_request',
            currentUser.user_id || currentUser.id,
            notificationData
        );

        return {
            success: true,
            message: 'Payment submitted successfully! Admin will review your request.',
            data: enrollmentData
        };

    } catch (error) {
        console.error('❌ Error submitting student payment:', error);
        throw error;
    }
}

// Submit parent payment (for child)
async function submitParentPayment(paymentData, examData, studentData) {
    try {
        console.log('📝 Submitting parent payment request with data:', paymentData);

        const currentUser = await getCurrentUser();
        if (!currentUser) {
            throw new Error('User not authenticated');
        }

        // Store enrollment request
        const { data: enrollmentData, error: enrollmentError } = await window.supabaseClient
            .from('icup_enrollment_requests')
            .insert({
                student_full_name: studentData.full_name,
                student_user_id: studentData.user_id,
                transaction_id: paymentData.transaction_id,
                bkash_number: paymentData.bkash_number,
                exam_name: examData.title,
                week_number: examData.week_number,
                fee: examData.fee,
                screenshot_url: paymentData.screenshot_url,
                status: 'pending',
                additional_information: paymentData.additional_information || ''
            })
            .select()
            .single();

        if (enrollmentError) throw enrollmentError;

        console.log('✅ Enrollment request stored in database:', enrollmentData);

        // Create notification data
        const notificationData = {
            paid_by: currentUser.full_name,
            payment_type: 'parent',
            exam_name: examData.title,
            exam_id: examData.exam_id,
            week_number: examData.week_number,
            fee: examData.fee,
            pay_number: examData.pay_number,
            student_full_name: studentData.full_name,
            student_user_id: studentData.user_id,
            transaction_id: paymentData.transaction_id,
            bkash_number: paymentData.bkash_number,
            screenshot_url: paymentData.screenshot_url,
            enrollment_request_id: enrollmentData.id,
            paid_by_user_id: currentUser.user_id || currentUser.id,
            additional_information: paymentData.additional_information || ''
        };

        // Create admin notifications
        await createAdminNotifications(
            'New iCup Enrollment Request',
            `${studentData.full_name} has been enrolled by parent ${currentUser.full_name} for ${examData.title} (Week ${examData.week_number})`,
            'enrollment_request',
            studentData.user_id,
            notificationData
        );

        return {
            success: true,
            message: 'Payment submitted successfully! Admin will review your request.',
            data: enrollmentData
        };

    } catch (error) {
        console.error('❌ Error submitting parent payment:', error);
        throw error;
    }
}

// Helper function to get current user
async function getCurrentUser() {
    try {
        const backendUser = await window.userAPI.getCurrentUser();
        if (!backendUser || !backendUser.profile) {
            return null;
        }
        return {
            ...backendUser.user,
            ...backendUser.profile,
            user_id: backendUser.user.id,
            full_name: backendUser.profile.full_name
        };
    } catch (error) {
        console.error('Error getting current user:', error);
        return null;
    }
}

// Helper function to create admin notifications
async function createAdminNotifications(title, message, type, relatedUserId, data) {
    try {
        console.log('🔔 Creating admin notifications...');

        // Get all admin users
        const { data: adminUsers, error: adminError } = await window.supabaseClient
            .from('user_information')
            .select('user_id')
            .eq('role', 'admin');

        if (adminError) {
            console.error('Error fetching admin users:', adminError);
            throw adminError;
        }

        if (adminUsers && adminUsers.length > 0) {
            // Create notification for each admin
            const adminNotifications = adminUsers.map(admin => ({
                user_id: admin.user_id,
                title: title,
                message: message,
                type: type,
                related_user_id: relatedUserId,
                created_at: new Date().toISOString(),
                read: false,
                hidden: false,
                data: data
            }));

            console.log('📤 Inserting admin notifications:', adminNotifications.length, 'notifications');

            const { data: notificationData, error: notificationError } = await window.supabaseClient
                .from('notifications')
                .insert(adminNotifications)
                .select();

            if (notificationError) {
                console.error('Error inserting admin notifications:', notificationError);
                throw notificationError;
            }

            console.log('✅ Admin notifications created successfully:', notificationData);
        } else {
            console.warn('⚠️ No admin users found to notify');
        }
    } catch (error) {
        console.error('❌ Failed to create admin notifications:', error);
        // Don't throw here, as the enrollment was successful
    }
}