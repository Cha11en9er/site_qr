const DB_NAME = 'qr-pamyat-media';
const STORE_NAME = 'blobs';
const DB_VERSION = 1;

export const IDB_PREFIX = 'idb://';

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME);
      }
    };
  });
}

export function isPersistedMediaUrl(url: string | undefined): boolean {
  if (!url) return false;
  return url.startsWith(IDB_PREFIX) || url.startsWith('data:') || url.startsWith('http');
}

export function isIdbUrl(url: string): boolean {
  return url.startsWith(IDB_PREFIX);
}

export function idbKeyFromUrl(url: string): string {
  return url.slice(IDB_PREFIX.length);
}

export async function putMediaBlob(id: string, blob: Blob): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    tx.objectStore(STORE_NAME).put(blob, id);
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => reject(tx.error);
  });
}

export async function getMediaBlob(id: string): Promise<Blob | null> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const request = tx.objectStore(STORE_NAME).get(id);
    request.onsuccess = () => {
      db.close();
      resolve((request.result as Blob | undefined) ?? null);
    };
    request.onerror = () => reject(request.error);
  });
}

export async function deleteMediaBlob(id: string): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    tx.objectStore(STORE_NAME).delete(id);
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => reject(tx.error);
  });
}

export async function blobToIdbUrl(blob: Blob, id?: string): Promise<string> {
  const key = id ?? `media-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  await putMediaBlob(key, blob);
  return `${IDB_PREFIX}${key}`;
}

import { isStorageKey, mediaFileUrl } from '@/lib/media-api';

export async function resolveMediaUrl(url: string | undefined): Promise<string | undefined> {
  if (!url) return undefined;
  if (url.startsWith('data:') || url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/')) {
    return url;
  }
  if (isStorageKey(url)) {
    return mediaFileUrl(url);
  }
  if (isIdbUrl(url)) {
    const blob = await getMediaBlob(idbKeyFromUrl(url));
    if (!blob) return undefined;
    return URL.createObjectURL(blob);
  }
  return undefined;
}

export async function persistFile(file: File | Blob, id?: string): Promise<string> {
  return blobToIdbUrl(file, id);
}

export async function removePersistedUrl(url: string | undefined): Promise<void> {
  if (!url || !isIdbUrl(url)) return;
  await deleteMediaBlob(idbKeyFromUrl(url));
}
