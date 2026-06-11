import { useState, useMemo, useEffect } from 'react';
import { useRoute, Link } from 'wouter';
import { useMemorialStore, Memory, UploadedFile } from '@/store/useMemorialStore';
import { getDemoMemorial, isDemoMemorialId } from '@/data/demo-memorials';
import {
  fetchMemorial,
  fetchPublicMemorial,
  isUuid,
  memorialDtoToStore,
} from '@/lib/memorials-api';
import { useAuthStore } from '@/store/useAuthStore';
import { Memorial } from '@/store/useMemorialStore';
import { PersistedImage } from '@/components/PersistedImage';
import { PersistedVideo } from '@/components/PersistedVideo';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { MemorialMap } from '@/components/MemorialMap';
import { Leaf, MapPin, Heart, Image as ImageIcon, Film } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { toast } from 'sonner';

export default function PublicMemorial() {
  const [, params] = useRoute('/memorial/:id');
  const id = params?.id;
  const { memorials, addMemory } = useMemorialStore();
  const { user, accessToken } = useAuthStore();
  const [apiMemorial, setApiMemorial] = useState<Memorial | null>(null);
  const [loading, setLoading] = useState(Boolean(id && isUuid(id)));

  useEffect(() => {
    if (!id || !isUuid(id)) {
      setLoading(false);
      return;
    }

    const load = async () => {
      try {
        const dto = accessToken
          ? await fetchMemorial(id).catch(() => fetchPublicMemorial(id))
          : await fetchPublicMemorial(id);
        setApiMemorial(memorialDtoToStore(dto, user?.id || 'public'));
      } catch {
        setApiMemorial(isDemoMemorialId(id) ? getDemoMemorial(id) ?? null : null);
      } finally {
        setLoading(false);
      }
    };

    void load();
  }, [id, accessToken, user?.id]);

  const memorial = useMemo(() => {
    if (!id) return undefined;
    if (apiMemorial) return apiMemorial;
    if (getDemoMemorial(id)) return getDemoMemorial(id);
    return memorials.find((m) => m.id === id);
  }, [memorials, id, apiMemorial]);

  const [memoryName, setMemoryName] = useState('');
  const [memoryEmail, setMemoryEmail] = useState('');
  const [memoryText, setMemoryText] = useState('');

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center min-h-[60vh] text-muted-foreground">
        Загрузка страницы памяти…
      </div>
    );
  }

  if (!memorial) {
    return (
      <div className="flex-1 flex flex-col items-center justify-center p-8 text-center min-h-[60vh]">
        <Leaf className="w-16 h-16 text-muted-foreground/30 mb-4" />
        <h1 className="text-3xl font-serif mb-2">Мемориал не найден</h1>
        <p className="text-muted-foreground mb-6">Возможно, ссылка устарела или мемориал был удален.</p>
        <Button asChild>
          <Link href="/">На главную</Link>
        </Button>
      </div>
    );
  }

  const birthDate = memorial.birthDate ? format(new Date(memorial.birthDate), 'dd MMMM yyyy', { locale: ru }) : '';
  const deathDate = memorial.deathDate ? format(new Date(memorial.deathDate), 'dd MMMM yyyy', { locale: ru }) : '';
  const approvedMemories = memorial.memories.filter((m: Memory) => m.approved);

  const handleAddMemory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!memoryName || !memoryEmail || !memoryText) {
      toast.error('Пожалуйста, заполните все поля');
      return;
    }
    
    addMemory(memorial.id, {
      authorName: memoryName,
      authorEmail: memoryEmail,
      text: memoryText,
    });
    
    toast.success('Ваше воспоминание отправлено на модерацию');
    setMemoryName('');
    setMemoryEmail('');
    setMemoryText('');
  };

  return (
    <div className="w-full bg-background pb-24">
      {/* Portrait & Header */}
      <div className="container mx-auto px-4 pt-10 md:pt-16">
        <div className="max-w-4xl mx-auto flex flex-col md:flex-row gap-8 md:gap-12 items-start md:items-center">
          <div className="w-48 sm:w-56 md:w-64 shrink-0 aspect-[3/4] rounded-2xl overflow-hidden bg-muted border shadow-sm flex items-center justify-center mx-auto md:mx-0">
            {memorial.coverPhoto ? (
              <PersistedImage
                src={memorial.coverPhoto}
                alt={memorial.fullName}
                className="w-full h-full object-contain"
              />
            ) : (
              <Leaf className="w-24 h-24 text-primary/20" />
            )}
          </div>

          <div className="flex-1 text-center md:text-left space-y-4 w-full">
            <h1 className="text-3xl md:text-4xl lg:text-5xl font-serif font-medium tracking-tight">
              {memorial.fullName}
            </h1>
            <div className="text-lg md:text-xl font-serif italic text-muted-foreground">
              {birthDate} — {deathDate}
            </div>
            {(memorial.fatherName || memorial.motherName) && (
              <div className="text-muted-foreground space-y-1 text-base md:text-lg pt-2">
                {memorial.fatherName && <p>Отец: {memorial.fatherName}</p>}
                {memorial.motherName && <p>Мать: {memorial.motherName}</p>}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 mt-16">
        {/* Epitaph */}
        <div className="max-w-3xl mx-auto text-center mb-20 space-y-12">
          {memorial.epitaph && (
            <div className="relative py-8">
              <div className="absolute top-0 left-1/2 -translate-x-1/2 w-12 h-[1px] bg-primary/30" />
              <p className="font-serif text-2xl md:text-3xl italic leading-relaxed text-foreground/90">
                «{memorial.epitaph}»
              </p>
              <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-12 h-[1px] bg-primary/30" />
            </div>
          )}
        </div>

        {/* Location Map */}
        {memorial.graveLocation && (
          <div className="max-w-4xl mx-auto mb-20">
            <h2 className="text-2xl font-serif text-center mb-8 flex items-center justify-center gap-2">
              <MapPin className="text-primary w-6 h-6" /> Место захоронения
            </h2>
            <div className="bg-card p-2 rounded-2xl shadow-sm border">
              <p className="text-center mb-4 text-muted-foreground mt-2">{memorial.graveLocation.address}</p>
              <div className="h-64 sm:h-96 rounded-xl overflow-hidden relative z-0">
                <MemorialMap
                  lat={memorial.graveLocation.lat}
                  lng={memorial.graveLocation.lng}
                  label={memorial.fullName}
                  className="h-full w-full"
                />
              </div>
            </div>
          </div>
        )}

        {/* Photos */}
        {memorial.photos.length > 0 && (
          <div className="max-w-6xl mx-auto mb-20">
            <h2 className="text-2xl font-serif text-center mb-8 flex items-center justify-center gap-2">
              <ImageIcon className="text-primary w-6 h-6" /> Фотографии
            </h2>
            <div className="columns-2 md:columns-3 lg:columns-4 gap-4 space-y-4">
              {memorial.photos.map((photo: UploadedFile, i: number) => (
                <div key={i} className="break-inside-avoid rounded-xl overflow-hidden relative group">
                  <PersistedImage src={photo.url} alt="" className="w-full h-auto object-cover transition-transform duration-500 group-hover:scale-105" />
                  <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Videos */}
        {memorial.videos.length > 0 && (
          <div className="max-w-5xl mx-auto mb-20">
            <h2 className="text-2xl font-serif text-center mb-8 flex items-center justify-center gap-2">
              <Film className="text-primary w-6 h-6" /> Видео
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {memorial.videos.map((video: UploadedFile, i: number) => (
                <div key={i} className="rounded-xl overflow-hidden bg-black aspect-video">
                  <PersistedVideo src={video.url} className="w-full h-full object-contain" />
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Memories */}
        <div className="max-w-3xl mx-auto">
          <h2 className="text-2xl font-serif text-center mb-8 flex items-center justify-center gap-2">
            <Heart className="text-primary w-6 h-6" /> Книга воспоминаний
          </h2>
          
          <div className="space-y-6 mb-12">
            {approvedMemories.length === 0 ? (
              <p className="text-center text-muted-foreground py-8">Пока нет воспоминаний. Станьте первым.</p>
            ) : (
              approvedMemories.map((memory: Memory) => (
                <Card key={memory.id} className="bg-card border-none shadow-sm">
                  <CardContent className="pt-6">
                    <p className="text-foreground/90 leading-relaxed mb-4 whitespace-pre-line">{memory.text}</p>
                    <div className="flex justify-between items-center text-sm text-muted-foreground">
                      <span className="font-medium">{memory.authorName}</span>
                      <span>{format(new Date(memory.createdAt), 'dd.MM.yyyy')}</span>
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </div>

          <Card className="bg-muted/30 border-dashed">
            <CardContent className="pt-6">
              <h3 className="font-serif text-xl mb-4 text-center">Оставить воспоминание</h3>
              <form onSubmit={handleAddMemory} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Ваше имя</label>
                    <Input value={memoryName} onChange={(e) => setMemoryName(e.target.value)} placeholder="Как вас представить" />
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Ваш Email (не публикуется)</label>
                    <Input type="email" value={memoryEmail} onChange={(e) => setMemoryEmail(e.target.value)} placeholder="email@example.com" />
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Текст воспоминания</label>
                  <Textarea value={memoryText} onChange={(e) => setMemoryText(e.target.value)} placeholder="Поделитесь светлой историей..." className="h-32 resize-none" />
                </div>
                <Button type="submit" className="w-full">Отправить</Button>
                <p className="text-xs text-center text-muted-foreground mt-2">
                  Ваше сообщение появится на странице после проверки модератором (семьей усопшего).
                </p>
              </form>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
