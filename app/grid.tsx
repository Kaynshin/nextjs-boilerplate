/** @format */
'use client';

import { useToggleGrid } from '@hooks/useToggleGrid';

type GridSize = 'full' | 'fixed';

interface GridConfig {
  cols: number;
  size: GridSize;
}

const gridConfig: GridConfig = {
  cols: 12,
  size: 'full',
};

export default function Grid() {
  const isGridVisible = useToggleGrid();

  const gridSizeVariants = {
    full: 'w-screen',
    fixed: 'top-1/2 left-1/2 translate-x-[-50%] translate-y-[-50%] w-figma-width',
  };

  const renderCols = () => {
    return Array.from({ length: gridConfig.cols }, (_, index) => (
      <div className="w-full h-full bg-grid opacity-10" key={index} />
    ));
  };

  return (
    <>
      {isGridVisible && (
        <div
          className={`${
            gridSizeVariants[gridConfig.size]
          } absolute z-50 h-screen flex gap-figma-gutter px-figma-margin`}
        >
          {renderCols()}
        </div>
      )}
    </>
  );
}
