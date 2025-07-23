
// Theme Management System for iScore

// Prevent duplicate class declarations
if (typeof window.ThemeManager !== 'undefined') {
  console.warn('ThemeManager already exists, skipping redefinition');
} else {

class ThemeManager {
  constructor() {
    this.currentTheme = this.getStoredTheme() || this.getPreferredTheme();
    this.themeToggle = null;
    this.transitionOverlay = null;
    
    this.init();
  }

  init() {
    this.applyTheme(this.currentTheme);
    this.createTransitionOverlay();
    this.bindEvents();
    this.setupThemeToggle();
  }

  getStoredTheme() {
    return localStorage.getItem('iScore-theme');
  }

  getPreferredTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  storeTheme(theme) {
    localStorage.setItem('iScore-theme', theme);
  }

  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    this.updateThemeIcon(theme);
    this.currentTheme = theme;
    this.storeTheme(theme);
  }

  updateThemeIcon(theme) {
    // Ensure the toggle has the correct HTML structure
    const toggleBtn = document.querySelector('.theme-toggle-btn');
    if (toggleBtn && !toggleBtn.querySelector('.theme-icons')) {
      toggleBtn.innerHTML = `
        <div class="theme-icons">
          <span class="theme-icon light material-symbols-outlined">light_mode</span>
          <span class="theme-icon dark material-symbols-outlined">dark_mode</span>
        </div>
      `;
    }
    
    // Force update the visibility based on current theme
    const lightIcons = document.querySelectorAll('.theme-icon.light');
    const darkIcons = document.querySelectorAll('.theme-icon.dark');
    
    if (theme === 'light') {
      lightIcons.forEach(icon => {
        icon.style.opacity = '0';
        icon.style.visibility = 'hidden';
        icon.style.transform = 'rotate(180deg) scale(0.5)';
      });
      darkIcons.forEach(icon => {
        icon.style.opacity = '1';
        icon.style.visibility = 'visible';
        icon.style.transform = 'rotate(0deg) scale(1)';
        icon.style.color = '#000000';
      });
    } else {
      lightIcons.forEach(icon => {
        icon.style.opacity = '1';
        icon.style.visibility = 'visible';
        icon.style.transform = 'rotate(0deg) scale(1)';
        icon.style.color = '#ffffff';
      });
      darkIcons.forEach(icon => {
        icon.style.opacity = '0';
        icon.style.visibility = 'hidden';
        icon.style.transform = 'rotate(-180deg) scale(0.5)';
      });
    }
  }

  createTransitionOverlay() {
    this.transitionOverlay = document.createElement('div');
    this.transitionOverlay.className = 'theme-transition';
    document.body.appendChild(this.transitionOverlay);
  }

  setupThemeToggle() {
    this.themeToggle = document.getElementById('theme-toggle');
    if (!this.themeToggle) {
      console.warn('Theme toggle button not found');
      return;
    }
  }

  toggleTheme() {
    const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';
    
    // Show transition overlay
    this.transitionOverlay.classList.add('active');
    
    // Apply new theme after short delay
    setTimeout(() => {
      this.applyTheme(newTheme);
      
      // Hide transition overlay
      setTimeout(() => {
        this.transitionOverlay.classList.remove('active');
      }, 150);
    }, 150);

    // Dispatch custom event for other components
    window.dispatchEvent(new CustomEvent('themeChanged', {
      detail: { theme: newTheme }
    }));

    // Add haptic feedback if supported
    if ('vibrate' in navigator) {
      navigator.vibrate(50);
    }
  }

  bindEvents() {
    // Theme toggle button click
    document.addEventListener('click', (e) => {
      if (e.target.closest('.theme-toggle-btn')) {
        e.preventDefault();
        this.toggleTheme();
      }
    });

    // Keyboard shortcut (Ctrl/Cmd + Shift + T)
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'T') {
        e.preventDefault();
        this.toggleTheme();
      }
    });

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!this.getStoredTheme()) {
        this.applyTheme(e.matches ? 'dark' : 'light');
      }
    });

    // Listen for storage changes (sync across tabs)
    window.addEventListener('storage', (e) => {
      if (e.key === 'iScore-theme' && e.newValue !== this.currentTheme) {
        this.applyTheme(e.newValue);
      }
    });
  }

  // Public method to get current theme
  getCurrentTheme() {
    return this.currentTheme;
  }

  // Public method to set theme programmatically
  setTheme(theme) {
    if (theme === 'light' || theme === 'dark') {
      this.applyTheme(theme);
    }
  }
}

// Gradient Animation Controller
class GradientAnimationController {
  constructor() {
    this.orbs = [];
    this.animationFrameId = null;
    this.init();
  }

  init() {
    this.createOrbs();
    this.startAnimation();
    this.bindEvents();
  }

  createOrbs() {
    const orbElements = document.querySelectorAll('.gradient-orb');
    
    orbElements.forEach((orb, index) => {
      this.orbs.push({
        element: orb,
        baseX: parseFloat(orb.style.left || '0'),
        baseY: parseFloat(orb.style.top || '0'),
        offsetX: 0,
        offsetY: 0,
        speed: 0.5 + Math.random() * 0.5,
        direction: Math.random() * Math.PI * 2,
        radius: 50 + Math.random() * 30
      });
    });
  }

  updateOrbs() {
    this.orbs.forEach((orb, index) => {
      // Create floating motion
      orb.direction += 0.01;
      orb.offsetX = Math.sin(orb.direction) * orb.radius;
      orb.offsetY = Math.cos(orb.direction * 0.7) * orb.radius * 0.5;

      // Apply transforms
      orb.element.style.transform = `translate(${orb.offsetX}px, ${orb.offsetY}px)`;
    });
  }

  startAnimation() {
    const animate = () => {
      this.updateOrbs();
      this.animationFrameId = requestAnimationFrame(animate);
    };
    animate();
  }

  stopAnimation() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
  }

  bindEvents() {
    // Pause animations when tab is not visible
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.stopAnimation();
      } else {
        this.startAnimation();
      }
    });

    // Respect reduced motion preferences
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.stopAnimation();
    }
  }
}

// Scroll-triggered animations
class ScrollAnimations {
  constructor() {
    this.observer = null;
    this.init();
  }

  init() {
    this.setupIntersectionObserver();
    this.addAnimationClasses();
  }

  setupIntersectionObserver() {
    const options = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    };

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
        }
      });
    }, options);
  }

  addAnimationClasses() {
    const animatedElements = document.querySelectorAll(
      '.feature-card, .about-feature, .stat, .hero-card'
    );

    animatedElements.forEach((el, index) => {
      el.classList.add('fade-in-up');
      el.style.transitionDelay = `${index * 0.1}s`;
      this.observer.observe(el);
    });
  }
}

// Performance optimizer
class PerformanceOptimizer {
  constructor() {
    this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.init();
  }

  init() {
    if (this.reducedMotion) {
      this.disableAnimations();
    }
    
    this.optimizeImages();
    this.preloadCriticalAssets();
  }

  disableAnimations() {
    const style = document.createElement('style');
    style.textContent = `
      *, *::before, *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
      }
    `;
    document.head.appendChild(style);
  }

  optimizeImages() {
    const images = document.querySelectorAll('img[src*="placeholder"]');
    images.forEach(img => {
      // Replace with actual optimized images or use CSS backgrounds
      img.style.background = 'linear-gradient(135deg, #3b82f6, #1e40af)';
      img.style.borderRadius = '8px';
    });
  }

  preloadCriticalAssets() {
    // Preload critical fonts and assets
    const criticalAssets = [
      'css/main.css',
      'css/theme.css',
      'css/responsive.css'
    ];

    criticalAssets.forEach(asset => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.as = asset.endsWith('.css') ? 'style' : 'script';
      link.href = asset;
      document.head.appendChild(link);
    });
  }
}

// Export ThemeManager to window object
window.ThemeManager = ThemeManager;

}

// Initialize everything when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  // Initialize theme management only if not already initialized
  if (!window.themeManager) {
    window.themeManager = new window.ThemeManager();
  }
  
  // Initialize gradient animations (only if not reduced motion and not already initialized)
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches && !window.gradientController) {
    window.gradientController = new GradientAnimationController();
  }
  
  // Initialize scroll animations only if not already initialized
  if (!window.scrollAnimations) {
    window.scrollAnimations = new ScrollAnimations();
  }
  
  // Initialize performance optimizations only if not already initialized
  if (!window.performanceOptimizer) {
    window.performanceOptimizer = new PerformanceOptimizer();
  }
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ThemeManager, GradientAnimationController, ScrollAnimations };
}
