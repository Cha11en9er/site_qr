import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface UploadedFile {
  id: string;
  name: string;
  url: string; // URL для отображения (/api/v1/media/files/...)
  storageKey?: string; // относительный путь: YYYY-MM/{order_id|memorial_id}/photos/… или examples/…
  size: number;
  type: string;
  duration?: number; // for video, in seconds
  thumbnail?: string;
}

export interface Memory {
  id: string;
  authorName: string;
  authorEmail: string;
  text: string;
  approved: boolean;
  createdAt: string;
}

export interface Memorial {
  id: string;
  userId: string;
  orderId: string;
  fullName: string;
  birthDate: string;
  deathDate: string;
  fatherName?: string;
  motherName?: string;
  epitaph?: string;
  coverPhoto?: string;
  coverStorageKey?: string;
  isPublished?: boolean;
  mainPhoto?: string;
  gravePhoto?: string;
  graveLocation?: { lat: number; lng: number; address: string };
  photos: UploadedFile[];
  videos: UploadedFile[];
  memories: Memory[];
  packageType: 'standard' | 'premium' | 'max';
  createdAt: string;
}

interface MemorialState {
  memorials: Memorial[];
  createMemorial: (memorial: Omit<Memorial, 'id' | 'createdAt' | 'photos' | 'videos' | 'memories'>) => Memorial;
  updateMemorial: (id: string, updates: Partial<Memorial>) => void;
  upsertMemorial: (memorial: Memorial) => void;
  deleteMemorial: (id: string) => void;
  addMemory: (memorialId: string, memory: Omit<Memory, 'id' | 'createdAt' | 'approved'>) => void;
  approveMemory: (memorialId: string, memoryId: string) => void;
  deleteMemory: (memorialId: string, memoryId: string) => void;
}

const sampleMemorials: Memorial[] = [];

export const useMemorialStore = create<MemorialState>()(
  persist(
    (set) => ({
      memorials: sampleMemorials,
      createMemorial: (memorialData) => {
        const newMemorial: Memorial = {
          ...memorialData,
          id: `mem-${Date.now()}`,
          photos: [],
          videos: [],
          memories: [],
          createdAt: new Date().toISOString(),
        };
        set(state => ({ memorials: [newMemorial, ...state.memorials] }));
        return newMemorial;
      },
      updateMemorial: (id, updates) => {
        set(state => ({
          memorials: state.memorials.map(m => m.id === id ? { ...m, ...updates } : m)
        }));
      },
      upsertMemorial: (memorial) => {
        set(state => {
          const exists = state.memorials.some(m => m.id === memorial.id);
          if (exists) {
            return {
              memorials: state.memorials.map(m =>
                m.id === memorial.id ? { ...m, ...memorial } : m
              ),
            };
          }
          return { memorials: [memorial, ...state.memorials] };
        });
      },
      deleteMemorial: (id) => {
        set(state => ({
          memorials: state.memorials.filter(m => m.id !== id)
        }));
      },
      addMemory: (memorialId, memoryData) => {
        const newMemory: Memory = {
          ...memoryData,
          id: `memory-${Date.now()}`,
          approved: false,
          createdAt: new Date().toISOString()
        };
        set(state => ({
          memorials: state.memorials.map(m => 
            m.id === memorialId 
              ? { ...m, memories: [...m.memories, newMemory] }
              : m
          )
        }));
      },
      approveMemory: (memorialId, memoryId) => {
        set(state => ({
          memorials: state.memorials.map(m => 
            m.id === memorialId 
              ? {
                  ...m, 
                  memories: m.memories.map(mem => mem.id === memoryId ? { ...mem, approved: true } : mem)
                }
              : m
          )
        }));
      },
      deleteMemory: (memorialId, memoryId) => {
        set(state => ({
          memorials: state.memorials.map(m => 
            m.id === memorialId 
              ? {
                  ...m, 
                  memories: m.memories.filter(mem => mem.id !== memoryId)
                }
              : m
          )
        }));
      }
    }),
    {
      name: 'memorial-storage',
    }
  )
);
