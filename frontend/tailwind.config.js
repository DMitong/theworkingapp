/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        navy:    { DEFAULT: '#1B2A4A', light: '#2D4070' },
        teal:    { DEFAULT: '#0D7377', light: '#14A098', subtle: '#E6F4F1' },
        slate:   { DEFAULT: '#4A6580' },
        accent:  { DEFAULT: '#E8B84B' },
        surface: { DEFAULT: '#F2F4F7', card: '#FFFFFF' },
      },
      fontFamily: {
        sans: ['Inter var', 'Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      borderRadius: { card: '12px', pill: '999px' },
      boxShadow: {
        card: '0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.04)',
        elevated: '0 4px 16px rgba(0,0,0,.10)',
      },
    },
  },
  plugins: [],
};
