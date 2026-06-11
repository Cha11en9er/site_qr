import { useEffect } from 'react';
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
  return (
    <div className={className ?? 'h-full w-full memorial-map'}>
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
    </div>
  );
}
