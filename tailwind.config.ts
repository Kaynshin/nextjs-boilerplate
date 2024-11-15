/** @format */

import type { Config } from 'tailwindcss';

export default {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        background: 'var(--background)',
        foreground: 'var(--foreground)',
        grid: '#FF0000',
        white: '#FFFFFF',
        black: '#000000',
        primary: '#FBECE7',
        secondary: '#563828',
        accent: '#FF0000',
      },
      fontFamily: {
        inter: 'var(--font-inter)',
      },
      spacing: {
        'figma-margin': '24px',
        'figma-gutter': '20px',
        'figma-width': '1440px',
      },
    },
  },
  plugins: [],
} satisfies Config;
