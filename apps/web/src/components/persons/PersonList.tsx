import Link from "next/link";
import { User } from "lucide-react";

interface Person {
  id: string;
  name: string;
}

interface PersonListProps {
  persons: Person[];
}

export default function PersonList({ persons }: PersonListProps) {
  return (
    <>
      {persons.map((person) => (
        <Link
          key={person.id}
          href={`/${person.id}`}
          className="bg-white p-8 rounded-2xl shadow-sm border border-mint-light flex flex-col items-center hover:shadow-md transition-shadow group"
        >
          <div className="w-16 h-16 bg-teal-medium rounded-full mb-4 flex items-center justify-center text-white text-2xl font-bold group-hover:scale-105 transition-transform">
            <User size={32} />
          </div>
          <h2 className="text-xl font-semibold mb-2">{person.name}</h2>
          <span className="text-teal-dark hover:underline font-medium">
            Görüntüle →
          </span>
        </Link>
      ))}
    </>
  );
}
