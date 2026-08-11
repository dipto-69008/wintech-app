import mongoose, { Schema, Document } from 'mongoose';

export interface IHoliday extends Document {
  name: string;
  date: string;
  type: 'public' | 'company' | 'optional';
  description?: string;
}

const HolidaySchema = new Schema<IHoliday>({
  name: { type: String, required: true, trim: true },
  date: { type: String, required: true },
  type: { type: String, enum: ['public', 'company', 'optional'], default: 'public' },
  description: String,
}, { timestamps: true });

export default mongoose.models.Holiday || mongoose.model<IHoliday>('Holiday', HolidaySchema);
