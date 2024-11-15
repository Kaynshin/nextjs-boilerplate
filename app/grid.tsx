/** @format */
'use client';

import { useToggleGrid } from '@hooks/useToggleGrid';

const gridConfig = {
  cols: 12,
};

export default function Grid() {
  const isGridVisible = useToggleGrid();

  const renderCols = () => {
    return Array.from({ length: gridConfig.cols }, (_, index) => (
      <div className="w-full h-full bg-grid opacity-10" key={index} />
    ));
  };

  return (
    <>
      {isGridVisible && (
        <div className="absolute z-50 w-screen h-screen flex gap-figma-gutter px-figma-margin">
          {renderCols()}
        </div>
      )}
    </>
  );
}
