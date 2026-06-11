import { API_BASE_URL, ApiError, apiRequest } from '@/lib/api';
import { useAuthStore } from '@/store/useAuthStore';

export interface MediaUploadResponse {
  id: string;
  storage_key: string;
  url: string;
  mime_type: string;
  size_bytes: number;
  original_filename: string;
  media_type: string;
}

export function mediaFileUrl(storageKey: string): string {
  if (storageKey.startsWith('http://') || storageKey.startsWith('https://')) {
    return storageKey;
  }
  if (storageKey.startsWith('/')) {
    return storageKey;
  }
  return `${API_BASE_URL}/media/files/${storageKey}`;
}

export function isStorageKey(value: string | undefined): boolean {
  if (!value) return false;
  return value.startsWith('memorials/') || value.startsWith('demos/');
}

export async function uploadMedia(
  memorialId: string,
  mediaType: 'portrait' | 'photo' | 'video',
  file: File,
): Promise<MediaUploadResponse> {
  const token = useAuthStore.getState().accessToken;
  const formData = new FormData();
  formData.append('memorial_id', memorialId);
  formData.append('media_type', mediaType);
  formData.append('file', file);

  const response = await fetch(`${API_BASE_URL}/media/upload`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: formData,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const detail =
      typeof data?.detail === 'string' ? data.detail : 'Ошибка загрузки файла';
    throw new ApiError(response.status, detail);
  }

  return data as MediaUploadResponse;
}

export async function deleteMedia(mediaId: string): Promise<void> {
  const token = useAuthStore.getState().accessToken;
  await apiRequest(`/media/${mediaId}`, { method: 'DELETE', token });
}
