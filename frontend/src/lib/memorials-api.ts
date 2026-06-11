import { apiRequest } from '@/lib/api';
import { useAuthStore } from '@/store/useAuthStore';
import { UploadedFile } from '@/store/useMemorialStore';

export interface MemorialMediaItem {
  id: string;
  storage_key: string;
  url: string;
  mime_type: string;
  size_bytes: number;
  original_filename: string;
  duration_seconds?: number | null;
  sort_order: number;
}

export interface MemorialDto {
  id: string;
  public_slug: string;
  full_name: string;
  birth_date: string | null;
  death_date: string | null;
  father_name: string | null;
  mother_name: string | null;
  epitaph: string | null;
  grave_address: string | null;
  grave_lat: string | null;
  grave_lng: string | null;
  package_type: string;
  max_photos: number;
  max_video_seconds: number;
  is_published: boolean;
  portrait: MemorialMediaItem | null;
  photos: MemorialMediaItem[];
  videos: MemorialMediaItem[];
}

export function isUuid(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id);
}

function mediaToUploadedFile(item: MemorialMediaItem): UploadedFile {
  return {
    id: item.id,
    name: item.original_filename,
    url: item.url,
    storageKey: item.storage_key,
    size: item.size_bytes,
    type: item.mime_type,
    duration: item.duration_seconds ?? undefined,
    thumbnail: item.url,
  };
}

export function memorialDtoToStore(dto: MemorialDto, userId: string) {
  return {
    id: dto.id,
    userId,
    orderId: '',
    fullName: dto.full_name,
    birthDate: dto.birth_date ?? '',
    deathDate: dto.death_date ?? '',
    fatherName: dto.father_name ?? undefined,
    motherName: dto.mother_name ?? undefined,
    epitaph: dto.epitaph ?? undefined,
    coverPhoto: dto.portrait?.url,
    coverStorageKey: dto.portrait?.storage_key,
    graveLocation:
      dto.grave_address && dto.grave_lat && dto.grave_lng
        ? {
            address: dto.grave_address,
            lat: Number(dto.grave_lat),
            lng: Number(dto.grave_lng),
          }
        : undefined,
    photos: dto.photos.map(mediaToUploadedFile),
    videos: dto.videos.map(mediaToUploadedFile),
    memories: [],
    packageType: dto.package_type as 'standard' | 'premium' | 'max',
    createdAt: new Date().toISOString(),
    isPublished: dto.is_published,
  };
}

function authToken() {
  return useAuthStore.getState().accessToken;
}

export async function createMemorialApi(payload: {
  full_name: string;
  birth_date: string;
  death_date: string;
  father_name?: string;
  mother_name?: string;
  epitaph?: string;
  package_type: 'standard' | 'premium' | 'max';
}): Promise<MemorialDto> {
  return apiRequest<MemorialDto>('/memorials', {
    method: 'POST',
    body: JSON.stringify(payload),
    token: authToken(),
  });
}

export async function updateMemorialApi(
  id: string,
  payload: Record<string, unknown>,
): Promise<MemorialDto> {
  return apiRequest<MemorialDto>(`/memorials/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
    token: authToken(),
  });
}

export async function fetchMyMemorials(): Promise<MemorialDto[]> {
  return apiRequest<MemorialDto[]>('/memorials/me', { token: authToken() });
}

export async function fetchMemorial(id: string): Promise<MemorialDto> {
  return apiRequest<MemorialDto>(`/memorials/${id}`, { token: authToken() });
}

export async function fetchPublicMemorial(id: string): Promise<MemorialDto> {
  return apiRequest<MemorialDto>(`/memorials/${id}/public`);
}
