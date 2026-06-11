import { useEffect } from 'react';
import { Link } from 'wouter';
import { useMemorialStore } from '@/store/useMemorialStore';
import { useAuthStore } from '@/store/useAuthStore';
import { fetchMyMemorials, memorialDtoToStore } from '@/lib/memorials-api';
import { Card, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Edit, ExternalLink, Calendar, Image as ImageIcon } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { PersistedImage } from '@/components/PersistedImage';

export default function CabinetMemorials() {
  const { user } = useAuthStore();
  const { memorials, upsertMemorial } = useMemorialStore();

  useEffect(() => {
    if (!user) return;
    void fetchMyMemorials()
      .then((list) => {
        list.forEach((dto) => {
          upsertMemorial(memorialDtoToStore(dto, user.id));
        });
      })
      .catch(() => {});
  }, [user, upsertMemorial]);

  const userMemorials = memorials.filter(m => m.userId === user?.id);

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-serif font-medium mb-2">Мои мемориалы</h1>
          <p className="text-muted-foreground">Страницы памяти, которыми вы управляете</p>
        </div>
        <Button asChild>
          <Link href="/cabinet/create">Создать</Link>
        </Button>
      </div>

      {userMemorials.length === 0 ? (
        <Card className="border-dashed bg-muted/30">
          <CardContent className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-16 h-16 bg-background rounded-full flex items-center justify-center mb-4 shadow-sm">
              <ImageIcon className="w-8 h-8 text-muted-foreground" />
            </div>
            <h3 className="text-xl font-medium mb-2">У вас пока нет созданных мемориалов</h3>
            <p className="text-muted-foreground max-w-md mb-6">
              Создайте первую страницу памяти, чтобы сохранить историю близкого человека.
            </p>
            <Button asChild>
              <Link href="/cabinet/create">Создать мемориал</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {userMemorials.map((memorial) => {
            const birthYear = memorial.birthDate ? format(new Date(memorial.birthDate), 'yyyy') : '';
            const deathYear = memorial.deathDate ? format(new Date(memorial.deathDate), 'yyyy') : '';
            
            return (
              <Card key={memorial.id} className="overflow-hidden flex flex-col transition-shadow hover:shadow-md">
                <div className="h-48 bg-muted relative flex items-center justify-center">
                  {memorial.coverPhoto ? (
                    <PersistedImage src={memorial.coverPhoto} alt={memorial.fullName} className="w-full h-full object-contain" />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center bg-primary/5">
                      <ImageIcon className="w-12 h-12 text-primary/20" />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                  <div className="absolute bottom-4 left-4 right-4 text-white">
                    <h3 className="font-serif text-xl font-medium truncate">{memorial.fullName}</h3>
                    <div className="flex items-center text-sm opacity-90 mt-1">
                      <Calendar className="w-3.5 h-3.5 mr-1.5" />
                      <span>{birthYear} — {deathYear}</span>
                    </div>
                  </div>
                </div>
                
                <CardContent className="py-4 flex-1">
                  <div className="flex gap-4 text-sm text-muted-foreground">
                    <div>
                      <span className="block text-foreground font-medium">{memorial.photos?.length || 0}</span>
                      фото
                    </div>
                    <div>
                      <span className="block text-foreground font-medium">{memorial.memories?.length || 0}</span>
                      воспоминаний
                    </div>
                  </div>
                </CardContent>
                
                <CardFooter className="gap-3 pt-0 pb-4">
                  <Button variant="outline" className="flex-1 bg-background" asChild>
                    <Link href={`/memorial/${memorial.id}/edit`}>
                      <Edit className="w-4 h-4 mr-2" />
                      Редактировать
                    </Link>
                  </Button>
                  <Button variant="secondary" className="flex-1" asChild>
                    <Link href={`/memorial/${memorial.id}`}>
                      <ExternalLink className="w-4 h-4 mr-2" />
                      Открыть
                    </Link>
                  </Button>
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
