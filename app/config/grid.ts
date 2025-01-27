/** @format */

import '@/styles/globals.css';

export type BreakpointsTypes = {
  mobile: string;
  'mobile-ls': string;
  tablet: string;
  'tablet-ls': string;
  desktop: string;
};

export interface GridConfigTypes {
  columns: number;
  spacing: {
    gutter: string;
    margin: string;
  };
}

export interface GridConfigurations {
  mobile: GridConfigTypes;
  tablet: GridConfigTypes;
  desktop: GridConfigTypes;
}

// Must match breakpoints in globals.css
export const breakpoints = {
  mobile: '320px',
  'mobile-ls': '481px',
  tablet: '601px',
  'tablet-ls': '769px',
  desktop: '1025px',
};

const gridColumns = {
  mobile: 4,
  'mobile-ls': 4,
  tablet: 8,
  'tablet-ls': 8,
  desktop: 12,
};

export const gridConfig = {
  mobile: {
    columns: gridColumns.mobile,
    spacing: {
      gutter: 'gap-(--gutter-mobile)',
      margin: 'px-(--margin-mobile)',
    },
  },
  'mobile-ls': {
    columns: gridColumns['mobile-ls'],
    spacing: {
      gutter: 'gap-(--gutter-mobile-ls)',
      margin: 'px-(--margin-mobile-ls)',
    },
  },
  tablet: {
    columns: gridColumns.tablet,
    spacing: {
      gutter: 'gap-(--gutter-tablet)',
      margin: 'px-(--margin-tablet)',
    },
  },
  'tablet-ls': {
    columns: gridColumns['tablet-ls'],
    spacing: {
      gutter: 'gap-(--gutter-tablet-ls)',
      margin: 'px-(--margin-tablet-ls)',
    },
  },
  desktop: {
    columns: gridColumns.desktop,
    spacing: {
      gutter: 'gap-(--gutter-desktop)',
      margin: 'px-(--margin-desktop)',
    },
  },
};
