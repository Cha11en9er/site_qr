import { useEffect, useState } from 'react';
import { resolveMediaUrl } from '@/lib/media-storage';

interface PersistedVideoProps {
  src?: string;
  className?: string;
}

export function PersistedVideo({ src, className }: PersistedVideoProps) {
  const [resolved, setResolved] = useState<string | undefined>();

  useEffect(() => {
    let objectUrl: string | undefined;
    let cancelled = false;

    void resolveMediaUrl(src).then((url) => {
      if (cancelled) {
        if (url?.startsWith('blob:')) URL.revokeObjectURL(url);
        return;
      }
      objectUrl = url;
      setResolved(url);
    });

    return () => {
      cancelled = true;
      if (objectUrl?.startsWith('blob:')) URL.revokeObjectURL(objectUrl);
    };
  }, [src]);

  if (!resolved) return <div className={className} />;

  return <video src={resolved} controls className={className} />;
}
