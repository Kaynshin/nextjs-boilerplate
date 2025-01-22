/** @format */

import type { Config } from 'tailwindcss';
import { breakpoints } from './app/config/grid';

export default {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'media',
  theme: {
    screens: {
      ...breakpoints,
    },
    extend: {
      colors: {
        background: 'var(--background)',
        foreground: 'var(--foreground)',
        white: '#FFFFFF',
        black: '#000000',
        primary: '#FBECE7',
        secondary: '#563828',
        accent: '#FF0000',
      },
      fontFamily: {
        inter: 'var(--font-inter)',
      },
    },
  },
  plugins: [],
} satisfies Config;
