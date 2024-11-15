/** @format */
'use client';

import { useState, useEffect } from 'react';

export function useToggleGrid(initialVisibility: boolean = true) {
  const [isGridVisible, setIsGridVisible] = useState(initialVisibility);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.shiftKey && event.key === 'G') {
        setIsGridVisible((prev) => !prev);
      }
    };

    window.addEventListener('keydown', handleKeyDown);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

  return isGridVisible;
}
