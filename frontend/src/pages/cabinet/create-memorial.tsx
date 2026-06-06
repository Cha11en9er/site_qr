import { useLocation } from 'wouter';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import { useMemorialStore } from '@/store/useMemorialStore';
import { useOrderStore } from '@/store/useOrderStore';
import { useAuthStore } from '@/store/useAuthStore';
import { toast } from 'sonner';

const schema = z.object({
  orderId: z.string().min(1, 'Выберите заказ (оплаченный пакет)'),
  fullName: z.string().min(2, 'Введите полное имя'),
  birthDate: z.string().min(1, 'Введите дату рождения'),
  deathDate: z.string().min(1, 'Введите дату смерти'),
  fatherName: z.string().optional(),
  motherName: z.string().optional(),
  epitaph: z.string().optional(),
});

export default function CabinetCreateMemorial() {
  const [, setLocation] = useLocation();
  const { user } = useAuthStore();
  const { createMemorial } = useMemorialStore();
  const { orders } = useOrderStore();
  
  const userOrders = orders.filter(o => o.userId === user?.id);

  const form = useForm<z.infer<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: {
      orderId: '',
      fullName: '',
      birthDate: '',
      deathDate: '',
      fatherName: '',
      motherName: '',
      epitaph: '',
    }
  });

  const onSubmit = (data: z.infer<typeof schema>) => {
    const order = userOrders.find(o => o.id === data.orderId);
    if (!order) return;

    const newMemorial = createMemorial({
      userId: user!.id,
      orderId: data.orderId,
      fullName: data.fullName,
      birthDate: data.birthDate,
      deathDate: data.deathDate,
      fatherName: data.fatherName,
      motherName: data.motherName,
      epitaph: data.epitaph,
      packageType: order.packageType,
    });

    toast.success('Мемориал создан! Теперь можно добавить фото.');
    setLocation(`/memorial/${newMemorial.id}/edit`);
  };

  return (
    <div className="max-w-2xl">
      <h1 className="text-3xl font-serif font-medium mb-6">Создание мемориала</h1>
      
      <Card>
        <CardHeader>
          <CardTitle>Основные данные</CardTitle>
          <CardDescription>
            Заполните начальную информацию. Фотографии и видео можно будет добавить на следующем шаге.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              
              <FormField
                control={form.control}
                name="orderId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Оплаченный пакет</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Выберите заказ для привязки" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {userOrders.length === 0 ? (
                          <SelectItem value="empty" disabled>Нет доступных заказов</SelectItem>
                        ) : (
                          userOrders.map(o => (
                            <SelectItem key={o.id} value={o.id}>
                              Пакет {o.packageType} ({o.deceasedName || 'Без имени'}) — {new Date(o.createdAt).toLocaleDateString('ru-RU')}
                            </SelectItem>
                          ))
                        )}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="fullName"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>ФИО усопшего</FormLabel>
                    <FormControl>
                      <Input placeholder="Иванов Иван Иванович" {...field} />
                    </FormControl>
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
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
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
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
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
                      <FormLabel>Имя отца (необязательно)</FormLabel>
                      <FormControl>
                        <Input placeholder="Отец" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="motherName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Имя матери (необязательно)</FormLabel>
                      <FormControl>
                        <Input placeholder="Мать" {...field} />
                      </FormControl>
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
                    <FormLabel>Эпитафия (памятные слова)</FormLabel>
                    <FormControl>
                      <Textarea placeholder="Помним, любим, скорбим..." className="resize-none h-24" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <Button type="submit" size="lg" disabled={userOrders.length === 0}>
                Создать страницу
              </Button>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
