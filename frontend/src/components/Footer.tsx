import { Link } from 'wouter';

export function Footer() {
  return (
    <footer className="border-t bg-card mt-auto">
      <div className="container mx-auto px-4 py-8 md:py-12">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-sm">
          <div>
            <h3 className="font-serif font-bold text-lg mb-4 text-foreground">QR Память</h3>
            <p className="text-muted-foreground leading-relaxed">
              Сохраняем историю вашей семьи в цифровом формате для будущих поколений.
            </p>
          </div>
          <div>
            <h4 className="font-medium mb-4 text-foreground">Навигация</h4>
            <ul className="space-y-2 text-muted-foreground">
              <li><Link href="/" className="hover:text-primary transition-colors">Главная</Link></li>
              <li><Link href="/#how-it-works" className="hover:text-primary transition-colors">О сервисе</Link></li>
              <li><Link href="/#pricing" className="hover:text-primary transition-colors">Тарифы</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-medium mb-4 text-foreground">Правовая информация</h4>
            <ul className="space-y-2 text-muted-foreground">
              <li><a href="#" className="hover:text-primary transition-colors">Политика конфиденциальности</a></li>
              <li><a href="#" className="hover:text-primary transition-colors">Пользовательское соглашение</a></li>
              <li><a href="#" className="hover:text-primary transition-colors">Контакты</a></li>
            </ul>
          </div>
        </div>
        <div className="mt-12 pt-8 border-t text-center text-muted-foreground text-xs">
          <p>© {new Date().getFullYear()} QR Память. Все права защищены.</p>
        </div>
      </div>
    </footer>
  );
}
