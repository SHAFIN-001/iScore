// Supabase Configuration
const SUPABASE_URL = 'https://szjekvevdgzlqbifzutd.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6amVrdmV2ZGd6bHFiaWZ6dXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNjI2NzYsImV4cCI6MjA2NjkzODY3Nn0.etbROeMcUnITa8h5pPlVqe38Q-_HEmN_M9UZDwfDl0g';

// Initialize Supabase client (using CDN for simplicity)
let supabase;

// Load Supabase from CDN only if not already loaded
if (typeof window !== 'undefined' && !window.supabase) {
  // Client-side initialization
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
  script.onload = () => {
    // Don't create another client if one already exists
    if (!window.supabaseClient) {
      supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      
    }
  };
  script.onerror = () => {
    console.error('Failed to load Supabase client');
  };
  document.head.appendChild(script);
}

// Export configuration
window.SUPABASE_CONFIG = {
  url: SUPABASE_URL,
  anonKey: SUPABASE_ANON_KEY,
  getClient: () => supabase
};