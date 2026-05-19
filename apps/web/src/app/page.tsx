import { db } from "@/lib/db";
import { persons } from "@/lib/db/schema";
import { desc } from "drizzle-orm";
import { InferSelectModel } from "drizzle-orm";
import PersonList from "@/components/persons/PersonList";
import AddPersonForm from "@/components/persons/AddPersonForm";

type Person = InferSelectModel<typeof persons>;

export default async function Home() {
  let allPersons: Person[] = [];
  
  try {
    // Veritabanı URL'i .env'den alınıyor
    if (db) {
      allPersons = await db.select().from(persons).orderBy(desc(persons.createdAt));
    }
  } catch (error) {
    console.error("Home Page Fetch Error:", error);
    // Hata olsa bile sayfa 404 olmasın, boş liste gösterelim
  }

  return (
    <div className="flex flex-col items-center justify-center text-teal-dark">
      <div className="text-center mb-12">
        <h1 className="text-5xl font-extrabold mb-4 tracking-tight">HealthApp</h1>
        <p className="text-lg text-teal-dark/70 max-w-lg mx-auto font-medium">
          Sağlık verilerinizi ve tahlil sonuçlarınızı tek bir yerden takip edin.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 w-full max-w-5xl">
        <PersonList persons={allPersons} />
        <AddPersonForm />
      </div>

      <footer className="mt-20 text-teal-dark/40 text-sm font-medium">
        &copy; {new Date().getFullYear()} HealthApp
      </footer>
    </div>
  );
}
