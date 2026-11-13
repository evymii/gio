import { Schema } from 'mongoose';

/** GeoJSON Point sub-schema: coordinates are [lng, lat]. Index the parent field with '2dsphere'. */
export const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true },
    coordinates: {
      type: [Number],
      required: true,
      validate: {
        validator: (c: number[]) => c.length === 2 && Math.abs(c[0]) <= 180 && Math.abs(c[1]) <= 90,
        message: 'coordinates must be [lng, lat]',
      },
    },
  },
  { _id: false },
);
