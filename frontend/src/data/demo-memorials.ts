import { mediaFileUrl } from '@/lib/media-api';
import { Memorial } from '@/store/useMemorialStore';

/** Фиксированные UUID — совпадают с seed в db/scripts/08_seed.sql */
export const DEMO_USER_ID = 'f0000000-0000-4000-8000-000000000001';

export const DEMO_MEMORIAL_IDS = [
  'f0000001-0000-4000-8000-000000000001',
  'f0000002-0000-4000-8000-000000000002',
  'f0000003-0000-4000-8000-000000000003',
] as const;

type DemoId = (typeof DEMO_MEMORIAL_IDS)[number];

function portrait(slug: string): string {
  return mediaFileUrl(`examples/${slug}/portrait.jpg`);
}

const DEMO_DATA: Memorial[] = [
  {
    id: DEMO_MEMORIAL_IDS[0],
    userId: DEMO_USER_ID,
    orderId: '',
    fullName: 'Пушкин Александр Сергеевич',
    birthDate: '1799-06-06',
    deathDate: '1837-01-29',
    fatherName: 'Сергей Львович Пушкин',
    motherName: 'Надежда Осиповна Пушкина',
    epitaph: 'И память сердца говорит Мне больше, чем дня печать…',
    coverPhoto: portrait('pushkin'),
    coverStorageKey: 'examples/pushkin/portrait.jpg',
    isPublished: true,
    graveLocation: {
      address: 'Святогорский монастырь, Пушкинские Горы, Псковская область',
      lat: 57.0221,
      lng: 28.9208,
    },
    photos: [],
    videos: [],
    memories: [
      {
        id: 'demo-memory-pushkin-1',
        authorName: 'Вяземский',
        authorEmail: 'demo@qr-pamyat.ru',
        text: 'Пушкин дал русской словесности всё, что мог дать гениальный поэт своего времени.',
        approved: true,
        createdAt: '2020-01-01T12:00:00Z',
      },
    ],
    packageType: 'premium',
    createdAt: '2020-01-01T00:00:00Z',
  },
  {
    id: DEMO_MEMORIAL_IDS[1],
    userId: DEMO_USER_ID,
    orderId: '',
    fullName: 'Куприн Александр Иванович',
    birthDate: '1870-09-07',
    deathDate: '1938-08-25',
    fatherName: 'Иван Иванович Куприн',
    motherName: 'Любовь Алексеевна Куприна',
    epitaph: 'Писатель должен жить в своих книгах.',
    coverPhoto: portrait('kuprin'),
    coverStorageKey: 'examples/kuprin/portrait.jpg',
    isPublished: true,
    graveLocation: {
      address: 'Волково православное кладбище, Санкт-Петербург',
      lat: 59.9042,
      lng: 30.3894,
    },
    photos: [],
    videos: [],
    memories: [
      {
        id: 'demo-memory-kuprin-1',
        authorName: 'Горький',
        authorEmail: 'demo@qr-pamyat.ru',
        text: 'Куприн — один из самых ярких мастеров русской прозы начала XX века.',
        approved: true,
        createdAt: '2020-01-01T12:00:00Z',
      },
    ],
    packageType: 'premium',
    createdAt: '2020-01-01T00:00:00Z',
  },
  {
    id: DEMO_MEMORIAL_IDS[2],
    userId: DEMO_USER_ID,
    orderId: '',
    fullName: 'Менделеев Дмитрий Иванович',
    birthDate: '1834-02-08',
    deathDate: '1907-02-02',
    fatherName: 'Иван Павлович Менделеев',
    motherName: 'Мария Дмитриевна Менделеева',
    epitaph: 'Наука и жизнь — неразделимы.',
    coverPhoto: portrait('mendeleev'),
    coverStorageKey: 'examples/mendeleev/portrait.jpg',
    isPublished: true,
    graveLocation: {
      address: 'Волково кладбище, Санкт-Петербург',
      lat: 59.906,
      lng: 30.39,
    },
    photos: [],
    videos: [],
    memories: [
      {
        id: 'demo-memory-mendeleev-1',
        authorName: 'Коллега',
        authorEmail: 'demo@qr-pamyat.ru',
        text: 'Открытие периодического закона стало фундаментом современной химии.',
        approved: true,
        createdAt: '2020-01-01T12:00:00Z',
      },
    ],
    packageType: 'premium',
    createdAt: '2020-01-01T00:00:00Z',
  },
];

/** Карточки на лендинге и полные страницы (fallback без API). */
export const DEMO_MEMORIALS: Memorial[] = DEMO_DATA;

export function isDemoMemorialId(id: string): id is DemoId {
  return (DEMO_MEMORIAL_IDS as readonly string[]).includes(id);
}

export function getDemoMemorial(id: string): Memorial | undefined {
  return DEMO_MEMORIALS.find((m) => m.id === id);
}
