/** @format */

import { useState, useEffect } from 'react';
import { breakpoints } from '@config/grid';

export const useBreakpoint = () => {
  const [breakpoint, setBreakpoint] = useState<string>('');

  useEffect(() => {
    const handleResize = () => {
      const width = window.innerWidth;
      let current = 'mobile'; // Default value for screens smaller than the smallest breakpoint
      for (const [key, value] of Object.entries(breakpoints)) {
        if (width >= parseInt(value)) {
          current = key;
        }
      }
      setBreakpoint(current);
    };

    handleResize();
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return breakpoint;
};
