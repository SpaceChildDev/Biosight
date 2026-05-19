import Link from "next/link";

export default function Header() {
  return (
    <header className="h-16 border-b border-mint-light bg-white flex items-center justify-between px-6 sticky top-0 z-50">
      <Link href="/" className="text-xl font-bold text-teal-dark">
        HealthApp
      </Link>
      <nav className="flex items-center gap-6">
        <Link href="/" className="text-sm font-medium hover:text-teal-medium transition-colors">
          Dashboard
        </Link>
        <Link href="/sources" className="text-sm font-medium hover:text-teal-medium transition-colors">
          Kaynaklar
        </Link>
        <div className="w-8 h-8 rounded-full bg-teal-medium text-white flex items-center justify-center text-xs font-bold">
          D
        </div>
      </nav>
    </header>
  );
}
