"use client";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  ReferenceArea,
  ResponsiveContainer,
} from "recharts";

type Point = { date: string; value: number };

export default function TrendsChart({
  data,
  refMin,
  refMax,
}: {
  data: Point[];
  refMin: number | null;
  refMax: number | null;
}) {
  const values = data.map((d) => d.value);
  const dataMin = Math.min(...values);
  const dataMax = Math.max(...values);
  const yMin = Math.min(dataMin, refMin ?? dataMin) * 0.9;
  const yMax = Math.max(dataMax, refMax ?? dataMax) * 1.1;

  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 10, right: 10, bottom: 0, left: -20 }}>
        <CartesianGrid stroke="#CDE8E5" strokeDasharray="3 3" />
        <XAxis dataKey="date" stroke="#4D869C" fontSize={11} />
        <YAxis domain={[yMin, yMax]} stroke="#4D869C" fontSize={11} />
        <Tooltip
          contentStyle={{ backgroundColor: "white", border: "1px solid #CDE8E5", borderRadius: 8 }}
          labelStyle={{ color: "#4D869C" }}
        />
        {refMin !== null && refMax !== null && (
          <ReferenceArea
            y1={refMin}
            y2={refMax}
            fill="#7AB2B2"
            fillOpacity={0.15}
            stroke="#7AB2B2"
            strokeOpacity={0.3}
          />
        )}
        <Line
          type="monotone"
          dataKey="value"
          stroke="#4D869C"
          strokeWidth={2}
          dot={{ fill: "#4D869C", r: 4 }}
          activeDot={{ r: 6 }}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
