import { useState } from 'react';
import { motion } from 'framer-motion';
import { QrCode, BookOpen, Clock, Heart, ChevronRight, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import { PurchaseModal } from '@/components/PurchaseModal';
import { QRCodeSVG } from 'qrcode.react';

export default function LandingPage() {
  const [isPurchaseOpen, setIsPurchaseOpen] = useState(false);

  return (
    <div className="w-full">
      {/* Hero Section */}
      <section className="relative min-h-[85vh] flex items-center justify-center overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-[#F2EFE8] to-[#FAF7F2] -z-10" />
        
        {/* Soft decorative elements */}
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cream-paper.png')] opacity-40 mix-blend-overlay -z-10" />
        <div className="absolute -top-[20%] -left-[10%] w-[50%] h-[50%] rounded-full bg-[#E5DCC5] blur-3xl opacity-50 -z-10" />
        <div className="absolute -bottom-[20%] -right-[10%] w-[60%] h-[60%] rounded-full bg-[#E5DCC5] blur-3xl opacity-50 -z-10" />

        <div className="container px-4 py-16 mx-auto text-center z-10 flex flex-col items-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          >
            <h1 className="text-4xl md:text-6xl lg:text-7xl font-serif font-medium text-foreground tracking-tight max-w-4xl mx-auto leading-tight mb-6">
              Вечная память <br className="hidden md:block" />в одном QR-коде
            </h1>
            <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-12 leading-relaxed">
              Прикрепите цифровую страницу к памятнику. Сохраните историю, фотографии и воспоминания о близком человеке для будущих поколений.
            </p>

            <Button
              onClick={() => setIsPurchaseOpen(true)}
              className="rounded-full w-48 h-48 sm:w-56 sm:h-56 text-lg sm:text-xl font-medium bg-primary hover:bg-primary/90 text-primary-foreground shadow-xl hover:shadow-2xl transition-all duration-300 hover:scale-105 flex flex-col items-center justify-center gap-3"
            >
              <QrCode className="w-10 h-10" />
              <span className="max-w-[140px] leading-tight">Купить QR-код воспоминания</span>
            </Button>
          </motion.div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="py-24 bg-background">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-serif font-medium mb-4">Как это работает</h2>
            <div className="w-16 h-0.5 bg-primary/20 mx-auto" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-10 max-w-5xl mx-auto">
            {[
              { icon: QrCode, title: "1. Заказ", desc: "Выберите подходящий пакет и закажите металлическую табличку с QR-кодом." },
              { icon: BookOpen, title: "2. Создание страницы", desc: "В личном кабинете заполните данные, добавьте биографию и эпитафию." },
              { icon: Heart, title: "3. Фото и видео", desc: "Загрузите медиафайлы, которые расскажут историю жизни близкого." },
              { icon: Clock, title: "4. Память навсегда", desc: "Прикрепите табличку к памятнику. Любой сможет открыть страницу, отсканировав код." }
            ].map((step, i) => (
              <motion.div 
                key={i}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: i * 0.1 }}
                className="text-center group"
              >
                <div className="w-16 h-16 mx-auto bg-card border rounded-2xl flex items-center justify-center mb-6 group-hover:bg-primary/5 transition-colors">
                  <step.icon className="w-7 h-7 text-primary" />
                </div>
                <h3 className="font-medium text-lg mb-3">{step.title}</h3>
                <p className="text-muted-foreground text-sm leading-relaxed">{step.desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="py-24 bg-card">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-serif font-medium mb-4">Наши пакеты</h2>
            <div className="w-16 h-0.5 bg-primary/20 mx-auto" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {[
              {
                name: "Standard",
                price: 2990,
                desc: "Базовая страница памяти",
                features: ["Вечная страница", "До 40 фотографий", "Биография и эпитафия", "Книга воспоминаний"],
                notIncluded: ["Видеогалерея", "Интерактивная карта захоронения"]
              },
              {
                name: "Premium",
                price: 5990,
                desc: "Расширенные возможности с видео",
                features: ["Вечная страница", "До 80 фотографий", "До 20 минут видео", "Биография и эпитафия", "Книга воспоминаний", "Интерактивная карта"],
                notIncluded: [],
                popular: true
              },
              {
                name: "Max",
                price: 11990,
                desc: "Максимальный объем памяти",
                features: ["Вечная страница", "До 200 фотографий", "До 60 минут видео", "Биография и эпитафия", "Книга воспоминаний", "Интерактивная карта", "Приоритетная поддержка"],
                notIncluded: []
              }
            ].map((pkg, i) => (
              <Card key={i} className={`flex flex-col ${pkg.popular ? 'border-primary shadow-lg scale-105 z-10 relative' : 'border-border/50'}`}>
                {pkg.popular && (
                  <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-primary text-primary-foreground px-4 py-1 text-xs rounded-full font-medium tracking-wide">
                    Популярный выбор
                  </div>
                )}
                <CardHeader className="text-center pt-10">
                  <CardTitle className="font-serif text-2xl mb-2">{pkg.name}</CardTitle>
                  <div className="text-muted-foreground text-sm h-10">{pkg.desc}</div>
                  <div className="mt-4 mb-2">
                    <span className="text-4xl font-bold">{pkg.price}</span>
                    <span className="text-muted-foreground"> ₽</span>
                  </div>
                </CardHeader>
                <CardContent className="flex-1">
                  <ul className="space-y-4 text-sm mt-4">
                    {pkg.features.map((f, j) => (
                      <li key={j} className="flex items-start gap-3">
                        <Check className="w-5 h-5 text-primary shrink-0" />
                        <span>{f}</span>
                      </li>
                    ))}
                    {pkg.notIncluded.map((f, j) => (
                      <li key={j} className="flex items-start gap-3 text-muted-foreground opacity-50">
                        <div className="w-5 h-5 flex items-center justify-center shrink-0">-</div>
                        <span>{f}</span>
                      </li>
                    ))}
                  </ul>
                </CardContent>
                <CardFooter>
                  <Button 
                    onClick={() => setIsPurchaseOpen(true)} 
                    variant={pkg.popular ? "default" : "outline"} 
                    className="w-full"
                  >
                    Выбрать пакет
                  </Button>
                </CardFooter>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="py-24 bg-background overflow-hidden">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-serif font-medium mb-4">Отзывы</h2>
            <div className="w-16 h-0.5 bg-primary/20 mx-auto" />
          </div>

          <div className="flex gap-6 overflow-x-auto pb-10 snap-x snap-mandatory px-4 md:px-0 scrollbar-hide">
            {[
              { name: "Анна С.", text: "Очень светлый и уважительный сервис. Смогли собрать все фотографии дедушки в одном месте. Теперь родственники из других городов могут в любой момент 'навестить' его страницу." },
              { name: "Михаил В.", text: "Табличка пришла быстро, качество отличное. Самому заполнить страницу оказалось очень просто, интерфейс интуитивно понятный." },
              { name: "Елена Д.", text: "Для нашей семьи это стало настоящим проектом памяти. Мы вместе вспоминали истории, отбирали фотографии. Спасибо создателям." },
              { name: "Сергей П.", text: "Очень удобно, что есть возможность оставить свои воспоминания. Друзья отца написали столько теплых слов, о которых мы даже не знали." }
            ].map((testimonial, i) => (
              <Card key={i} className="min-w-[300px] md:min-w-[400px] max-w-[400px] snap-center bg-card border-none shadow-sm">
                <CardContent className="pt-8">
                  <div className="flex text-primary mb-4">
                    {[1,2,3,4,5].map(s => <span key={s}>★</span>)}
                  </div>
                  <p className="text-muted-foreground italic mb-6 leading-relaxed">"{testimonial.text}"</p>
                  <p className="font-medium">{testimonial.name}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-24 bg-card">
        <div className="container mx-auto px-4 max-w-3xl">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-serif font-medium mb-4">Частые вопросы</h2>
            <div className="w-16 h-0.5 bg-primary/20 mx-auto" />
          </div>

          <Accordion type="single" collapsible className="w-full">
            <AccordionItem value="item-1">
              <AccordionTrigger className="text-left font-medium text-lg">Как долго будет работать страница?</AccordionTrigger>
              <AccordionContent className="text-muted-foreground leading-relaxed">
                Мы используем надежные распределенные сервера для хранения данных. Ваш платеж единоразовый — страница создается навсегда без абонентской платы.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-2">
              <AccordionTrigger className="text-left font-medium text-lg">Из какого материала сделана табличка?</AccordionTrigger>
              <AccordionContent className="text-muted-foreground leading-relaxed">
                Табличка изготавливается из анодированного алюминия с лазерной гравировкой. Она устойчива к перепадам температур, солнцу и осадкам.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-3">
              <AccordionTrigger className="text-left font-medium text-lg">Кто может редактировать информацию?</AccordionTrigger>
              <AccordionContent className="text-muted-foreground leading-relaxed">
                Только владелец аккаунта (создатель мемориала) имеет доступ к редактированию всех данных, загрузке фотографий и модерации воспоминаний.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-4">
              <AccordionTrigger className="text-left font-medium text-lg">Нужно ли специальное приложение для сканирования?</AccordionTrigger>
              <AccordionContent className="text-muted-foreground leading-relaxed">
                Нет, достаточно стандартной камеры любого современного смартфона. При наведении на код автоматически появится ссылка на мемориальную страницу.
              </AccordionContent>
            </AccordionItem>
          </Accordion>
        </div>
      </section>

      <PurchaseModal open={isPurchaseOpen} onOpenChange={setIsPurchaseOpen} />
    </div>
  );
}
