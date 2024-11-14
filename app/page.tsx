/** @format */
import Image from 'next/image';

export default function Home() {
  return (
    <div className="flex flex-col items-center justify-center gap-20 h-screen">
      <Image
        className="dark:invert"
        src="/assets/svgs/next.svg"
        alt="Next.js logo"
        width={180}
        height={38}
        priority
      />
      <p className="w-[400px] font-inter">
        Lorem, ipsum dolor sit amet consectetur adipisicing elit. Aspernatur quibusdam quam facilis
        accusamus natus asperiores praesentium, culpa ut soluta voluptatibus quaerat pariatur eius
        expedita molestiae vel explicabo commodi ab perspiciatis!
      </p>
    </div>
  );
}
