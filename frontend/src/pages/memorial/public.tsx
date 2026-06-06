import { useState, useMemo } from 'react';
import { useRoute, Link } from 'wouter';
import { useMemorialStore, Memory } from '@/store/useMemorialStore';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
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
  
  const memorial = useMemo(() => memorials.find(m => m.id === id), [memorials, id]);

  const [memoryName, setMemoryName] = useState('');
  const [memoryEmail, setMemoryEmail] = useState('');
  const [memoryText, setMemoryText] = useState('');

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
  const approvedMemories = memorial.memories.filter(m => m.approved);

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
      {/* Cover Photo & Header */}
      <div className="relative h-[40vh] md:h-[60vh] w-full bg-muted">
        {memorial.coverPhoto ? (
          <img src={memorial.coverPhoto} alt={memorial.fullName} className="w-full h-full object-cover" />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center bg-primary/5">
            <Leaf className="w-24 h-24 text-primary/20" />
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-background via-background/60 to-transparent" />
        
        <div className="absolute bottom-0 left-0 right-0 p-6 md:p-12 text-center text-foreground z-10 translate-y-12">
          <h1 className="text-4xl md:text-6xl lg:text-7xl font-serif font-medium mb-4 tracking-tight drop-shadow-sm">
            {memorial.fullName}
          </h1>
          <div className="text-xl md:text-2xl opacity-90 font-serif italic text-muted-foreground">
            {birthDate} — {deathDate}
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 mt-24">
        {/* Parents & Epitaph */}
        <div className="max-w-3xl mx-auto text-center mb-20 space-y-12">
          {(memorial.fatherName || memorial.motherName) && (
            <div className="text-muted-foreground flex flex-col sm:flex-row items-center justify-center gap-2 sm:gap-8">
              {memorial.fatherName && <span>Сын/Дочь: {memorial.fatherName}</span>}
              {memorial.motherName && <span>Сын/Дочь: {memorial.motherName}</span>}
            </div>
          )}

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
                <MapContainer 
                  center={[memorial.graveLocation.lat, memorial.graveLocation.lng]} 
                  zoom={15} 
                  style={{ height: '100%', width: '100%' }}
                >
                  <TileLayer
                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    attribution='&copy; OpenStreetMap contributors'
                  />
                  <Marker position={[memorial.graveLocation.lat, memorial.graveLocation.lng]}>
                    <Popup>{memorial.fullName}</Popup>
                  </Marker>
                </MapContainer>
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
              {memorial.photos.map((photo, i) => (
                <div key={i} className="break-inside-avoid rounded-xl overflow-hidden relative group">
                  <img src={photo.url} alt="" className="w-full h-auto object-cover transition-transform duration-500 group-hover:scale-105" />
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
              {memorial.videos.map((video, i) => (
                <div key={i} className="rounded-xl overflow-hidden bg-black aspect-video">
                  <video src={video.url} controls className="w-full h-full object-contain" />
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
              approvedMemories.map((memory) => (
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
