import { useState } from 'react';
import { useAuthStore } from '@/store/useAuthStore';
import { useOrderStore } from '@/store/useOrderStore';
import { useMemorialStore } from '@/store/useMemorialStore';
import { useLocation, Link } from 'wouter';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { toast } from 'sonner';
import { Check, X, Eye } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const statusMap = {
  processing: { label: 'В обработке', color: 'bg-yellow-100 text-yellow-800' },
  shipped: { label: 'Отправлен', color: 'bg-blue-100 text-blue-800' },
  delivered: { label: 'Доставлен', color: 'bg-green-100 text-green-800' }
};

export default function AdminPanel() {
  const [location] = useLocation();
  const { user } = useAuthStore();
  const { orders, updateOrderStatus } = useOrderStore();
  const { memorials, approveMemory, deleteMemory } = useMemorialStore();
  
  const [tab, setTab] = useState('orders');

  if (!user?.isAdmin) {
    return (
      <div className="p-8 text-center">
        <h1 className="text-2xl font-serif text-destructive">Доступ запрещен</h1>
        <p className="mt-2 text-muted-foreground">У вас нет прав администратора.</p>
        <Button asChild className="mt-4"><Link href="/">На главную</Link></Button>
      </div>
    );
  }

  const unapprovedMemories = memorials.flatMap(m => 
    m.memories.filter(mem => !mem.approved).map(mem => ({ ...mem, memorialId: m.id, memorialName: m.fullName }))
  );

  // Mock analytics data
  const revenue = orders.reduce((sum, o) => sum + o.totalPrice, 0);
  const packageData = [
    { name: 'Standard', value: orders.filter(o => o.packageType === 'standard').length, color: '#2D5016' },
    { name: 'Premium', value: orders.filter(o => o.packageType === 'premium').length, color: '#4A7A2A' },
    { name: 'Max', value: orders.filter(o => o.packageType === 'max').length, color: '#68A541' },
  ];
  
  const dailyOrders = Array.from({length: 7}).map((_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (6 - i));
    return {
      name: format(d, 'dd MMM', { locale: ru }),
      total: Math.floor(Math.random() * 50000) + 10000
    };
  });

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-serif font-medium mb-8">Панель администратора</h1>
      
      <Tabs value={tab} onValueChange={setTab} className="space-y-6">
        <TabsList>
          <TabsTrigger value="orders">Заказы ({orders.length})</TabsTrigger>
          <TabsTrigger value="memorials">Мемориалы ({memorials.length})</TabsTrigger>
          <TabsTrigger value="memories">
            Модерация {unapprovedMemories.length > 0 && <Badge variant="destructive" className="ml-2">{unapprovedMemories.length}</Badge>}
          </TabsTrigger>
          <TabsTrigger value="analytics">Аналитика</TabsTrigger>
        </TabsList>

        <TabsContent value="orders" className="space-y-4">
          <div className="bg-card rounded-xl border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Дата</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Пакет</TableHead>
                  <TableHead>Сумма</TableHead>
                  <TableHead>Статус</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {orders.map((order) => (
                  <TableRow key={order.id}>
                    <TableCell className="font-mono text-xs">{order.id.split('-')[1]}</TableCell>
                    <TableCell>{format(new Date(order.createdAt), 'dd.MM.yyyy')}</TableCell>
                    <TableCell>{order.email}</TableCell>
                    <TableCell className="capitalize">{order.packageType} x{order.quantity}</TableCell>
                    <TableCell>{order.totalPrice} ₽</TableCell>
                    <TableCell>
                      <Select 
                        defaultValue={order.status} 
                        onValueChange={(val: any) => {
                          updateOrderStatus(order.id, val);
                          toast.success('Статус обновлен');
                        }}
                      >
                        <SelectTrigger className={`h-8 w-32 border-none ${statusMap[order.status].color}`}>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="processing">В обработке</SelectItem>
                          <SelectItem value="shipped">Отправлен</SelectItem>
                          <SelectItem value="delivered">Доставлен</SelectItem>
                        </SelectContent>
                      </Select>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        <TabsContent value="memorials">
          <div className="bg-card rounded-xl border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ФИО</TableHead>
                  <TableHead>Пользователь (ID)</TableHead>
                  <TableHead>Пакет</TableHead>
                  <TableHead>Медиа</TableHead>
                  <TableHead>Действия</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {memorials.map((memorial) => (
                  <TableRow key={memorial.id}>
                    <TableCell className="font-medium">{memorial.fullName}</TableCell>
                    <TableCell className="font-mono text-xs">{memorial.userId}</TableCell>
                    <TableCell className="capitalize">{memorial.packageType}</TableCell>
                    <TableCell>
                      {memorial.photos.length} фото, {memorial.videos.length} видео
                    </TableCell>
                    <TableCell>
                      <Button variant="ghost" size="sm" asChild>
                        <Link href={`/memorial/${memorial.id}`}>
                          <Eye className="w-4 h-4" />
                        </Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        <TabsContent value="memories">
          {unapprovedMemories.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground bg-card rounded-xl border">
              Нет воспоминаний, ожидающих модерации
            </div>
          ) : (
            <div className="grid gap-4">
              {unapprovedMemories.map(mem => (
                <Card key={mem.id}>
                  <CardContent className="pt-6 flex gap-4">
                    <div className="flex-1 space-y-2">
                      <div className="flex justify-between items-start">
                        <div>
                          <span className="font-medium">{mem.authorName}</span>
                          <span className="text-muted-foreground text-sm ml-2">({mem.authorEmail})</span>
                        </div>
                        <span className="text-sm text-muted-foreground">Мемориал: {mem.memorialName}</span>
                      </div>
                      <p className="bg-muted p-4 rounded-lg text-sm">{mem.text}</p>
                      <div className="text-xs text-muted-foreground">
                        Отправлено: {format(new Date(mem.createdAt), 'dd.MM.yyyy HH:mm')}
                      </div>
                    </div>
                    <div className="flex flex-col gap-2 shrink-0">
                      <Button 
                        size="sm" 
                        className="bg-green-600 hover:bg-green-700 text-white"
                        onClick={() => {
                          approveMemory(mem.memorialId, mem.id);
                          toast.success('Одобрено');
                        }}
                      >
                        <Check className="w-4 h-4 mr-1" /> Одобрить
                      </Button>
                      <Button 
                        size="sm" 
                        variant="destructive"
                        onClick={() => {
                          deleteMemory(mem.memorialId, mem.id);
                          toast.success('Удалено');
                        }}
                      >
                        <X className="w-4 h-4 mr-1" /> Удалить
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="analytics" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Общая выручка</CardTitle></CardHeader>
              <CardContent><div className="text-3xl font-bold">{revenue.toLocaleString('ru-RU')} ₽</div></CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Всего заказов</CardTitle></CardHeader>
              <CardContent><div className="text-3xl font-bold">{orders.length}</div></CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Мемориалов создано</CardTitle></CardHeader>
              <CardContent><div className="text-3xl font-bold">{memorials.length}</div></CardContent>
            </Card>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card>
              <CardHeader><CardTitle>Выручка (последние 7 дней)</CardTitle></CardHeader>
              <CardContent className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={dailyOrders}>
                    <XAxis dataKey="name" fontSize={12} tickLine={false} axisLine={false} />
                    <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(v) => `${v / 1000}k`} />
                    <Tooltip cursor={{fill: 'rgba(0,0,0,0.05)'}} />
                    <Bar dataKey="total" fill="#2D5016" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            <Card>
              <CardHeader><CardTitle>Распределение пакетов</CardTitle></CardHeader>
              <CardContent className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={packageData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={100} label>
                      {packageData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
