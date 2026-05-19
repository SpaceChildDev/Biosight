import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { persons } from "@/lib/db/schema";
import { desc } from "drizzle-orm";

export async function GET() {
  try {
    const allPersons = await db.select().from(persons).orderBy(desc(persons.createdAt));
    return NextResponse.json(allPersons);
  } catch (error) {
    console.error("Failed to fetch persons:", error);
    return NextResponse.json({ error: "Failed to fetch persons" }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const { name, birthDate, gender } = await request.json();
    
    if (!name) {
      return NextResponse.json({ error: "Name is required" }, { status: 400 });
    }

    const newPerson = await db.insert(persons).values({
      name,
      birthDate,
      gender,
    }).returning();

    return NextResponse.json(newPerson[0]);
  } catch (error) {
    console.error("Failed to create person:", error);
    return NextResponse.json({ error: "Failed to create person" }, { status: 500 });
  }
}
