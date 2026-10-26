import { useEffect, useState, type ReactNode } from 'react';
import './studio-launch.css';

export function StudioLaunch({ children }: { children: ReactNode }) {
  const [complete, setComplete] = useState(false);
  useEffect(() => {
    const timer = window.setTimeout(() => setComplete(true), 2000);
    return () => window.clearTimeout(timer);
  }, []);
  return <>
    <div inert={!complete} style={complete ? undefined : { visibility: 'hidden' }}>{children}</div>
    {!complete && <div className="studio-launch" role="status" aria-label="Lilly Bit Games">
      <img src="/lilly-bit-games.png" alt="Lilly Bit Games" width="1254" height="1254" />
    </div>}
  </>;
}
