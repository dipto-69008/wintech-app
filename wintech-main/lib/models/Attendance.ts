import mongoose, { Schema, Document } from 'mongoose';

export interface IAttendance extends Document {
  weekLabel: string;
  records: { employee: string; day: string; status: string }[];
}

const AttendanceSchema = new Schema<IAttendance>({
  weekLabel: { type: String, required: true },
  records: [{
    employee: { type: String, required: true },
    day: { type: String, required: true },
    status: { type: String, required: true, default: 'leave' },
  }],
}, { timestamps: true });

AttendanceSchema.index({ weekLabel: 1 });

export default mongoose.models.Attendance || mongoose.model<IAttendance>('Attendance', AttendanceSchema);
