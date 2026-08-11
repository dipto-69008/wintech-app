import mongoose, { Schema, Document } from 'mongoose';

export interface IShift extends Document {
  name: string;
  startTime: string;
  endTime: string;
  employees: string[];
  color: string;
  days: string[];
}

const ShiftSchema = new Schema<IShift>({
  name: { type: String, required: true, trim: true },
  startTime: { type: String, required: true },
  endTime: { type: String, required: true },
  employees: [{ type: String }],
  color: { type: String, default: 'bg-blue-500' },
  days: [{ type: String }],
}, { timestamps: true });

export default mongoose.models.Shift || mongoose.model<IShift>('Shift', ShiftSchema);
