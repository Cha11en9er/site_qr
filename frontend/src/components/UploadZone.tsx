import { useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { UploadCloud, X, Film, Image as ImageIcon } from 'lucide-react';
import imageCompression from 'browser-image-compression';
import { Progress } from '@/components/ui/progress';
import { UploadedFile } from '@/store/useMemorialStore';

interface UploadZoneProps {
  accept: string;
  multiple?: boolean;
  maxFiles?: number;
  usedCount: number;
  maxCount: number;
  files: UploadedFile[];
  onAdd: (files: UploadedFile[]) => void;
  onRemove: (id: string) => void;
  label: string;
  unitLabel: 'фото' | 'минут';
}

export function UploadZone({
  accept,
  multiple = true,
  maxFiles = 10,
  usedCount,
  maxCount,
  files,
  onAdd,
  onRemove,
  label,
  unitLabel
}: UploadZoneProps) {
  const isVideo = accept.includes('video');
  const percentUsed = Math.min(100, Math.round((usedCount / maxCount) * 100)) || 0;
  const isNearLimit = percentUsed >= 90;

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    const newFiles: UploadedFile[] = [];
    
    for (const file of acceptedFiles) {
      if (isVideo) {
        // Handle video
        const url = URL.createObjectURL(file);
        const video = document.createElement('video');
        video.preload = 'metadata';
        
        await new Promise((resolve) => {
          video.onloadedmetadata = () => {
            newFiles.push({
              id: `vid-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
              name: file.name,
              url,
              size: file.size,
              type: file.type,
              duration: video.duration
            });
            resolve(null);
          };
          video.src = url;
        });
      } else {
        // Handle image compression
        try {
          const compressedFile = await imageCompression(file, {
            maxSizeMB: 1.5,
            maxWidthOrHeight: 1920,
            useWebWorker: true
          });
          const url = URL.createObjectURL(compressedFile);
          
          newFiles.push({
            id: `img-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            name: file.name,
            url,
            size: compressedFile.size,
            type: compressedFile.type,
            thumbnail: url
          });
        } catch (error) {
          console.error("Error compressing image:", error);
        }
      }
    }
    
    if (newFiles.length > 0) {
      onAdd(newFiles);
    }
  }, [isVideo, onAdd]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: isVideo ? { 'video/*': ['.mp4', '.mov', '.webm'] } : { 'image/*': ['.jpeg', '.jpg', '.png', '.webp'] },
    multiple,
    maxFiles
  });

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center text-sm font-medium">
        <span>{label}</span>
        <span className={isNearLimit ? "text-destructive" : "text-muted-foreground"}>
          Использовано {usedCount.toFixed(isVideo ? 1 : 0)} / {maxCount} {unitLabel}
        </span>
      </div>
      
      <Progress value={percentUsed} className={`h-2 ${isNearLimit ? "[&>div]:bg-destructive" : "[&>div]:bg-primary"}`} />

      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors cursor-pointer flex flex-col items-center justify-center min-h-[160px]
          ${isDragActive ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50 hover:bg-muted/50'}`}
      >
        <input {...getInputProps()} />
        <UploadCloud className="w-10 h-10 text-muted-foreground mb-4" />
        <p className="text-sm font-medium">
          {isDragActive ? 'Перетащите файлы сюда...' : 'Нажмите или перетащите файлы'}
        </p>
        <p className="text-xs text-muted-foreground mt-2">
          {isVideo ? 'MP4, MOV до 100МБ' : 'JPG, PNG, WEBP до 10МБ'}
        </p>
      </div>

      {files.length > 0 && (
        <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-4 mt-4">
          {files.map((file) => (
            <div key={file.id} className="relative group aspect-square rounded-lg overflow-hidden border bg-muted">
              {isVideo ? (
                <div className="w-full h-full flex flex-col items-center justify-center p-2">
                  <Film className="w-8 h-8 text-muted-foreground mb-2" />
                  <span className="text-xs text-center truncate w-full px-1">{file.name}</span>
                  <span className="text-xs font-mono mt-1">{file.duration ? Math.round(file.duration) + 's' : ''}</span>
                </div>
              ) : (
                <img src={file.thumbnail || file.url} alt={file.name} className="w-full h-full object-cover" />
              )}
              
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  onRemove(file.id);
                }}
                className="absolute top-1 right-1 bg-black/60 hover:bg-black/80 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
