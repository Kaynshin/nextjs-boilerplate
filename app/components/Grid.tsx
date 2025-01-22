/** @format */
'use client';

import { useToggleGrid } from '@hooks/useToggleGrid';
import { useBreakpoint } from '@hooks/useBreakpoints';

import { gridConfig } from '@config/grid';

import type { GridConfigurations } from '@config/grid';

export default function Grid() {
  const isGridVisible = useToggleGrid();
  const currentBreakpoint = useBreakpoint();

  console.log('currentBreakpoint', currentBreakpoint);

  const currentGridSettings = gridConfig[currentBreakpoint as keyof GridConfigurations];

  const classNameGap = `${currentGridSettings?.spacing['gutter']}`;
  const classNameMargin = `${currentGridSettings?.spacing['margin']}`;

  const renderCols = (nbCols: number) => {
    return Array.from({ length: nbCols }, (_, index) => (
      <div
        className="w-full h-full mobile:bg-green-500 tablet:bg-blue-500 desktop:bg-red-500 opacity-10"
        key={index}
      />
    ));
  };

  return (
    <>
      {isGridVisible && (
        <div className={`w-screen h-screen absolute z-50 flex ${classNameMargin} ${classNameGap}`}>
          {renderCols(currentGridSettings?.columns)}
          <span className="absolute right-5 bottom-5 rounded-full bg-black text-white p-2">
            {currentBreakpoint}
          </span>
        </div>
      )}
    </>
  );
}
