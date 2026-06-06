import { ReactNode } from 'react';
import { Link, useLocation } from 'wouter';
import { useAuthStore } from '@/store/useAuthStore';
import { Book, PlusCircle, ShoppingBag, Settings, LogOut } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function CabinetLayout({ children }: { children: ReactNode }) {
  const [location] = useLocation();
  const { user, logout } = useAuthStore();

  if (!user) {
    return (
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="text-center">
          <h2 className="text-2xl font-serif mb-4">Требуется авторизация</h2>
          <p className="text-muted-foreground mb-6">Пожалуйста, войдите в систему, чтобы получить доступ к личному кабинету.</p>
          <Button asChild>
            <Link href="/">На главную</Link>
          </Button>
        </div>
      </div>
    );
  }

  const navItems = [
    { href: '/cabinet', icon: Book, label: 'Мои мемориалы' },
    { href: '/cabinet/create', icon: PlusCircle, label: 'Создать мемориал' },
    { href: '/cabinet/orders', icon: ShoppingBag, label: 'Мои заказы' },
    { href: '/cabinet/settings', icon: Settings, label: 'Настройки' },
  ];

  return (
    <div className="container mx-auto px-4 py-8 flex flex-col md:flex-row gap-8 flex-1">
      {/* Desktop Sidebar */}
      <aside className="hidden md:flex flex-col w-64 shrink-0 bg-card rounded-xl border p-4 h-fit sticky top-24">
        <div className="mb-8 px-4">
          <h2 className="font-serif text-xl font-medium truncate">{user.name}</h2>
          <p className="text-sm text-muted-foreground truncate">{user.email}</p>
        </div>
        <nav className="flex flex-col gap-2 flex-1">
          {navItems.map((item) => (
            <Link key={item.href} href={item.href}>
              <span className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors cursor-pointer
                ${location === item.href ? 'bg-primary/10 text-primary' : 'hover:bg-muted text-foreground/80 hover:text-foreground'}`}
              >
                <item.icon className="w-5 h-5" />
                {item.label}
              </span>
            </Link>
          ))}
          <div className="mt-auto pt-4 border-t">
            <button 
              onClick={() => void logout()}
              className="flex w-full items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium text-destructive hover:bg-destructive/10 transition-colors"
            >
              <LogOut className="w-5 h-5" />
              Выйти
            </button>
          </div>
        </nav>
      </aside>

      {/* Main Content */}
      <div className="flex-1 min-w-0 pb-20 md:pb-0">
        {children}
      </div>

      {/* Mobile Bottom Nav */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-background border-t pb-safe z-40 flex justify-around p-2">
        {navItems.map((item) => (
          <Link key={item.href} href={item.href}>
            <span className={`flex flex-col items-center gap-1 p-2 rounded-lg text-[10px] font-medium transition-colors
              ${location === item.href ? 'text-primary' : 'text-muted-foreground'}`}
            >
              <item.icon className="w-6 h-6" />
              {item.label}
            </span>
          </Link>
        ))}
      </nav>
    </div>
  );
}
