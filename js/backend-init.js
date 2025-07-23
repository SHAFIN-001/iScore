// Backend Initialization Script
// This script initializes all backend services and APIs

class BackendService {
  constructor() {
    this.isInitialized = false;
    this.services = {};
    this.init();
  }

  async init() {
    try {
      console.log('🚀 Initializing Backend Services...');

      // Load Supabase SDK
      await this.loadSupabaseSDK();

      // Initialize Supabase config
      await this.initializeSupabase();

      // Initialize all API services
      await this.initializeServices();

      // Set up auth state listener
      this.setupAuthListener();

      this.isInitialized = true;
      console.log('✅ Backend Services Initialized Successfully');

      // Dispatch custom event when backend is ready
      window.dispatchEvent(new CustomEvent('backendReady'));

    } catch (error) {
      console.error('❌ Backend Initialization Failed:', error);
    }
  }

  async loadSupabaseSDK() {
    return new Promise((resolve, reject) => {
      if (window.supabase) {
        resolve();
        return;
      }

      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
      script.onload = () => {
        console.log('📦 Supabase SDK Loaded');
        resolve();
      };
      script.onerror = () => reject(new Error('Failed to load Supabase SDK'));
      document.head.appendChild(script);
    });
  }

  async initializeSupabase() {
    // Check if client already exists to prevent multiple instances
    if (window.supabaseClient) {
      console.log('🔗 Supabase Client Already Initialized');
      return;
    }

    const SUPABASE_URL = 'https://szjekvevdgzlqbifzutd.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6amVrdmV2ZGd6bHFiaWZ6dXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNjI2NzYsImV4cCI6MjA2NjkzODY3Nn0.etbROeMcUnITa8h5pPlVqe38Q-_HEmN_M9UZDwfDl0g';

    window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    console.log('🔗 Supabase Client Initialized');
  }

  async initializeServices() {
    // Wait for API classes to be available
    const maxRetries = 100;
    let retries = 0;

    // Check for API classes with more detailed logging
    while (retries < maxRetries) {
      const services = {
        userAPI: window.userAPI,
        examAPI: window.examAPI,
        proctorAPI: window.proctorAPI,
        evaluationAPI: window.evaluationAPI,
        paymentAPI: window.paymentAPI
      };

      

      // Check if essential services are available (userAPI is required, others are optional)
      if (services.userAPI) {
        // Create placeholder services for missing APIs
        if (!services.examAPI) {
          window.examAPI = { initialized: false };
        }
        if (!services.proctorAPI) {
          window.proctorAPI = { initialized: false };
        }
        if (!services.evaluationAPI) {
          window.evaluationAPI = { initialized: false };
        }
        if (!services.paymentAPI) {
          window.paymentAPI = { initialized: false };
        }
        break;
      }

      await new Promise(resolve => setTimeout(resolve, 200));
      retries++;
    }

    if (retries >= maxRetries) {
      console.error('Available services:', {
        userAPI: !!window.userAPI,
        examAPI: !!window.examAPI,
        proctorAPI: !!window.proctorAPI,
        evaluationAPI: !!window.evaluationAPI,
        paymentAPI: !!window.paymentAPI
      });
      throw new Error('Essential API services not available after 20 seconds');
    }

    this.services = {
      user: window.userAPI,
      exam: window.examAPI,
      proctor: window.proctorAPI,
      evaluation: window.evaluationAPI,
      payment: window.paymentAPI
    };

    console.log('🔧 API Services Connected');
  }

  setupAuthListener() {
    if (!window.supabaseClient) return;

    window.supabaseClient.auth.onAuthStateChange((event, session) => {
      console.log('🔐 Auth State Changed:', event);

      if (event === 'SIGNED_IN') {
        this.handleUserSignIn(session);
      } else if (event === 'SIGNED_OUT') {
        this.handleUserSignOut();
      }
    });
  }

  async handleUserSignIn(session) {
    try {
      // Get user profile
      const profile = await this.services.user.getUserProfile(session.user.id);

      // Store user data in localStorage
      localStorage.setItem('currentUser', JSON.stringify({
        id: session.user.id,
        email: session.user.email,
        profile: profile
      }));

      // Dispatch custom event
      window.dispatchEvent(new CustomEvent('userSignedIn', { 
        detail: { user: session.user, profile } 
      }));

      console.log('👤 User Signed In:', profile?.full_name || session.user.email);
    } catch (error) {
      console.error('Error handling sign in:', error);
    }
  }

  handleUserSignOut() {
    // Clear user data
    localStorage.removeItem('currentUser');

    // Dispatch custom event
    window.dispatchEvent(new CustomEvent('userSignedOut'));

    console.log('👋 User Signed Out');
  }

  // Utility methods
  async getCurrentUser() {
    try {
      const { data: { user } } = await window.supabaseClient.auth.getUser();
      if (user) {
        const profile = await this.services.user.getUserProfile(user.id);
        return { user, profile };
      }
      return null;
    } catch (error) {
      console.error('Error getting current user:', error);
      return null;
    }
  }

  getService(serviceName) {
    return this.services[serviceName];
  }

  isReady() {
    return this.isInitialized;
  }
}

// Initialize backend service
window.backendService = new BackendService();

// Helper function to wait for backend to be ready
window.waitForBackend = () => {
  return new Promise((resolve) => {
    if (window.backendService.isReady()) {
      resolve();
    } else {
      window.addEventListener('backendReady', resolve, { once: true });
    }
  });
};