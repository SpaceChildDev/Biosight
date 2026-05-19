import { ACADEMIC_SOURCES } from "@/lib/constants/sources";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ExternalLink, BookOpen, ShieldCheck } from "lucide-react";

export default function SourcesPage() {
  return (
    <div className="container mx-auto py-12 px-4 space-y-12">
      <div className="text-center space-y-4 max-w-3xl mx-auto">
        <h1 className="text-4xl font-extrabold text-teal-dark tracking-tight">
          Akademik Kaynakça
        </h1>
        <p className="text-lg text-teal-dark/60 font-medium leading-relaxed">
          VitalTrace, sağlık verilerinizin analizi ve yorumlanmasında yalnızca en güvenilir, 
          hakemli ve resmi tıbbi kaynakları temel alır.
        </p>
        <div className="flex items-center justify-center gap-2 text-teal-medium font-semibold text-sm bg-teal-medium/10 w-fit mx-auto px-4 py-2 rounded-full">
          <ShieldCheck size={18} />
          Sadece Doğrulanmış Akademik Kaynaklar
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {ACADEMIC_SOURCES.map((category) => (
          <Card key={category.category} className="border-mint-light bg-white shadow-sm hover:shadow-md transition-shadow">
            <CardHeader className="border-b border-mint-light/50 bg-blue-soft/10">
              <CardTitle className="text-xl text-teal-dark flex items-center gap-3">
                <BookOpen className="text-teal-medium" size={20} />
                {category.category}
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <ul className="divide-y divide-mint-light">
                {category.items.map((item) => (
                  <li key={item.name} className="group">
                    <a
                      href={item.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-between p-4 hover:bg-blue-soft/20 transition-colors"
                    >
                      <span className="text-teal-dark font-medium group-hover:text-teal-medium transition-colors">
                        {item.name}
                      </span>
                      <ExternalLink 
                        size={16} 
                        className="text-teal-medium opacity-0 group-hover:opacity-100 transition-opacity" 
                      />
                    </a>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="bg-teal-dark text-white rounded-3xl p-8 md:p-12 text-center space-y-6">
        <h2 className="text-2xl font-bold italic">"Sağlık verisi, magazin veya reklam içeriği değil; bilimsel disiplin gerektirir."</h2>
        <div className="h-px bg-white/20 max-w-xs mx-auto" />
        <p className="text-white/70 max-w-2xl mx-auto text-sm leading-relaxed">
          Uygulama içerisindeki otomatik analiz ve filtreleme sistemleri; blog yazıları, doktor klinik siteleri 
          veya reklam içerikli makaleleri kesinlikle dikkate almaz. Tüm yorumlar yukarıdaki kaynakların 
          güncel verileriyle normalize edilir.
        </p>
      </div>
    </div>
  );
}
