import { useOrderStore } from '@/store/useOrderStore';
import { useAuthStore } from '@/store/useAuthStore';
import { Card, CardContent } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';

const statusMap = {
  processing: { label: 'В обработке', color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400' },
  shipped: { label: 'Отправлен', color: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400' },
  delivered: { label: 'Доставлен', color: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400' }
};

export default function CabinetOrders() {
  const { user } = useAuthStore();
  const { orders } = useOrderStore();
  
  const userOrders = orders.filter(o => o.userId === user?.id);

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-serif font-medium mb-6">Мои заказы</h1>

      {userOrders.length === 0 ? (
        <Card className="border-dashed bg-muted/30">
          <CardContent className="flex flex-col items-center justify-center py-16 text-center text-muted-foreground">
            У вас пока нет заказов
          </CardContent>
        </Card>
      ) : (
        <div className="bg-card rounded-xl border overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Номер</TableHead>
                <TableHead>Дата</TableHead>
                <TableHead>Пакет</TableHead>
                <TableHead>Сумма</TableHead>
                <TableHead>Статус</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {userOrders.map((order) => (
                <TableRow key={order.id}>
                  <TableCell className="font-medium text-xs font-mono">{order.id.split('-')[1]}</TableCell>
                  <TableCell>{format(new Date(order.createdAt), 'dd MMM yyyy', { locale: ru })}</TableCell>
                  <TableCell className="capitalize">{order.packageType} x{order.quantity}</TableCell>
                  <TableCell>{order.totalPrice} ₽</TableCell>
                  <TableCell>
                    <Badge variant="outline" className={`border-none ${statusMap[order.status].color}`}>
                      {statusMap[order.status].label}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
