import { Schema, model } from 'mongoose';

/** regions — id, name, polygon (GeoJSON Polygon with a 2dsphere index, MongoDB's PostGIS equivalent). */
const regionSchema = new Schema(
  {
    slug: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    area: {
      type: { type: String, enum: ['Polygon'], required: true },
      coordinates: { type: [[[Number]]], required: true },
    },
  },
  { timestamps: true, collection: 'regions' },
);

regionSchema.index({ area: '2dsphere' });

export const Region = model('Region', regionSchema);
