import { useEffect, useState } from 'react';
import { Link, useSearch } from 'wouter';
import { CheckCircle2, Loader2, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { getOrderStatus } from '@/lib/payments-api';

export default function OrderSuccessPage() {
  const search = useSearch();
  const params = new URLSearchParams(search);
  const orderId = params.get('order_id');

  const [status, setStatus] = useState<'loading' | 'paid' | 'pending' | 'error'>('loading');

  useEffect(() => {
    if (!orderId) {
      setStatus('error');
      return;
    }

    let cancelled = false;

    const poll = async () => {
      try {
        const result = await getOrderStatus(orderId);
        if (cancelled) return;
        setStatus(result.is_paid ? 'paid' : 'pending');
      } catch {
        if (!cancelled) setStatus('error');
      }
    };

    void poll();
    const interval = setInterval(() => void poll(), 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [orderId]);

  return (
    <div className="container mx-auto px-4 py-24 max-w-lg text-center">
      {status === 'loading' && (
        <>
          <Loader2 className="w-12 h-12 animate-spin mx-auto mb-6 text-primary" />
          <h1 className="text-2xl font-serif mb-2">Проверяем оплату…</h1>
          <p className="text-muted-foreground">Подождите несколько секунд</p>
        </>
      )}

      {status === 'paid' && (
        <>
          <CheckCircle2 className="w-16 h-16 text-green-600 mx-auto mb-6" />
          <h1 className="text-3xl font-serif mb-4">Оплата прошла успешно</h1>
          <p className="text-muted-foreground mb-8">
            Заказ принят в обработку. Данные для входа в личный кабинет отправлены на вашу почту.
          </p>
          <Button asChild className="w-full">
            <Link href="/cabinet">Перейти в личный кабинет</Link>
          </Button>
        </>
      )}

      {status === 'pending' && (
        <>
          <Loader2 className="w-12 h-12 animate-spin mx-auto mb-6 text-primary" />
          <h1 className="text-2xl font-serif mb-2">Ожидаем подтверждение оплаты</h1>
          <p className="text-muted-foreground mb-8">
            Если вы уже оплатили заказ, статус обновится автоматически в течение минуты.
          </p>
          <Button variant="outline" asChild>
            <Link href="/">На главную</Link>
          </Button>
        </>
      )}

      {status === 'error' && (
        <>
          <XCircle className="w-16 h-16 text-destructive mx-auto mb-6" />
          <h1 className="text-2xl font-serif mb-2">Не удалось проверить заказ</h1>
          <p className="text-muted-foreground mb-8">
            Проверьте ссылку или обратитесь в поддержку, указав номер заказа.
          </p>
          <Button asChild>
            <Link href="/">На главную</Link>
          </Button>
        </>
      )}
    </div>
  );
}
