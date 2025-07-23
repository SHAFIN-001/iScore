
// Authentication management utility
class AuthManager {
  constructor() {
    this.initSupabase();
  }

  async initSupabase() {
    while (!window.supabaseClient) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    this.supabase = window.supabaseClient;
  }

  // Check if user is logged in
  isLoggedIn() {
    return localStorage.getItem('isLoggedIn') === 'true';
  }

  // Check if user is logged in and email is verified
  isEmailVerified() {
    const userData = JSON.parse(localStorage.getItem('userData') || '{}');
    return this.isLoggedIn() && userData.email_confirmed_at;
  }

  // Get current user data
  getCurrentUser() {
    if (this.isLoggedIn()) {
      return {
        user: JSON.parse(localStorage.getItem('userData') || '{}'),
        profile: JSON.parse(localStorage.getItem('userProfile') || '{}')
      };
    }
    return null;
  }

  // Set user session
  setUserSession(user, profile) {
    localStorage.setItem('isLoggedIn', 'true');
    localStorage.setItem('userData', JSON.stringify(user));
    localStorage.setItem('userProfile', JSON.stringify(profile));
  }

  // Clear user session
  clearUserSession() {
    localStorage.removeItem('isLoggedIn');
    localStorage.removeItem('userData');
    localStorage.removeItem('userProfile');
  }

  // Logout user and redirect to login
  logout() {
    this.clearUserSession();
    window.location.href = '../auth/login.html';
  }

  // Get user role
  getUserRole() {
    const user = this.getCurrentUser();
    return user?.profile?.role || 'student';
  }

  // Redirect based on role
  redirectToDashboard() {
    const role = this.getUserRole();
    const redirectMap = {
      admin: '../dashboards/admin-dashboard.html',
      tutor: '../dashboards/tutor-dashboard.html',
      parent: '../dashboards/parent-dashboard.html',
      student: '../dashboards/student-dashboard.html'
    };
    
    window.location.href = redirectMap[role] || redirectMap.student;
  }

  // Protect routes - redirect to login if not authenticated or email not verified
  requireAuth() {
    if (!this.isLoggedIn()) {
      window.location.href = '../auth/login.html';
      return false;
    }
    
    if (!this.isEmailVerified()) {
      alert('Please verify your email address before accessing the dashboard.');
      this.logout();
      return false;
    }
    
    return true;
  }

  // Protect admin routes
  requireAdmin() {
    if (!this.requireAuth()) return false;
    
    if (this.getUserRole() !== 'admin') {
      this.redirectToDashboard();
      return false;
    }
    return true;
  }

  // Generate QR code for address
  generateAddressQR(userProfile) {
    const addressData = {
      name: userProfile.full_name,
      division: userProfile.division,
      district: userProfile.district,
      upazila: userProfile.upazila,
      city: userProfile.city,
      phone: userProfile.phone
    };
    
    return btoa(JSON.stringify(addressData));
  }

  // Parse address QR
  parseAddressQR(qrData) {
    try {
      return JSON.parse(atob(qrData));
    } catch (error) {
      console.error('Invalid QR data:', error);
      return null;
    }
  }
}

// Initialize global auth manager
window.authManager = new AuthManager();

// Auto-redirect if already logged in on auth pages
if (window.location.pathname.includes('/auth/')) {
  if (window.authManager.isLoggedIn()) {
    window.authManager.redirectToDashboard();
  }
}
