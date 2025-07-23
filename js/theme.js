// Enhanced Theme Management System for iScore
class ThemeManager {
    constructor() {
        this.currentTheme = this.getStoredTheme() || this.getPreferredTheme();
        this.themeToggle = null;
        this.init();
    }

    init() {
        // Apply theme immediately
        this.applyTheme(this.currentTheme);
        this.setupThemeToggle();
        this.bindEvents();
        console.log('Theme Manager initialized with theme:', this.currentTheme);
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
        // Force remove any existing theme attributes
        document.documentElement.removeAttribute('data-theme');
        document.body.removeAttribute('data-theme');

        // Apply new theme
        document.documentElement.setAttribute('data-theme', theme);
        document.body.setAttribute('data-theme', theme);

        // Force update CSS custom properties
        if (theme === 'dark') {
            document.documentElement.style.setProperty('--bg-primary', '#0f172a');
            document.documentElement.style.setProperty('--bg-secondary', '#1e293b');
            document.documentElement.style.setProperty('--text-primary', '#f1f5f9');
            document.documentElement.style.setProperty('--text-secondary', '#94a3b8');
            document.documentElement.style.setProperty('--border-color', '#334155');
            document.documentElement.style.setProperty('--blue-primary', '#60a5fa');
        } else {
            document.documentElement.style.setProperty('--bg-primary', '#ffffff');
            document.documentElement.style.setProperty('--bg-secondary', '#f8fafc');
            document.documentElement.style.setProperty('--text-primary', '#0f172a');
            document.documentElement.style.setProperty('--text-secondary', '#64748b');
            document.documentElement.style.setProperty('--border-color', '#e2e8f0');
            document.documentElement.style.setProperty('--blue-primary', '#3b82f6');
        }

        this.currentTheme = theme;
        this.storeTheme(theme);
        this.updateThemeIcon(theme);

        console.log('Theme applied:', theme);
    }

    updateThemeIcon(theme) {
        const toggleBtn = document.querySelector('.theme-toggle-btn');
        if (!toggleBtn) return;

        // Ensure proper HTML structure
        if (!toggleBtn.querySelector('.theme-icons')) {
            toggleBtn.innerHTML = `
                <div class="theme-icons">
                    <span class="theme-icon light material-symbols-outlined">light_mode</span>
                    <span class="theme-icon dark material-symbols-outlined">dark_mode</span>
                </div>
            `;
        }

        const lightIcons = document.querySelectorAll('.theme-icon.light');
        const darkIcons = document.querySelectorAll('.theme-icon.dark');

        if (theme === 'dark') {
            // Show light icon (to switch to light)
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
        } else {
            // Show dark icon (to switch to dark)
            darkIcons.forEach(icon => {
                icon.style.opacity = '1';
                icon.style.visibility = 'visible';
                icon.style.transform = 'rotate(0deg) scale(1)';
                icon.style.color = '#000000';
            });
            lightIcons.forEach(icon => {
                icon.style.opacity = '0';
                icon.style.visibility = 'hidden';
                icon.style.transform = 'rotate(180deg) scale(0.5)';
            });
        }
    }

    setupThemeToggle() {
        this.themeToggle = document.getElementById('theme-toggle');
        if (this.themeToggle) {
            this.themeToggle.addEventListener('click', (e) => {
                e.preventDefault();
                this.toggleTheme();
            });
        }
    }

    toggleTheme() {
        const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        console.log('Toggling theme from', this.currentTheme, 'to', newTheme);
        this.applyTheme(newTheme);

        // Dispatch custom event
        window.dispatchEvent(new CustomEvent('themeChanged', {
            detail: { theme: newTheme }
        }));
    }

    bindEvents() {
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

        // Keyboard shortcut
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'T') {
                e.preventDefault();
                this.toggleTheme();
            }
        });
    }

    getCurrentTheme() {
        return this.currentTheme;
    }

    setTheme(theme) {
        if (theme === 'light' || theme === 'dark') {
            this.applyTheme(theme);
        }
    }
}

// Initialize theme manager immediately
let themeManager;

// Function to initialize theme
function initializeTheme() {
    if (!window.themeManager) {
        window.themeManager = new ThemeManager();
        themeManager = window.themeManager;
    }
}

// Initialize immediately if DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeTheme);
} else {
    initializeTheme();
}

// Export for global access
window.ThemeManager = ThemeManager;
window.initializeTheme = initializeTheme;

console.log('Theme script loaded and initialized');

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

// Export classes to window object BEFORE initialization
window.GradientAnimationController = GradientAnimationController;
window.ScrollAnimations = ScrollAnimations;
window.PerformanceOptimizer = PerformanceOptimizer;

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ThemeManager, GradientAnimationController, ScrollAnimations, PerformanceOptimizer };
}