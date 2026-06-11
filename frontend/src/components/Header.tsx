import { Link, useLocation } from 'wouter';
import { QrCode, Menu, User, LogOut } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAuthStore } from '@/store/useAuthStore';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { AuthModal } from './AuthModal';
import { scrollToId } from '@/lib/scroll';
import { useState } from 'react';

function NavLink({ sectionId, children }: { sectionId: string; children: React.ReactNode }) {
  const [location] = useLocation();

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault();
    if (location === '/') {
      scrollToId(sectionId);
    } else {
      window.location.href = `/#${sectionId}`;
    }
  };

  return (
    <a
      href={`/#${sectionId}`}
      onClick={handleClick}
      className="text-foreground/80 hover:text-foreground transition-colors"
    >
      {children}
    </a>
  );
}

export function Header() {
  const { user, logout } = useAuthStore();
  const [isAuthOpen, setIsAuthOpen] = useState(false);

  return (
    <header className="site-header sticky top-0 z-50 w-full border-b bg-background/98 shadow-sm">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2 text-primary hover:opacity-90 transition-opacity">
          <QrCode className="h-6 w-6" />
          <span className="font-serif font-bold text-xl tracking-tight">QR Память</span>
        </Link>

        <nav className="hidden md:flex items-center gap-8 text-sm font-medium">
          <NavLink sectionId="how-it-works">О сервисе</NavLink>
          <NavLink sectionId="examples">Примеры</NavLink>
          <NavLink sectionId="pricing">Тарифы</NavLink>
        </nav>

        <div className="flex items-center gap-4">
          {user ? (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="flex items-center gap-2">
                  <User className="h-4 w-4" />
                  <span className="hidden sm:inline">{user.name}</span>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuItem asChild>
                  <Link href="/cabinet" className="cursor-pointer">Личный кабинет</Link>
                </DropdownMenuItem>
                {user.isAdmin && (
                  <DropdownMenuItem asChild>
                    <Link href="/admin" className="cursor-pointer">Панель управления</Link>
                  </DropdownMenuItem>
                )}
                <DropdownMenuItem onClick={() => void logout()} className="text-destructive cursor-pointer">
                  <LogOut className="h-4 w-4 mr-2" />
                  Выйти
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          ) : (
            <Button onClick={() => setIsAuthOpen(true)} variant="outline" className="font-medium">
              Войти
            </Button>
          )}

          <Button variant="ghost" size="icon" className="md:hidden">
            <Menu className="h-5 w-5" />
          </Button>
        </div>
      </div>

      <AuthModal open={isAuthOpen} onOpenChange={setIsAuthOpen} />
    </header>
  );
}
