/** @format */

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

export const breakpoints = {
  mobile: '320px',
  'mobile-ls': '481px',
  tablet: '601px',
  'tablet-ls': '769px',
  desktop: '1025px',
};

export const gridConfig = {
  mobile: {
    columns: 4,
    spacing: {
      gutter: 'gap-[20px]',
      margin: 'px-[12px]',
    },
  },
  'mobile-ls': {
    columns: 4,
    spacing: {
      gutter: 'gap-[20px]',
      margin: 'px-[12px]',
    },
  },
  tablet: {
    columns: 8,
    spacing: {
      gutter: 'gap-[20px]',
      margin: 'px-[16px]',
    },
  },
  'tablet-ls': {
    columns: 8,
    spacing: {
      gutter: 'gap-[20px]',
      margin: 'px-[16px]',
    },
  },
  desktop: {
    columns: 12,
    spacing: {
      gutter: 'gap-[20px]',
      margin: 'px-[24px]',
    },
  },
};
