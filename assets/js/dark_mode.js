// Dark mode management
export const DarkMode = {
  mounted() {
    // Initialize dark mode based on user preference or system setting
    this.initializeDarkMode()
    
    // Listen for dark mode toggle
    this.el.addEventListener("click", () => this.toggleDarkMode())
  },

  initializeDarkMode() {
    // Check for saved preference or default to system preference
    const savedTheme = localStorage.getItem('theme')
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    if (savedTheme === 'dark' || (!savedTheme && systemPrefersDark)) {
      document.documentElement.classList.add('dark')
      this.updateToggleIcon(true)
    } else {
      document.documentElement.classList.remove('dark')
      this.updateToggleIcon(false)
    }

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        if (e.matches) {
          document.documentElement.classList.add('dark')
          this.updateToggleIcon(true)
        } else {
          document.documentElement.classList.remove('dark')
          this.updateToggleIcon(false)
        }
      }
    })
  },

  toggleDarkMode() {
    const isDark = document.documentElement.classList.contains('dark')
    
    if (isDark) {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('theme', 'light')
      this.updateToggleIcon(false)
    } else {
      document.documentElement.classList.add('dark')
      localStorage.setItem('theme', 'dark')
      this.updateToggleIcon(true)
    }
  },

  updateToggleIcon(isDark) {
    const sunIcon = this.el.querySelector('.sun-icon')
    const moonIcon = this.el.querySelector('.moon-icon')
    
    if (sunIcon && moonIcon) {
      if (isDark) {
        sunIcon.classList.remove('hidden')
        moonIcon.classList.add('hidden')
      } else {
        sunIcon.classList.add('hidden')
        moonIcon.classList.remove('hidden')
      }
    }
  }
}

// Initialize dark mode on page load (for non-LiveView pages)
document.addEventListener('DOMContentLoaded', () => {
  const savedTheme = localStorage.getItem('theme')
  const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  
  if (savedTheme === 'dark' || (!savedTheme && systemPrefersDark)) {
    document.documentElement.classList.add('dark')
  } else {
    document.documentElement.classList.remove('dark')
  }
})