import { useEffect, useState } from 'react';
import { resolveMediaUrl } from '@/lib/media-storage';

interface PersistedImageProps {
  src?: string;
  alt: string;
  className?: string;
  fallback?: React.ReactNode;
}

export function PersistedImage({ src, alt, className, fallback }: PersistedImageProps) {
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
      if (objectUrl?.startsWith('blob:')) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [src]);

  if (!resolved) {
    return (
      <div className={className}>
        {fallback ?? <div className="w-full h-full bg-muted" />}
      </div>
    );
  }

  return <img src={resolved} alt={alt} className={className} />;
}
