import { useEffect, useRef, useState } from 'react';
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

function HideAttribution() {
  const map = useMap();

  useEffect(() => {
    const control = map.attributionControl;
    if (control) {
      map.removeControl(control);
    }
  }, [map]);

  return null;
}

interface MemorialMapProps {
  lat: number;
  lng: number;
  label: string;
  className?: string;
}

export function MemorialMap({ lat, lng, label, className }: MemorialMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [shouldRender, setShouldRender] = useState(false);

  useEffect(() => {
    const node = containerRef.current;
    if (!node) return;

    if (typeof IntersectionObserver === 'undefined') {
      setShouldRender(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShouldRender(true);
          observer.disconnect();
        }
      },
      { rootMargin: '120px' },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={containerRef} className={className ?? 'h-full w-full memorial-map'}>
      {shouldRender ? (
        <MapContainer
          center={[lat, lng]}
          zoom={15}
          attributionControl={false}
          style={{ height: '100%', width: '100%' }}
        >
          <HideAttribution />
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" attribution="" />
          <Marker position={[lat, lng]}>
            <Popup>{label}</Popup>
          </Marker>
        </MapContainer>
      ) : (
        <div className="h-full w-full bg-muted/40" aria-hidden />
      )}
    </div>
  );
}
