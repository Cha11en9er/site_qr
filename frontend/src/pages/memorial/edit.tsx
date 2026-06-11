import { useState, useEffect } from 'react';
import { useRoute, Link, useLocation } from 'wouter';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { useMemorialStore, UploadedFile } from '@/store/useMemorialStore';
import { useAuthStore } from '@/store/useAuthStore';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { UploadZone } from '@/components/UploadZone';
import { toast } from 'sonner';
import { ChevronLeft, Save } from 'lucide-react';
import imageCompression from 'browser-image-compression';
import { persistFile, removePersistedUrl } from '@/lib/media-storage';
import { PersistedImage } from '@/components/PersistedImage';
import { uploadMedia } from '@/lib/media-api';
import {
  fetchMemorial,
  isUuid,
  memorialDtoToStore,
  updateMemorialApi,
} from '@/lib/memorials-api';
import { ApiError } from '@/lib/api';

const schema = z.object({
  fullName: z.string().min(2, 'Введите полное имя'),
  birthDate: z.string().min(1, 'Введите дату рождения'),
  deathDate: z.string().min(1, 'Введите дату смерти'),
  fatherName: z.string().optional(),
  motherName: z.string().optional(),
  epitaph: z.string().optional(),
  address: z.string().optional(),
  lat: z.number().optional(),
  lng: z.number().optional()
});

export default function EditMemorial() {
  const [, params] = useRoute('/memorial/:id/edit');
  const [, setLocation] = useLocation();
  const id = params?.id;
  
  const { user } = useAuthStore();
  const { memorials, updateMemorial, upsertMemorial } = useMemorialStore();
  
  const memorial = memorials.find(m => m.id === id);
  
  const form = useForm<z.infer<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: {
      fullName: memorial?.fullName || '',
      birthDate: memorial?.birthDate || '',
      deathDate: memorial?.deathDate || '',
      fatherName: memorial?.fatherName || '',
      motherName: memorial?.motherName || '',
      epitaph: memorial?.epitaph || '',
      address: memorial?.graveLocation?.address || '',
      lat: memorial?.graveLocation?.lat || 55.7558,
      lng: memorial?.graveLocation?.lng || 37.6173
    }
  });

  const [coverPhoto, setCoverPhoto] = useState<string | undefined>(memorial?.coverPhoto);
  const [photos, setPhotos] = useState<UploadedFile[]>(memorial?.photos || []);
  const [videos, setVideos] = useState<UploadedFile[]>(memorial?.videos || []);
  const [loading, setLoading] = useState(Boolean(id && isUuid(id)));

  useEffect(() => {
    if (!id || !isUuid(id) || !user) return;

    void fetchMemorial(id)
      .then((dto) => {
        const mapped = memorialDtoToStore(dto, user.id);
        upsertMemorial(mapped);
        setCoverPhoto(mapped.coverPhoto);
        setPhotos(mapped.photos);
        setVideos(mapped.videos);
        form.reset({
          fullName: mapped.fullName,
          birthDate: mapped.birthDate,
          deathDate: mapped.deathDate,
          fatherName: mapped.fatherName || '',
          motherName: mapped.motherName || '',
          epitaph: mapped.epitaph || '',
          address: mapped.graveLocation?.address || '',
          lat: mapped.graveLocation?.lat || 55.7558,
          lng: mapped.graveLocation?.lng || 37.6173,
        });
      })
      .catch(() => toast.error('Не удалось загрузить мемориал с сервера'))
      .finally(() => setLoading(false));
  }, [id, user]);

  useEffect(() => {
    if (!memorial || (user && memorial.userId !== user.id && !user.isAdmin)) {
      toast.error('Нет доступа');
      setLocation('/cabinet');
    }
  }, [memorial, user, setLocation]);

  if (!memorial) return null;
  if (loading) return <div className="container py-16 text-center text-muted-foreground">Загрузка…</div>;

  const isServerMemorial = isUuid(memorial.id);

  const getPackageLimits = (type: string) => {
    switch (type) {
      case 'standard': return { photos: 40, videos: 0 };
      case 'premium': return { photos: 80, videos: 20 };
      case 'max': return { photos: 200, videos: 60 };
      default: return { photos: 40, videos: 0 };
    }
  };

  const limits = getPackageLimits(memorial.packageType);
  const usedVideoMinutes = videos.reduce((acc, v) => acc + (v.duration || 0) / 60, 0);

  const onSubmit = async (data: z.infer<typeof schema>) => {
    const graveLocation = data.address
      ? { address: data.address, lat: data.lat || 0, lng: data.lng || 0 }
      : undefined;

    if (isServerMemorial) {
      try {
        await updateMemorialApi(memorial.id, {
          full_name: data.fullName,
          birth_date: data.birthDate,
          death_date: data.deathDate,
          father_name: data.fatherName || null,
          mother_name: data.motherName || null,
          epitaph: data.epitaph || null,
          grave_address: data.address || null,
          grave_lat: data.lat ?? null,
          grave_lng: data.lng ?? null,
          is_published: true,
        });
        updateMemorial(memorial.id, {
          fullName: data.fullName,
          birthDate: data.birthDate,
          deathDate: data.deathDate,
          fatherName: data.fatherName,
          motherName: data.motherName,
          epitaph: data.epitaph,
          graveLocation,
          coverPhoto,
          photos,
          videos,
          isPublished: true,
        });
        toast.success('Изменения сохранены');
      } catch (error) {
        toast.error(error instanceof ApiError ? error.detail : 'Ошибка сохранения');
      }
      return;
    }

    updateMemorial(memorial.id, {
      fullName: data.fullName,
      birthDate: data.birthDate,
      deathDate: data.deathDate,
      fatherName: data.fatherName,
      motherName: data.motherName,
      epitaph: data.epitaph,
      graveLocation,
      coverPhoto,
      photos,
      videos,
    });
    toast.success('Изменения сохранены');
  };

  const handleCoverUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      const compressed = await imageCompression(file, { maxSizeMB: 1, maxWidthOrHeight: 1920 });

      if (isServerMemorial) {
        const result = await uploadMedia(memorial.id, 'portrait', compressed);
        setCoverPhoto(result.url);
        toast.success('Фотография загружена');
        return;
      }

      if (coverPhoto) await removePersistedUrl(coverPhoto);
      const url = await persistFile(compressed, `cover-${memorial.id}`);
      setCoverPhoto(url);
    } catch (err) {
      toast.error(err instanceof ApiError ? err.detail : 'Ошибка загрузки фотографии');
    }
  };

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl pb-24">
      <div className="flex items-center gap-4 mb-8">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/cabinet">
            <ChevronLeft className="w-5 h-5" />
          </Link>
        </Button>
        <div>
          <h1 className="text-3xl font-serif font-medium">Редактирование</h1>
          <p className="text-muted-foreground">Мемориал: {memorial.fullName}</p>
        </div>
      </div>

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
          
          {/* Главная фотография */}
          <Card>
            <CardHeader>
              <CardTitle>Главная фотография</CardTitle>
              <CardDescription>
                Портрет близкого человека — отображается в верхней части мемориальной страницы при сканировании QR-кода
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="w-56 sm:w-64 mx-auto aspect-[3/4] rounded-xl border overflow-hidden bg-muted flex items-center justify-center">
                  {coverPhoto ? (
                    <PersistedImage src={coverPhoto} alt="Портрет" className="w-full h-full object-contain" />
                  ) : (
                    <span className="text-muted-foreground text-sm text-center px-4">
                      Фотография не загружена
                    </span>
                  )}
                </div>
                <div>
                  <Input type="file" accept="image/*" onChange={handleCoverUpload} />
                  <p className="text-xs text-muted-foreground mt-2">
                    Рекомендуется портретная фотография — будет показана целиком, без обрезки
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Основные данные */}
          <Card>
            <CardHeader>
              <CardTitle>Основные данные</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <FormField
                control={form.control}
                name="fullName"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>ФИО усопшего</FormLabel>
                    <FormControl><Input {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="birthDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Дата рождения</FormLabel>
                      <FormControl><Input type="date" {...field} /></FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="deathDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Дата смерти</FormLabel>
                      <FormControl><Input type="date" {...field} /></FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="fatherName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Отец</FormLabel>
                      <FormControl><Input {...field} /></FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="motherName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Мать</FormLabel>
                      <FormControl><Input {...field} /></FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              <FormField
                control={form.control}
                name="epitaph"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Эпитафия</FormLabel>
                    <FormControl><Textarea className="h-24 resize-none" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </CardContent>
          </Card>

          {/* Место захоронения */}
          <Card>
            <CardHeader>
              <CardTitle>Место захоронения</CardTitle>
              <CardDescription>Укажите координаты и адрес кладбища</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <FormField
                control={form.control}
                name="address"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Адрес текстом</FormLabel>
                    <FormControl><Input placeholder="Например: Троекуровское кладбище, участок 4" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="lat"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Широта (Lat)</FormLabel>
                      <FormControl>
                        <Input type="number" step="any" onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)} value={field.value || ''} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="lng"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Долгота (Lng)</FormLabel>
                      <FormControl>
                        <Input type="number" step="any" onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)} value={field.value || ''} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </CardContent>
          </Card>

          {/* Фотографии */}
          <Card>
            <CardHeader>
              <CardTitle>Фотогалерея</CardTitle>
              <CardDescription>Пакет {memorial.packageType}</CardDescription>
            </CardHeader>
            <CardContent>
              <UploadZone
                accept="image/*"
                multiple={true}
                memorialId={memorial.id}
                usedCount={photos.length}
                maxCount={limits.photos}
                files={photos}
                label="Загруженные фотографии"
                unitLabel="фото"
                onAdd={(newFiles) => {
                  if (photos.length + newFiles.length > limits.photos) {
                    toast.error(`Превышен лимит пакета (${limits.photos} фото)`);
                    return;
                  }
                  setPhotos([...photos, ...newFiles]);
                }}
                onRemove={(id) => setPhotos(photos.filter(p => p.id !== id))}
              />
            </CardContent>
          </Card>

          {/* Видео */}
          <Card>
            <CardHeader>
              <CardTitle>Видеоархив</CardTitle>
              <CardDescription>Пакет {memorial.packageType}</CardDescription>
            </CardHeader>
            <CardContent>
              {limits.videos > 0 ? (
                <UploadZone
                  accept="video/*"
                  multiple={true}
                  memorialId={memorial.id}
                  usedCount={usedVideoMinutes}
                  maxCount={limits.videos}
                  files={videos}
                  label="Загруженные видео"
                  unitLabel="минут"
                  onAdd={(newFiles) => {
                    const newDuration = newFiles.reduce((acc, v) => acc + (v.duration || 0) / 60, 0);
                    if (usedVideoMinutes + newDuration > limits.videos) {
                      toast.error(`Превышен лимит пакета (${limits.videos} мин)`);
                      return;
                    }
                    setVideos([...videos, ...newFiles]);
                  }}
                  onRemove={(id) => setVideos(videos.filter(v => v.id !== id))}
                />
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  Загрузка видео недоступна на тарифе Standard.
                </div>
              )}
            </CardContent>
          </Card>

          <div className="sticky bottom-0 left-0 right-0 bg-background border-t p-4 flex justify-end gap-4 z-20">
            <Button type="button" variant="outline" asChild>
              <Link href={`/memorial/${memorial.id}`}>Предпросмотр</Link>
            </Button>
            <Button type="submit">
              <Save className="w-4 h-4 mr-2" />
              Сохранить изменения
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
