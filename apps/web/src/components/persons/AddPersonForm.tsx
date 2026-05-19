"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { PlusCircle } from "lucide-react";
import { useRouter } from "next/navigation";

export default function AddPersonForm() {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [gender, setGender] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const response = await fetch("/api/persons", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, birthDate, gender }),
      });

      if (response.ok) {
        setOpen(false);
        setName("");
        setBirthDate("");
        setGender("");
        router.refresh();
      } else {
        const data = await response.json();
        alert(data.error || "Failed to create person");
      }
    } catch (error) {
      console.error("Error creating person:", error);
      alert("An error occurred");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <button className="bg-white p-8 rounded-2xl shadow-sm border border-mint-light flex flex-col items-center hover:shadow-md transition-shadow cursor-pointer border-dashed w-full">
          <div className="w-16 h-16 bg-gray-100 rounded-full mb-4 flex items-center justify-center text-gray-400 text-3xl">
            <PlusCircle size={32} />
          </div>
          <h2 className="text-xl font-semibold mb-2 text-gray-400 italic">Kişi Ekle</h2>
          <p className="text-sm text-gray-400">Yeni bir profil oluşturun</p>
        </button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Yeni Kişi Ekle</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="name">Ad Soyad</Label>
            <Input
              id="name"
              placeholder="Örn: Ayşe Yılmaz"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="birthDate">Doğum Tarihi</Label>
            <Input
              id="birthDate"
              type="date"
              value={birthDate}
              onChange={(e) => setBirthDate(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="gender">Cinsiyet</Label>
            <Select value={gender} onValueChange={setGender}>
              <SelectTrigger>
                <SelectValue placeholder="Seçiniz" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="Erkek">Erkek</SelectItem>
                <SelectItem value="Kadın">Kadın</SelectItem>
                <SelectItem value="Diğer">Diğer</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button type="submit" className="w-full bg-teal-dark hover:bg-teal-medium" disabled={isLoading}>
            {isLoading ? "Kaydediliyor..." : "Kaydet"}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
