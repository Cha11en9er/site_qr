import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { QRCodeSVG } from 'qrcode.react';
import { CheckCircle2, ChevronRight, ChevronLeft, Loader2, Minus, Plus } from 'lucide-react';
import { useOrderStore } from '@/store/useOrderStore';
import { useAuthStore } from '@/store/useAuthStore';
import { toast } from 'sonner';
import { Link } from 'wouter';

const packages = [
  { id: 'standard', name: 'Standard', price: 2990 },
  { id: 'premium', name: 'Premium', price: 5990 },
  { id: 'max', name: 'Max', price: 11990 }
];

const formSchema = z.object({
  packageType: z.enum(['standard', 'premium', 'max']),
  quantity: z.number().min(1).max(50),
  deceasedName: z.string().min(2, 'Обязательное поле'),
  email: z.string().email('Неверный формат'),
  phone: z.string().min(10, 'Введите телефон'),
  deliveryAddress: z.string().min(10, 'Укажите полный адрес')
});

export function PurchaseModal({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const [step, setStep] = useState(1);
  const [isProcessing, setIsProcessing] = useState(false);
  const [successOrder, setSuccessOrder] = useState<any>(null);
  
  const { user } = useAuthStore();
  const { createOrder } = useOrderStore();

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      packageType: 'standard',
      quantity: 1,
      deceasedName: '',
      email: user?.email || '',
      phone: user?.phone || '',
      deliveryAddress: ''
    }
  });

  const { watch, setValue, trigger, control } = form;
  const currentPackage = watch('packageType');
  const quantity = watch('quantity');
  const total = (packages.find(p => p.id === currentPackage)?.price || 0) * quantity;

  const nextStep = async () => {
    if (step === 1) {
      setStep(2);
    } else if (step === 2) {
      const isValid = await trigger();
      if (isValid) setStep(3);
    }
  };

  const handlePayment = async () => {
    setIsProcessing(true);
    // Mock processing delay
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    const data = form.getValues();
    const order = createOrder({
      userId: user?.id || 'guest',
      email: data.email,
      deceasedName: data.deceasedName,
      packageType: data.packageType,
      quantity: data.quantity,
      totalPrice: total,
      deliveryAddress: data.deliveryAddress,
      phone: data.phone
    });
    
    setSuccessOrder(order);
    setIsProcessing(false);
    setStep(4);
  };

  return (
    <Dialog open={open} onOpenChange={(v) => {
      if (!v && step === 4) {
        // Reset on close if finished
        setStep(1);
        setSuccessOrder(null);
        form.reset();
      }
      onOpenChange(v);
    }}>
      <DialogContent className="sm:max-w-[600px] p-0 overflow-hidden bg-background">
        <div className="p-6">
          <DialogHeader className="mb-6">
            <DialogTitle className="font-serif text-2xl">
              {step === 4 ? 'Оформление завершено' : 'Оформление заказа'}
            </DialogTitle>
            {step < 4 && (
              <div className="flex items-center gap-2 mt-4 text-sm text-muted-foreground">
                <span className={step >= 1 ? "text-primary font-medium" : ""}>Пакет</span>
                <ChevronRight className="w-4 h-4" />
                <span className={step >= 2 ? "text-primary font-medium" : ""}>Доставка</span>
                <ChevronRight className="w-4 h-4" />
                <span className={step >= 3 ? "text-primary font-medium" : ""}>Оплата</span>
              </div>
            )}
          </DialogHeader>

          {step === 1 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <div className="space-y-3">
                <Label>Выберите пакет</Label>
                <Controller
                  name="packageType"
                  control={control}
                  render={({ field }) => (
                    <RadioGroup onValueChange={field.onChange} defaultValue={field.value} className="grid gap-3">
                      {packages.map(pkg => (
                        <div key={pkg.id} className="relative">
                          <RadioGroupItem value={pkg.id} id={`pkg-${pkg.id}`} className="peer sr-only" />
                          <Label
                            htmlFor={`pkg-${pkg.id}`}
                            className="flex items-center justify-between p-4 border rounded-xl cursor-pointer peer-data-[state=checked]:border-primary peer-data-[state=checked]:bg-primary/5 hover:bg-muted/50"
                          >
                            <span className="font-medium text-lg">{pkg.name}</span>
                            <span className="font-bold">{pkg.price} ₽</span>
                          </Label>
                        </div>
                      ))}
                    </RadioGroup>
                  )}
                />
              </div>

              <div className="space-y-3">
                <Label>Количество QR-кодов (табличек)</Label>
                <div className="flex items-center gap-4">
                  <Button 
                    type="button" 
                    variant="outline" 
                    size="icon"
                    onClick={() => setValue('quantity', Math.max(1, quantity - 1))}
                  >
                    <Minus className="w-4 h-4" />
                  </Button>
                  <span className="text-xl font-medium w-8 text-center">{quantity}</span>
                  <Button 
                    type="button" 
                    variant="outline" 
                    size="icon"
                    onClick={() => setValue('quantity', Math.min(50, quantity + 1))}
                  >
                    <Plus className="w-4 h-4" />
                  </Button>
                </div>
              </div>

              <div className="pt-4 border-t flex items-center justify-between">
                <div>
                  <div className="text-sm text-muted-foreground">Итого к оплате</div>
                  <div className="text-2xl font-bold">{total} ₽</div>
                </div>
                <Button onClick={nextStep} size="lg">Далее <ChevronRight className="w-4 h-4 ml-2" /></Button>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4 animate-in fade-in slide-in-from-right-4">
              <div className="space-y-2">
                <Label>ФИО усопшего (для гравировки)</Label>
                <Input {...form.register('deceasedName')} placeholder="Иванов Иван Иванович" />
                {form.formState.errors.deceasedName && <p className="text-sm text-destructive">{form.formState.errors.deceasedName.message}</p>}
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Email</Label>
                  <Input {...form.register('email')} placeholder="email@example.com" />
                  {form.formState.errors.email && <p className="text-sm text-destructive">{form.formState.errors.email.message}</p>}
                </div>
                <div className="space-y-2">
                  <Label>Телефон</Label>
                  <Input {...form.register('phone')} placeholder="+7..." />
                  {form.formState.errors.phone && <p className="text-sm text-destructive">{form.formState.errors.phone.message}</p>}
                </div>
              </div>

              <div className="space-y-2">
                <Label>Адрес доставки (СДЭК/Почта)</Label>
                <Textarea {...form.register('deliveryAddress')} placeholder="Город, улица, дом, индекс" className="resize-none h-24" />
                {form.formState.errors.deliveryAddress && <p className="text-sm text-destructive">{form.formState.errors.deliveryAddress.message}</p>}
              </div>

              <div className="pt-4 border-t flex items-center justify-between">
                <Button variant="ghost" onClick={() => setStep(1)}><ChevronLeft className="w-4 h-4 mr-2" /> Назад</Button>
                <Button onClick={nextStep}>Перейти к оплате</Button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <div className="bg-muted/30 p-4 rounded-xl space-y-3">
                <h3 className="font-medium">Ваш заказ</h3>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Пакет</span>
                  <span>{packages.find(p => p.id === currentPackage)?.name}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Количество табличек</span>
                  <span>{quantity} шт.</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Для</span>
                  <span>{form.getValues('deceasedName')}</span>
                </div>
                <div className="border-t pt-2 mt-2 flex justify-between font-bold">
                  <span>К оплате</span>
                  <span>{total} ₽</span>
                </div>
              </div>

              <Button 
                onClick={handlePayment} 
                size="lg" 
                className="w-full text-lg h-14" 
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <><Loader2 className="mr-2 h-5 w-5 animate-spin" /> Обработка...</>
                ) : (
                  `Оплатить ${total} ₽`
                )}
              </Button>
              <div className="text-center">
                <Button variant="ghost" onClick={() => setStep(2)} disabled={isProcessing}>Назад</Button>
              </div>
            </div>
          )}

          {step === 4 && successOrder && (
            <div className="space-y-6 text-center animate-in fade-in zoom-in-95">
              <div className="w-20 h-20 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-10 h-10" />
              </div>
              <h3 className="text-2xl font-medium">Оплата прошла успешно!</h3>
              <p className="text-muted-foreground">
                QR-коды и чек отправлены на {successOrder.email}
              </p>

              <div className="flex flex-wrap justify-center gap-4 py-4">
                {successOrder.qrCodes.map((qrId: string, idx: number) => (
                  <div key={qrId} className="flex flex-col items-center gap-2 p-3 border rounded-xl bg-white">
                    <span className="text-xs font-medium text-muted-foreground">Код #{idx + 1}</span>
                    <QRCodeSVG value={`https://qr-memory.ru/memorial/${qrId}`} size={80} />
                  </div>
                ))}
              </div>

              <Button onClick={() => onOpenChange(false)} asChild className="w-full">
                <Link href="/cabinet">Перейти в личный кабинет</Link>
              </Button>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
