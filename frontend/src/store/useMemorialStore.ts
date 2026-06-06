import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface UploadedFile {
  id: string;
  name: string;
  url: string; // object URL or base64
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
  deleteMemorial: (id: string) => void;
  addMemory: (memorialId: string, memory: Omit<Memory, 'id' | 'createdAt' | 'approved'>) => void;
  approveMemory: (memorialId: string, memoryId: string) => void;
  deleteMemory: (memorialId: string, memoryId: string) => void;
}

const sampleMemorials: Memorial[] = [
  {
    id: 'mem-1',
    userId: 'user-test',
    orderId: 'order-1',
    fullName: 'Иванов Иван Иванович',
    birthDate: '1945-05-09',
    deathDate: '2020-10-12',
    fatherName: 'Иванов Иван',
    motherName: 'Иванова Мария',
    epitaph: 'Помним, любим, скорбим...',
    photos: [],
    videos: [],
    memories: [
      {
        id: 'memory-1',
        authorName: 'Петр',
        authorEmail: 'petr@example.com',
        text: 'Прекрасный был человек, всегда помогал в трудную минуту.',
        approved: true,
        createdAt: '2023-01-10T10:00:00Z'
      }
    ],
    packageType: 'standard',
    createdAt: '2022-12-01T10:00:00Z'
  }
];

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
